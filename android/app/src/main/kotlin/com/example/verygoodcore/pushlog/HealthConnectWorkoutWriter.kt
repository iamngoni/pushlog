package za.co.codecraftsolutions.pushlog

import android.content.Context
import android.os.Build
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.ExerciseSegment
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.records.Record
import androidx.health.connect.client.records.TotalCaloriesBurnedRecord
import androidx.health.connect.client.records.metadata.Device
import androidx.health.connect.client.records.metadata.Metadata
import androidx.health.connect.client.units.Energy
import java.time.Instant
import java.time.ZoneId

class HealthConnectWorkoutWriter(private val context: Context) {
    data class HeartRateSample(val sampledAtEpochMilliseconds: Long, val bpm: Double)

    val permissions = setOf(
        HealthPermission.getWritePermission(ExerciseSessionRecord::class),
        HealthPermission.getWritePermission(HeartRateRecord::class),
        HealthPermission.getWritePermission(TotalCaloriesBurnedRecord::class),
    )

    fun isAvailable(): Boolean =
        HealthConnectClient.getSdkStatus(context) == HealthConnectClient.SDK_AVAILABLE

    suspend fun hasPermissions(): Boolean =
        isAvailable() && client().permissionController.getGrantedPermissions().containsAll(permissions)

    suspend fun saveWatchWorkout(
        externalId: String,
        reps: Int,
        startedAtEpochMilliseconds: Long,
        endedAtEpochMilliseconds: Long,
        heartRateSamples: List<HeartRateSample>,
        activeCalories: Double,
        effortScore: Int?,
    ): Boolean {
        if (reps <= 0 || externalId.isBlank() || !hasPermissions()) return false

        val end = Instant.ofEpochMilli(endedAtEpochMilliseconds)
        val startCandidate = Instant.ofEpochMilli(startedAtEpochMilliseconds)
        val start = if (startCandidate < end) startCandidate else end.minusSeconds(1)
        val zoneRules = ZoneId.systemDefault().rules
        val watch = Device(
            type = Device.TYPE_WATCH,
            manufacturer = "Wear OS",
            model = "Paired watch",
        )
        val sessionMetadata = Metadata.activelyRecorded(
            device = watch,
            clientRecordId = externalId,
            clientRecordVersion = 1,
        )
        val pushUps = ExerciseSegment(
            startTime = start,
            endTime = end,
            segmentType = ExerciseSegment.EXERCISE_SEGMENT_TYPE_OTHER_WORKOUT,
            repetitions = reps,
        )
        val records = mutableListOf<Record>(
            ExerciseSessionRecord(
                startTime = start,
                startZoneOffset = zoneRules.getOffset(start),
                endTime = end,
                endZoneOffset = zoneRules.getOffset(end),
                metadata = sessionMetadata,
                exerciseType = ExerciseSessionRecord.EXERCISE_TYPE_CALISTHENICS,
                title = "Push-ups",
                notes = buildString {
                    append("$reps push-ups · Wear OS")
                    if (effortScore != null && effortScore in 1..10) {
                        append(" · effort $effortScore/10")
                    }
                },
                segments = listOf(pushUps),
            ),
        )

        val samples = heartRateSamples
            .asSequence()
            .filter { it.bpm in 1.0..300.0 }
            .map {
                HeartRateRecord.Sample(
                    time = Instant.ofEpochMilli(it.sampledAtEpochMilliseconds).coerceIn(start, end),
                    beatsPerMinute = it.bpm.toLong(),
                )
            }
            .distinctBy { it.time }
            .sortedBy { it.time }
            .toList()
        if (samples.isNotEmpty()) {
            records += HeartRateRecord(
                startTime = start,
                startZoneOffset = zoneRules.getOffset(start),
                endTime = end,
                endZoneOffset = zoneRules.getOffset(end),
                samples = samples,
                metadata = Metadata.activelyRecorded(
                    device = watch,
                    clientRecordId = "$externalId-heart-rate",
                    clientRecordVersion = 1,
                ),
            )
        }
        if (activeCalories > 0) {
            records += TotalCaloriesBurnedRecord(
                startTime = start,
                startZoneOffset = zoneRules.getOffset(start),
                endTime = end,
                endZoneOffset = zoneRules.getOffset(end),
                energy = Energy.kilocalories(activeCalories),
                metadata = Metadata.activelyRecorded(
                    device = watch,
                    clientRecordId = "$externalId-calories",
                    clientRecordVersion = 1,
                ),
            )
        }

        client().insertRecords(records)
        return true
    }

    private fun Instant.coerceIn(start: Instant, end: Instant): Instant = when {
        this < start -> start
        this > end -> end
        else -> this
    }

    private fun client(): HealthConnectClient = HealthConnectClient.getOrCreate(context)
}
