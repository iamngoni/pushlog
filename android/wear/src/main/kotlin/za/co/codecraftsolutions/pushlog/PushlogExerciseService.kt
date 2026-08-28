package za.co.codecraftsolutions.pushlog

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.Build
import android.util.Log
import androidx.health.services.client.ExerciseUpdateCallback
import androidx.health.services.client.HealthServices
import androidx.health.services.client.data.Availability
import androidx.health.services.client.data.DataType
import androidx.health.services.client.data.ExerciseConfig
import androidx.health.services.client.data.ExerciseLapSummary
import androidx.health.services.client.data.ExerciseType
import androidx.health.services.client.data.ExerciseUpdate
import androidx.health.services.client.endExercise
import androidx.health.services.client.getCapabilities
import androidx.health.services.client.pauseExercise
import androidx.health.services.client.resumeExercise
import androidx.health.services.client.startExercise
import com.google.android.gms.wearable.MessageClient
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.Wearable
import com.google.android.gms.wearable.WearableListenerService
import java.util.concurrent.CopyOnWriteArraySet
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import org.json.JSONObject

class PushlogExerciseService : WearableListenerService() {
    private val serviceScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val exerciseClient by lazy { HealthServices.getClient(this).exerciseClient }
    private val messageClient by lazy { Wearable.getMessageClient(this) }
    private val sourceNodes = CopyOnWriteArraySet<String>()

    private var activeSessionId: String? = null
    private var latestHeartRate = 0.0
    private var latestCalories = 0.0
    private var paused = false

    private val exerciseCallback = object : ExerciseUpdateCallback {
        override fun onExerciseUpdateReceived(update: ExerciseUpdate) {
            val metrics = update.latestMetrics
            val heartRate = metrics.getData(DataType.HEART_RATE_BPM).lastOrNull()?.value
            val calories = metrics.getData(DataType.CALORIES_TOTAL)?.total
            if (heartRate != null) latestHeartRate = heartRate
            if (calories != null) latestCalories = calories
            publishState()
            sendMetrics()
        }

        override fun onLapSummaryReceived(lapSummary: ExerciseLapSummary) = Unit

        override fun onRegistered() = Unit

        override fun onRegistrationFailed(throwable: Throwable) {
            failWorkout("Sensor registration failed: ${throwable.message}")
        }

        override fun onAvailabilityChanged(
            dataType: DataType<*, *>,
            availability: Availability,
        ) = Unit
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        val saved = preferences()
        if (saved.getBoolean(KEY_ACTIVE, false)) {
            activeSessionId = saved.getString(KEY_SESSION_ID, null)
            latestHeartRate = saved.getFloat(KEY_HEART_RATE, 0f).toDouble()
            latestCalories = saved.getFloat(KEY_CALORIES, 0f).toDouble()
            paused = saved.getBoolean(KEY_PAUSED, false)
            startInForeground()
            exerciseClient.setUpdateCallback(exerciseCallback)
        }
    }

    override fun onDestroy() {
        exerciseClient.clearUpdateCallbackAsync(exerciseCallback)
        serviceScope.cancel()
        super.onDestroy()
    }

    override fun onMessageReceived(messageEvent: MessageEvent) {
        if (messageEvent.path != WearProtocol.PATH) return
        sourceNodes += messageEvent.sourceNodeId
        val payload = runCatching { WearProtocol.decode(messageEvent.data) }.getOrNull() ?: return
        serviceScope.launch { handleMessage(payload) }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_PAUSE -> serviceScope.launch { setPaused(true, notifyPhone = true) }
            ACTION_RESUME -> serviceScope.launch { setPaused(false, notifyPhone = true) }
            ACTION_END -> sendControl("end")
            ACTION_SYNC -> {
                sendToPhone("requestSync")
                if (activeSessionId == null) stopSelfResult(startId)
            }
        }
        return if (activeSessionId != null) Service.START_STICKY else Service.START_NOT_STICKY
    }

    private suspend fun handleMessage(payload: JSONObject) {
        when (payload.optString("type")) {
            "sessionStarted" -> startWorkout(
                sessionId = payload.optString("sessionID"),
                startedAtEpochMilliseconds = payload.optLong(
                    "startedAtEpochMilliseconds",
                    System.currentTimeMillis(),
                ),
            )
            "liveUpdate" -> {
                if (!matches(payload)) return
                setPaused(payload.optBoolean("isPaused", false), notifyPhone = false)
                publishState(
                    reps = payload.optInt("reps", 0),
                    elapsedSeconds = payload.optDouble("elapsed", 0.0),
                )
            }
            "sessionStopped" -> stopWorkout(payload)
            "sessionSave" -> saveWorkout(payload)
            "sessionDiscard", "sessionCancelled" -> discardWorkout(payload)
            "snapshot" -> applySnapshot(payload)
        }
    }

    private suspend fun startWorkout(sessionId: String, startedAtEpochMilliseconds: Long) {
        if (sessionId.isBlank()) return
        if (activeSessionId == sessionId) {
            sendAck(sessionId, true)
            return
        }
        if (!hasExercisePermissions()) {
            sendAck(sessionId, false)
            failWorkout("Open Pushlog on the watch and allow heart-rate access")
            return
        }

        runCatching {
            activeSessionId?.let { exerciseClient.endExercise() }
            exerciseClient.clearUpdateCallbackAsync(exerciseCallback)

            val capabilities = exerciseClient.getCapabilities()
            val exerciseType = when {
                ExerciseType.CALISTHENICS in capabilities.supportedExerciseTypes ->
                    ExerciseType.CALISTHENICS
                ExerciseType.STRENGTH_TRAINING in capabilities.supportedExerciseTypes ->
                    ExerciseType.STRENGTH_TRAINING
                else -> error("This watch does not support strength workouts")
            }
            val typeCapabilities = capabilities.getExerciseTypeCapabilities(exerciseType)
            val dataTypes = setOf(
                DataType.HEART_RATE_BPM,
                DataType.HEART_RATE_BPM_STATS,
                DataType.CALORIES_TOTAL,
            ).intersect(typeCapabilities.supportedDataTypes)
            require(DataType.HEART_RATE_BPM in dataTypes) {
                "This watch does not expose heart rate during workouts"
            }

            startInForeground()
            exerciseClient.setUpdateCallback(exerciseCallback)
            exerciseClient.startExercise(
                ExerciseConfig(
                    exerciseType = exerciseType,
                    dataTypes = dataTypes,
                    isAutoPauseAndResumeEnabled = false,
                    isGpsEnabled = false,
                ),
            )

            activeSessionId = sessionId
            latestHeartRate = 0.0
            latestCalories = 0.0
            paused = false
            preferences().edit()
                .putBoolean(KEY_ACTIVE, true)
                .putString(KEY_SESSION_ID, sessionId)
                .putLong(KEY_STARTED_AT, startedAtEpochMilliseconds)
                .apply()
            publishState()
            sendAck(sessionId, true)
        }.onFailure { error ->
            Log.e(LOG_TAG, "Unable to start Health Services exercise", error)
            sendAck(sessionId, false)
            failWorkout(error.message ?: "Unable to start watch workout")
            stopForeground(STOP_FOREGROUND_REMOVE)
        }
    }

    private suspend fun stopWorkout(payload: JSONObject) {
        if (!matches(payload)) return
        runCatching { exerciseClient.endExercise() }
        paused = false
        publishState(
            reps = payload.optInt("reps", 0),
            elapsedSeconds = payload.optDouble("duration", 0.0),
            active = false,
        )
        sendToPhone("workoutStopped", mapOf("sessionID" to activeSessionId))
        stopForeground(STOP_FOREGROUND_REMOVE)
    }

    private fun saveWorkout(payload: JSONObject) {
        if (!matches(payload)) return
        sendToPhone(
            "workoutSaved",
            mapOf(
                "sessionID" to activeSessionId,
                "bpm" to latestHeartRate,
                "activeCalories" to latestCalories,
            ),
        )
        clearWorkout()
    }

    private suspend fun discardWorkout(payload: JSONObject) {
        if (!matches(payload)) return
        runCatching { exerciseClient.endExercise() }
        clearWorkout()
    }

    private suspend fun setPaused(value: Boolean, notifyPhone: Boolean) {
        val sessionId = activeSessionId ?: return
        if (value == paused) return
        runCatching {
            if (value) exerciseClient.pauseExercise() else exerciseClient.resumeExercise()
        }.onSuccess {
            paused = value
            publishState()
            if (notifyPhone) sendControl(if (value) "pause" else "resume", sessionId)
        }.onFailure { Log.e(LOG_TAG, "Unable to update exercise pause state", it) }
    }

    private fun applySnapshot(payload: JSONObject) {
        if (!payload.optBoolean("activeSession", false)) return
        val sessionId = payload.optString("sessionID")
        if (activeSessionId == null && sessionId.isNotBlank()) {
            serviceScope.launch {
                startWorkout(
                    sessionId,
                    payload.optLong("startedAtEpochMilliseconds", System.currentTimeMillis()),
                )
            }
        }
    }

    private fun sendMetrics() {
        val sessionId = activeSessionId ?: return
        sendToPhone(
            "metrics",
            mapOf(
                "sessionID" to sessionId,
                "bpm" to latestHeartRate,
                "activeCalories" to latestCalories,
                "sampledAtEpochMilliseconds" to System.currentTimeMillis(),
            ),
        )
    }

    private fun sendAck(sessionId: String, accepted: Boolean) {
        sendToPhone("sessionAck", mapOf("sessionID" to sessionId, "accepted" to accepted))
    }

    private fun sendControl(action: String, sessionId: String? = activeSessionId) {
        val id = sessionId ?: return
        sendToPhone("watchControl", mapOf("sessionID" to id, "action" to action))
    }

    private fun sendToPhone(type: String, values: Map<String, Any?> = emptyMap()) {
        val data = WearProtocol.encode(type, values)
        if (sourceNodes.isNotEmpty()) {
            sourceNodes.forEach { node -> messageClient.sendMessage(node, WearProtocol.PATH, data) }
            return
        }
        Wearable.getNodeClient(this).connectedNodes.addOnSuccessListener { nodes ->
            nodes.forEach { node -> messageClient.sendMessage(node.id, WearProtocol.PATH, data) }
        }
    }

    private fun publishState(
        reps: Int? = null,
        elapsedSeconds: Double? = null,
        active: Boolean = activeSessionId != null,
    ) {
        preferences().edit()
            .putBoolean(KEY_ACTIVE, active)
            .putBoolean(KEY_PAUSED, paused)
            .putFloat(KEY_HEART_RATE, latestHeartRate.toFloat())
            .putFloat(KEY_CALORIES, latestCalories.toFloat())
            .apply {
                if (reps != null) putInt(KEY_REPS, reps)
                if (elapsedSeconds != null) putFloat(KEY_ELAPSED, elapsedSeconds.toFloat())
            }
            .apply()
    }

    private fun clearWorkout() {
        activeSessionId = null
        paused = false
        exerciseClient.clearUpdateCallbackAsync(exerciseCallback)
        preferences().edit().clear().apply()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun failWorkout(reason: String) {
        sendToPhone(
            "workoutFailed",
            mapOf("sessionID" to activeSessionId, "reason" to reason),
        )
        preferences().edit().putString(KEY_ERROR, reason).apply()
    }

    private fun matches(payload: JSONObject): Boolean {
        val messageSessionId = payload.optString("sessionID")
        return messageSessionId.isBlank() || messageSessionId == activeSessionId
    }

    private fun hasExercisePermissions(): Boolean {
        val heartRatePermission = if (Build.VERSION.SDK_INT >= 36) {
            "android.permission.health.READ_HEART_RATE"
        } else {
            Manifest.permission.BODY_SENSORS
        }
        return checkSelfPermission(heartRatePermission) == PackageManager.PERMISSION_GRANTED &&
            checkSelfPermission(Manifest.permission.ACTIVITY_RECOGNITION) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun startInForeground() {
        val notification = Notification.Builder(this, NOTIFICATION_CHANNEL)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentTitle("Pushlog workout")
            .setContentText("Tracking heart rate and calories")
            .setOngoing(true)
            .setContentIntent(
                PendingIntent.getActivity(
                    this,
                    0,
                    Intent(this, WearMainActivity::class.java),
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
                ),
            )
            .build()
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_HEALTH,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun createNotificationChannel() {
        getSystemService(NotificationManager::class.java).createNotificationChannel(
            NotificationChannel(
                NOTIFICATION_CHANNEL,
                "Live workouts",
                NotificationManager.IMPORTANCE_LOW,
            ),
        )
    }

    private fun preferences() = getSharedPreferences(PREFERENCES, MODE_PRIVATE)

    companion object {
        const val ACTION_PAUSE = "za.co.codecraftsolutions.pushlog.PAUSE"
        const val ACTION_RESUME = "za.co.codecraftsolutions.pushlog.RESUME"
        const val ACTION_END = "za.co.codecraftsolutions.pushlog.END"
        const val ACTION_SYNC = "za.co.codecraftsolutions.pushlog.SYNC"

        const val PREFERENCES = "pushlog_wear_workout"
        const val KEY_ACTIVE = "active"
        const val KEY_PAUSED = "paused"
        const val KEY_HEART_RATE = "heart_rate"
        const val KEY_CALORIES = "calories"
        const val KEY_REPS = "reps"
        const val KEY_ELAPSED = "elapsed"
        const val KEY_SESSION_ID = "session_id"
        const val KEY_STARTED_AT = "started_at"
        const val KEY_ERROR = "error"

        private const val NOTIFICATION_CHANNEL = "pushlog_workout"
        private const val NOTIFICATION_ID = 4701
        private const val LOG_TAG = "PushlogWear"
    }
}
