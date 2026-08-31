// The watch owns the live HealthKit session so Apple Watch can collect
// high-frequency heart rate and active-energy samples for the phone session.

import Combine
import Foundation
import HealthKit

@MainActor
final class WatchWorkoutManager: NSObject, ObservableObject {

    @Published var heartRate: Double = 0
    @Published var activeCalories: Double = 0
    @Published var isSessionActive: Bool = false
    @Published var isPaused: Bool = false

    weak var watchSessionManager: WatchSessionManager?

    private struct PendingWorkout {
        let sessionID: UUID
        var reps: Int
        var duration: TimeInterval
        var endedAt: Date
        var effortScore: Int?
    }

    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var activeSessionID: UUID?
    private var pendingWorkout: PendingWorkout?
    private var collectionEndedSessionID: UUID?
    private var saveAfterCollectionEnds = false

    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        var typesToShare: Set<HKSampleType> = [
            HKObjectType.workoutType()
        ]
        if #available(watchOS 11.0, *),
           let effortType = HKObjectType.quantityType(forIdentifier: .workoutEffortScore) {
            typesToShare.insert(effortType)
        }
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]

        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { _, _ in }
    }

    @discardableResult
    func startWorkout(
        sessionID: UUID,
        startDate: Date,
        configuration: HKWorkoutConfiguration? = nil
    ) -> Bool {
        if activeSessionID == sessionID, isSessionActive {
            return true
        }

        if let activeSessionID, activeSessionID != sessionID {
            discardWorkout(sessionID: activeSessionID)
        }

        let config = configuration ?? HKWorkoutConfiguration()
        if configuration == nil {
            config.activityType = .functionalStrengthTraining
            config.locationType = .indoor
        }

        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
            let liveBuilder = session.associatedWorkoutBuilder()

            session.delegate = self
            liveBuilder.delegate = self
            liveBuilder.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: config
            )

            workoutSession = session
            builder = liveBuilder
            activeSessionID = sessionID
            pendingWorkout = nil
            collectionEndedSessionID = nil
            saveAfterCollectionEnds = false
            heartRate = 0
            activeCalories = 0
            isPaused = false
            isSessionActive = true

            session.startActivity(with: startDate)
            liveBuilder.beginCollection(withStart: startDate) { [weak self] _, error in
                guard let error else { return }
                Task { @MainActor in
                    self?.watchSessionManager?.notifyWorkoutFailed(
                        sessionID: sessionID,
                        reason: error.localizedDescription
                    )
                }
            }

            return true
        } catch {
            watchSessionManager?.notifyWorkoutFailed(sessionID: sessionID, reason: error.localizedDescription)
            resetWorkoutState()
            return false
        }
    }

    func pauseWorkout(sessionID: UUID) {
        guard activeSessionID == sessionID, isSessionActive else { return }
        workoutSession?.pause()
        isPaused = true
    }

    func resumeWorkout(sessionID: UUID) {
        guard activeSessionID == sessionID, isSessionActive else { return }
        workoutSession?.resume()
        isPaused = false
    }

    func stopWorkout(sessionID: UUID, reps: Int, duration: TimeInterval, endedAt: Date) {
        guard activeSessionID == sessionID else { return }

        pendingWorkout = PendingWorkout(
            sessionID: sessionID,
            reps: reps,
            duration: duration,
            endedAt: endedAt,
            effortScore: nil
        )
        isSessionActive = false
        isPaused = false

        workoutSession?.end()

        guard let builder else {
            watchSessionManager?.notifyWorkoutFailed(sessionID: sessionID, reason: "Missing workout builder")
            resetWorkoutState()
            return
        }

        builder.endCollection(withEnd: endedAt) { [weak self] _, error in
            Task { @MainActor in
                self?.handleCollectionEnded(sessionID: sessionID, error: error)
            }
        }
    }

    func saveStoppedWorkout(
        sessionID: UUID,
        reps: Int,
        duration: TimeInterval,
        endedAt: Date,
        effortScore: Int?
    ) {
        guard activeSessionID == sessionID else { return }

        if pendingWorkout == nil {
            stopWorkout(sessionID: sessionID, reps: reps, duration: duration, endedAt: endedAt)
        }
        pendingWorkout = PendingWorkout(
            sessionID: sessionID,
            reps: reps,
            duration: duration,
            endedAt: endedAt,
            effortScore: effortScore
        )

        guard collectionEndedSessionID == sessionID else {
            saveAfterCollectionEnds = true
            return
        }

        finishPendingWorkout()
    }

    func discardWorkout(sessionID: UUID) {
        guard activeSessionID == sessionID || pendingWorkout?.sessionID == sessionID else { return }

        workoutSession?.end()
        builder?.discardWorkout()
        resetWorkoutState()
    }

    private func handleCollectionEnded(sessionID: UUID, error: Error?) {
        guard activeSessionID == sessionID else { return }

        if let error {
            watchSessionManager?.notifyWorkoutFailed(sessionID: sessionID, reason: error.localizedDescription)
            builder?.discardWorkout()
            resetWorkoutState()
            return
        }

        collectionEndedSessionID = sessionID
        watchSessionManager?.notifyWorkoutStopped(sessionID: sessionID)

        if saveAfterCollectionEnds {
            finishPendingWorkout()
        }
    }

    private func finishPendingWorkout() {
        guard
            let pendingWorkout,
            let builder,
            collectionEndedSessionID == pendingWorkout.sessionID
        else { return }

        let metadata: [String: Any] = [
            "PushlogRepCount": pendingWorkout.reps,
            "PushlogDuration": pendingWorkout.duration,
            "PushlogExternalSessionID": pendingWorkout.sessionID.uuidString
        ]

        builder.addMetadata(metadata) { [weak self] _, metadataError in
            if let metadataError {
                Task { @MainActor in
                    self?.watchSessionManager?.notifyWorkoutFailed(
                        sessionID: pendingWorkout.sessionID,
                        reason: metadataError.localizedDescription
                    )
                    self?.builder?.discardWorkout()
                    self?.resetWorkoutState()
                }
                return
            }

            builder.finishWorkout { [weak self] workout, finishError in
                Task { @MainActor in
                    if let finishError {
                        self?.watchSessionManager?.notifyWorkoutFailed(
                            sessionID: pendingWorkout.sessionID,
                            reason: finishError.localizedDescription
                        )
                        self?.builder?.discardWorkout()
                    } else {
                        if #available(watchOS 11.0, *),
                           let score = pendingWorkout.effortScore,
                           let workout {
                            do {
                                try await self?.saveEffortScore(score, for: workout)
                            } catch {
                                NSLog(
                                    "[Pushlog] Workout saved without effort score: %@",
                                    error.localizedDescription
                                )
                            }
                        }
                        self?.watchSessionManager?.notifyWorkoutSaved(sessionID: pendingWorkout.sessionID)
                    }
                    self?.resetWorkoutState()
                }
            }
        }
    }

    @available(watchOS 11.0, *)
    private func saveEffortScore(_ score: Int, for workout: HKWorkout) async throws {
        guard (1...10).contains(score) else { return }
        guard let effortType = HKObjectType.quantityType(forIdentifier: .workoutEffortScore) else {
            return
        }

        let sample = HKQuantitySample(
            type: effortType,
            quantity: HKQuantity(unit: .appleEffortScore(), doubleValue: Double(score)),
            start: workout.startDate,
            end: workout.endDate
        )
        try await healthStore.save(sample)
        _ = try await healthStore.relateWorkoutEffortSample(
            sample,
            with: workout,
            activity: nil
        )
    }

    private func resetWorkoutState() {
        workoutSession = nil
        builder = nil
        activeSessionID = nil
        pendingWorkout = nil
        collectionEndedSessionID = nil
        saveAfterCollectionEnds = false
        heartRate = 0
        activeCalories = 0
        isSessionActive = false
        isPaused = false
    }
}

extension WatchWorkoutManager: HKWorkoutSessionDelegate {

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        Task { @MainActor in
            self.isPaused = toState == .paused
        }
    }

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didFailWithError error: Error
    ) {
        Task { @MainActor in
            self.watchSessionManager?.notifyWorkoutFailed(
                sessionID: self.activeSessionID,
                reason: error.localizedDescription
            )
        }
    }
}

extension WatchWorkoutManager: HKLiveWorkoutBuilderDelegate {

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    nonisolated func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else { continue }

            switch quantityType.identifier {
            case HKQuantityTypeIdentifier.heartRate.rawValue:
                let stats = workoutBuilder.statistics(for: quantityType)
                let bpm = stats?.mostRecentQuantity()?.doubleValue(for: .count().unitDivided(by: .minute())) ?? 0
                Task { @MainActor in
                    self.heartRate = bpm
                    self.watchSessionManager?.sendMetrics(
                        heartRate: bpm,
                        activeCalories: self.activeCalories
                    )
                }

            case HKQuantityTypeIdentifier.activeEnergyBurned.rawValue:
                let stats = workoutBuilder.statistics(for: quantityType)
                let calories = stats?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                Task { @MainActor in
                    self.activeCalories = calories
                    self.watchSessionManager?.sendMetrics(
                        heartRate: self.heartRate,
                        activeCalories: calories
                    )
                }

            default:
                break
            }
        }
    }
}
