package za.co.codecraftsolutions.pushlog

import android.content.Context
import android.util.Log
import com.google.android.gms.wearable.CapabilityClient
import com.google.android.gms.wearable.CapabilityInfo
import com.google.android.gms.wearable.MessageClient
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.Node
import com.google.android.gms.wearable.Wearable
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import org.json.JSONObject

class PushlogWearSessionManager(
    context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler,
    MessageClient.OnMessageReceivedListener,
    CapabilityClient.OnCapabilityChangedListener {

    private enum class Ownership { PHONE, REQUESTED, ACCEPTED, STOPPED }

    private data class Workout(
        val id: String,
        val startedAtEpochMilliseconds: Long,
        var ownership: Ownership,
        var reps: Int = 0,
        var durationSeconds: Double = 0.0,
        var endedAtEpochMilliseconds: Long? = null,
        val heartRateSamples: MutableList<HealthConnectWorkoutWriter.HeartRateSample> = mutableListOf(),
        var activeCalories: Double = 0.0,
    )

    private val appContext = context.applicationContext
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val messageClient = Wearable.getMessageClient(appContext)
    private val capabilityClient = Wearable.getCapabilityClient(appContext)
    private val healthWriter = HealthConnectWorkoutWriter(appContext)
    private val nodes = mutableSetOf<Node>()
    private var workout: Workout? = null
    private var eventSink: EventChannel.EventSink? = null
    private var statusLabel = "ANDROID ONLY"
    private var currentHeartRate = 0.0
    private var currentCalories = 0.0
    private var controlAction = ""
    private var controlValue = 0
    private var controlSequence = 0

    init {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(this)
        EventChannel(messenger, EVENT_CHANNEL).setStreamHandler(this)
        messageClient.addListener(this)
        capabilityClient.addListener(this, WearProtocol.CAPABILITY)
        refreshNodes()
    }

    fun close() {
        messageClient.removeListener(this)
        capabilityClient.removeListener(this, WearProtocol.CAPABILITY)
        scope.cancel()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "status" -> {
                refreshNodes()
                result.success(snapshot())
            }
            "beginLiveWorkout" -> result.success(beginWorkout(call))
            "sendLiveUpdate" -> {
                updateWorkout(call)
                result.success(null)
            }
            "stopLiveWorkout" -> result.success(stopWorkout(call))
            "commitStoppedWorkout" -> commitWorkout(call, result)
            "discardStoppedWorkout" -> {
                discardWorkout(call)
                result.success(null)
            }
            "cancelLiveWorkout" -> {
                cancelWorkout(call)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        eventSink = events
        emit()
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    override fun onCapabilityChanged(capabilityInfo: CapabilityInfo) {
        nodes.clear()
        nodes += capabilityInfo.nodes
        refreshIdleLabel()
        emit()
    }

    override fun onMessageReceived(messageEvent: MessageEvent) {
        if (messageEvent.path != WearProtocol.PATH) return
        val payload = runCatching { WearProtocol.decode(messageEvent.data) }.getOrNull() ?: return
        scope.launch { handleWearMessage(messageEvent.sourceNodeId, payload) }
    }

    private fun beginWorkout(call: MethodCall): Map<String, Any> {
        val sessionId = call.argument<String>("sessionId") ?: return snapshot()
        val preferWatch = call.argument<Boolean>("preferWatch") == true
        val startedAt = call.argument<Number>("startedAtMillisecondsSinceEpoch")?.toLong()
            ?: System.currentTimeMillis()
        val useWatch = preferWatch && nodes.isNotEmpty()
        workout = Workout(
            id = sessionId,
            startedAtEpochMilliseconds = startedAt,
            ownership = if (useWatch) Ownership.REQUESTED else Ownership.PHONE,
        )
        currentHeartRate = 0.0
        currentCalories = 0.0
        controlAction = ""
        controlValue = 0
        statusLabel = if (useWatch) "WEAR REQUESTED" else "ANDROID ONLY"
        if (useWatch) {
            sendToWear(
                "sessionStarted",
                mapOf(
                    "sessionID" to sessionId,
                    "startedAtEpochMilliseconds" to startedAt,
                    "healthOwner" to "watch",
                ),
            )
        }
        emit()
        return snapshot()
    }

    private fun updateWorkout(call: MethodCall) {
        val current = workout ?: return
        if (!matches(current, call)) return
        current.reps = call.argument<Int>("reps") ?: current.reps
        current.durationSeconds = call.argument<Number>("elapsedSeconds")?.toDouble()
            ?: current.durationSeconds
        if (current.ownership == Ownership.ACCEPTED || current.ownership == Ownership.REQUESTED) {
            sendToWear(
                "liveUpdate",
                mapOf(
                    "sessionID" to current.id,
                    "reps" to current.reps,
                    "elapsed" to current.durationSeconds,
                    "phase" to (call.argument<String>("phase") ?: "LIVE"),
                    "trackingState" to (call.argument<String>("trackingState") ?: "READY"),
                    "isPaused" to (call.argument<Boolean>("isPaused") ?: false),
                    "isActive" to true,
                ),
            )
        }
    }

    private fun stopWorkout(call: MethodCall): String {
        val current = workout ?: return "phone"
        if (!matches(current, call)) return "phone"
        current.reps = call.argument<Int>("reps") ?: current.reps
        current.durationSeconds = call.argument<Number>("durationSeconds")?.toDouble()
            ?: current.durationSeconds
        current.endedAtEpochMilliseconds =
            call.argument<Number>("endedAtMillisecondsSinceEpoch")?.toLong()
                ?: System.currentTimeMillis()

        return if (current.ownership == Ownership.ACCEPTED) {
            current.ownership = Ownership.STOPPED
            statusLabel = "WEAR STOPPED"
            sendToWear(
                "sessionStopped",
                mapOf(
                    "sessionID" to current.id,
                    "reps" to current.reps,
                    "duration" to current.durationSeconds,
                    "endedAtEpochMilliseconds" to current.endedAtEpochMilliseconds,
                ),
            )
            emit()
            "watch"
        } else {
            if (current.ownership == Ownership.REQUESTED) {
                sendToWear("sessionCancelled", mapOf("sessionID" to current.id))
            }
            current.ownership = Ownership.PHONE
            statusLabel = "PHONE FALLBACK"
            emit()
            "phone"
        }
    }

    private fun commitWorkout(call: MethodCall, result: MethodChannel.Result) {
        val current = workout
        if (current == null || !matches(current, call) || current.ownership != Ownership.STOPPED) {
            clearWorkout()
            result.success("phone")
            return
        }

        scope.launch {
            val saved = runCatching {
                healthWriter.saveWatchWorkout(
                    externalId = current.id,
                    reps = current.reps,
                    startedAtEpochMilliseconds = current.startedAtEpochMilliseconds,
                    endedAtEpochMilliseconds = current.endedAtEpochMilliseconds
                        ?: System.currentTimeMillis(),
                    heartRateSamples = current.heartRateSamples,
                    activeCalories = current.activeCalories,
                    effortScore = call.argument<Number>("effortScore")?.toInt(),
                )
            }.onFailure { Log.e(LOG_TAG, "Wear workout export failed", it) }
                .getOrDefault(false)

            if (saved) {
                sendToWear("sessionSave", mapOf("sessionID" to current.id))
                clearWorkout()
                result.success("watch")
            } else {
                sendToWear("sessionDiscard", mapOf("sessionID" to current.id))
                clearWorkout()
                result.success("phone")
            }
        }
    }

    private fun discardWorkout(call: MethodCall) {
        val current = workout ?: return
        if (!matches(current, call)) return
        if (current.ownership != Ownership.PHONE) {
            sendToWear("sessionDiscard", mapOf("sessionID" to current.id))
        }
        clearWorkout()
    }

    private fun cancelWorkout(call: MethodCall) {
        val current = workout ?: return
        if (!matches(current, call)) return
        if (current.ownership != Ownership.PHONE) {
            sendToWear("sessionCancelled", mapOf("sessionID" to current.id))
        }
        clearWorkout()
    }

    private fun handleWearMessage(sourceNodeId: String, payload: JSONObject) {
        when (payload.optString("type")) {
            "sessionAck" -> {
                val current = workout ?: return
                if (!matches(current, payload)) return
                val accepted = payload.optBoolean("accepted", false)
                current.ownership = if (accepted) Ownership.ACCEPTED else Ownership.PHONE
                statusLabel = if (accepted) "WEAR RECORDING" else "PHONE FALLBACK"
            }
            "metrics" -> recordMetrics(payload)
            "watchControl" -> recordControl(payload)
            "requestSync" -> sendToNode(sourceNodeId, "snapshot", snapshot())
            "workoutStopped" -> statusLabel = "WEAR STOPPED"
            "workoutSaved" -> statusLabel = "WEAR SAVED"
            "workoutFailed" -> {
                workout?.ownership = Ownership.PHONE
                statusLabel = "WEAR FAILED"
            }
        }
        emit()
    }

    private fun recordMetrics(payload: JSONObject) {
        val current = workout ?: return
        if (!matches(current, payload)) return
        val bpm = payload.optDouble("bpm", currentHeartRate)
        val calories = payload.optDouble("activeCalories", currentCalories)
        val sampledAt = payload.optLong("sampledAtEpochMilliseconds", System.currentTimeMillis())
        if (bpm in 1.0..300.0) {
            currentHeartRate = bpm
            if (current.heartRateSamples.lastOrNull()?.sampledAtEpochMilliseconds != sampledAt) {
                current.heartRateSamples += HealthConnectWorkoutWriter.HeartRateSample(sampledAt, bpm)
            }
        }
        if (calories >= 0) {
            currentCalories = calories
            current.activeCalories = calories
        }
    }

    private fun recordControl(payload: JSONObject) {
        val current = workout ?: return
        if (!matches(current, payload)) return
        val action = payload.optString("action")
        if (action !in setOf("pause", "resume", "end")) return
        controlAction = action
        controlValue = 0
        controlSequence += 1
    }

    private fun refreshNodes() {
        scope.launch {
            runCatching {
                capabilityClient.getCapability(
                    WearProtocol.CAPABILITY,
                    CapabilityClient.FILTER_ALL,
                ).await()
            }.onSuccess { info ->
                nodes.clear()
                nodes += info.nodes
                refreshIdleLabel()
                emit()
            }.onFailure {
                nodes.clear()
                refreshIdleLabel()
                emit()
            }
        }
    }

    private fun sendToWear(type: String, values: Map<String, Any?> = emptyMap()) {
        val data = WearProtocol.encode(type, values)
        nodes.forEach { node -> messageClient.sendMessage(node.id, WearProtocol.PATH, data) }
    }

    private fun sendToNode(nodeId: String, type: String, values: Map<String, Any?>) {
        messageClient.sendMessage(nodeId, WearProtocol.PATH, WearProtocol.encode(type, values))
    }

    private fun clearWorkout() {
        workout = null
        currentHeartRate = 0.0
        currentCalories = 0.0
        refreshIdleLabel()
        emit()
    }

    private fun refreshIdleLabel() {
        if (workout == null) statusLabel = if (nodes.isEmpty()) "ANDROID ONLY" else "WEAR READY"
    }

    private fun matches(current: Workout, call: MethodCall): Boolean {
        val sessionId = call.argument<String>("sessionId")
        return sessionId == null || sessionId == current.id
    }

    private fun matches(current: Workout, payload: JSONObject): Boolean {
        val sessionId = payload.optString("sessionID")
        return sessionId.isBlank() || sessionId == current.id
    }

    private fun snapshot(): Map<String, Any> {
        val current = workout
        return buildMap {
            put("type", "snapshot")
            put("isSupported", true)
            put("isPaired", nodes.isNotEmpty())
            put("isAppInstalled", nodes.isNotEmpty())
            put("isReachable", nodes.any { it.isNearby })
            put("statusLabel", statusLabel)
            put("currentHeartRate", currentHeartRate)
            put("activeCalories", currentCalories)
            put("controlAction", controlAction)
            put("controlValue", controlValue)
            put("controlSequence", controlSequence)
            put("activeSession", current != null)
            if (current != null) {
                put("sessionID", current.id)
                put("startedAtEpochMilliseconds", current.startedAtEpochMilliseconds)
                put("reps", current.reps)
                put("elapsed", current.durationSeconds)
                put("ownership", current.ownership.name.lowercase())
            }
        }
    }

    private fun emit() {
        eventSink?.success(snapshot())
    }

    private companion object {
        const val CHANNEL = "pushlog/watch"
        const val EVENT_CHANNEL = "pushlog/watch/events"
        const val LOG_TAG = "PushlogWearPhone"
    }
}
