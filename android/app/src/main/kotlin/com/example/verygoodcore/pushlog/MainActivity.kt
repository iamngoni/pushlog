package za.co.codecraftsolutions.pushlog

import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.ExerciseSegment
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.metadata.Device
import androidx.health.connect.client.records.metadata.Metadata
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.time.Instant
import java.time.ZoneId
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

class MainActivity : FlutterActivity() {
    private val healthScope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private val healthPermissions = setOf(
        HealthPermission.getWritePermission(ExerciseSessionRecord::class),
    )
    private val healthPermissionContract =
        PermissionController.createRequestPermissionResultContract()
    private var pendingPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            HEALTH_CHANNEL,
        ).setMethodCallHandler(::handleHealthCall)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == HEALTH_PERMISSION_REQUEST_CODE) {
            val granted = healthPermissionContract.parseResult(resultCode, data)
            pendingPermissionResult?.success(granted.containsAll(healthPermissions))
            pendingPermissionResult = null
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun onDestroy() {
        healthScope.cancel()
        pendingPermissionResult?.success(false)
        pendingPermissionResult = null
        super.onDestroy()
    }

    private fun handleHealthCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "authorizationStatus" -> authorizationStatus(result)
            "requestAuthorization" -> requestHealthAuthorization(result)
            "saveLiveSession" -> saveLiveSession(call, result)
            else -> result.notImplemented()
        }
    }

    private fun authorizationStatus(result: MethodChannel.Result) {
        if (!healthConnectAvailable()) {
            result.success("unavailable")
            return
        }

        healthScope.launch {
            try {
                val granted = healthClient().permissionController.getGrantedPermissions()
                result.success(
                    if (granted.containsAll(healthPermissions)) "authorized"
                    else "notDetermined",
                )
            } catch (error: Exception) {
                Log.e(LOG_TAG, "Health Connect permission check failed", error)
                result.success("unavailable")
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun requestHealthAuthorization(result: MethodChannel.Result) {
        if (!healthConnectAvailable() || pendingPermissionResult != null) {
            result.success(false)
            return
        }

        healthScope.launch {
            try {
                val granted = healthClient().permissionController.getGrantedPermissions()
                if (granted.containsAll(healthPermissions)) {
                    result.success(true)
                    return@launch
                }

                pendingPermissionResult = result
                startActivityForResult(
                    healthPermissionContract.createIntent(
                        this@MainActivity,
                        healthPermissions,
                    ),
                    HEALTH_PERMISSION_REQUEST_CODE,
                )
            } catch (error: Exception) {
                Log.e(LOG_TAG, "Health Connect permission request failed", error)
                pendingPermissionResult = null
                result.success(false)
            }
        }
    }

    private fun saveLiveSession(call: MethodCall, result: MethodChannel.Result) {
        val reps = call.argument<Int>("reps")
        val durationMicroseconds = call.argument<Number>("durationMicroseconds")?.toLong()
        val manualAdjustments = call.argument<Int>("manualAdjustments")
        val endedAtEpochMilliseconds =
            call.argument<Number>("endedAtEpochMilliseconds")?.toLong()
        val externalId = call.argument<String>("externalId")

        if (
            reps == null || reps <= 0 ||
            durationMicroseconds == null || manualAdjustments == null ||
            endedAtEpochMilliseconds == null || externalId.isNullOrBlank() ||
            !healthConnectAvailable()
        ) {
            result.success(false)
            return
        }

        healthScope.launch {
            try {
                val client = healthClient()
                val granted = client.permissionController.getGrantedPermissions()
                if (!granted.containsAll(healthPermissions)) {
                    result.success(false)
                    return@launch
                }

                val end = Instant.ofEpochMilli(endedAtEpochMilliseconds)
                val durationMillis = maxOf(durationMicroseconds / 1_000, 1_000)
                val start = end.minusMillis(durationMillis)
                val zoneRules = ZoneId.systemDefault().rules
                val metadata = Metadata.activelyRecorded(
                    device = Device(
                        type = Device.TYPE_PHONE,
                        manufacturer = Build.MANUFACTURER,
                        model = Build.MODEL,
                    ),
                    clientRecordId = externalId,
                    clientRecordVersion = 1,
                )
                val pushUps = ExerciseSegment(
                    startTime = start,
                    endTime = end,
                    segmentType = ExerciseSegment.EXERCISE_SEGMENT_TYPE_OTHER_WORKOUT,
                    repetitions = reps,
                )
                val session = ExerciseSessionRecord(
                    startTime = start,
                    startZoneOffset = zoneRules.getOffset(start),
                    endTime = end,
                    endZoneOffset = zoneRules.getOffset(end),
                    metadata = metadata,
                    exerciseType = ExerciseSessionRecord.EXERCISE_TYPE_CALISTHENICS,
                    title = "Push-ups",
                    notes = "$reps push-ups · $manualAdjustments manual adjustments",
                    segments = listOf(pushUps),
                )

                client.insertRecords(listOf(session))
                result.success(true)
            } catch (error: Exception) {
                Log.e(LOG_TAG, "Health Connect workout export failed", error)
                result.success(false)
            }
        }
    }

    private fun healthConnectAvailable(): Boolean =
        HealthConnectClient.getSdkStatus(this) == HealthConnectClient.SDK_AVAILABLE

    private fun healthClient(): HealthConnectClient = HealthConnectClient.getOrCreate(this)

    private companion object {
        const val HEALTH_CHANNEL = "pushlog/health"
        const val HEALTH_PERMISSION_REQUEST_CODE = 4107
        const val LOG_TAG = "PushlogHealth"
    }
}
