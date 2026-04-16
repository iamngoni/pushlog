import Combine
import Foundation
import HealthKit
import WatchConnectivity

struct WatchControlRequest: Identifiable, Equatable {
    enum Action: String {
        case pause
        case resume
        case end
    }

    let id = UUID()
    let sessionID: UUID
    let action: Action
}

enum HealthKitWriteOwner: Equatable {
    case phone
    case watch
}

@MainActor
final class PhoneSessionManager: NSObject, ObservableObject {
    @Published private(set) var isWatchConnected = false
    @Published private(set) var isWatchAppInstalled = false
    @Published private(set) var watchWorkoutStatus = "IPHONE ONLY"
    @Published var currentHeartRate: Double = 0
    @Published var watchControlRequest: WatchControlRequest?

    weak var store: PushLogStore?

    private enum WatchOwnership {
        case phone
        case requested
        case accepted
        case stopped
        case committed
        case discarded
    }

    private struct ActiveWorkout {
        let id: UUID
        let startedAt: Date
        let requestedWatch: Bool
        var ownership: WatchOwnership
        var lastReps: Int
        var lastDuration: TimeInterval
        var endedAt: Date?
    }

    private let healthStore = HKHealthStore()
    private let appGroupID = "group.za.co.codecraftsolutions.pushlog"
    private var activeWorkout: ActiveWorkout?
    private var lastLiveUpdateSent: Date?

    override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
        refreshWatchState()
    }

    func activateWithStore(_ store: PushLogStore) {
        self.store = store
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
        refreshWatchState()
        sendSnapshot()
    }

    var canUseWatchForWorkout: Bool {
        guard WCSession.isSupported() else { return false }
        let session = WCSession.default
        return session.isPaired && session.isWatchAppInstalled
    }

    var watchHandledHealthKit: Bool {
        guard let activeWorkout else { return false }
        return activeWorkout.ownership == .accepted || activeWorkout.ownership == .stopped
    }

    @discardableResult
    func beginLiveWorkout(startedAt: Date, devicePreference: LiveDevicePreference) -> UUID {
        refreshWatchState()

        let sessionID = UUID()
        let shouldUseWatch = devicePreference == .iphoneAndWatch && canUseWatchForWorkout
        activeWorkout = ActiveWorkout(
            id: sessionID,
            startedAt: startedAt,
            requestedWatch: shouldUseWatch,
            ownership: shouldUseWatch ? .requested : .phone,
            lastReps: 0,
            lastDuration: 0,
            endedAt: nil
        )
        lastLiveUpdateSent = nil
        currentHeartRate = 0
        watchWorkoutStatus = shouldUseWatch ? "WATCH REQUESTED" : "IPHONE ONLY"

        sendSnapshot()

        guard shouldUseWatch else {
            return sessionID
        }

        sendToWatch(startMessage(for: sessionID), queued: true)

        Task {
            await startWatchWorkoutApp(for: sessionID)
        }

        return sessionID
    }

    func sendLiveUpdate(reps: Int, phase: String, elapsed: Double, trackingState: String, isPaused: Bool) {
        guard var workout = activeWorkout else { return }

        workout.lastReps = reps
        workout.lastDuration = elapsed
        activeWorkout = workout

        guard workout.requestedWatch else { return }

        let now = Date()
        if let last = lastLiveUpdateSent, now.timeIntervalSince(last) < 0.9 {
            return
        }
        lastLiveUpdateSent = now

        sendToWatch(
            [
                "type": "liveUpdate",
                "sessionID": workout.id.uuidString,
                "reps": reps,
                "phase": phase,
                "elapsed": elapsed,
                "trackingState": trackingState,
                "isPaused": isPaused,
                "isActive": true
            ],
            queued: false
        )
    }

    func sendTrackingState(phase: String, elapsed: Double, isPaused: Bool) {
        guard let workout = activeWorkout, workout.requestedWatch else { return }

        sendToWatch(
            [
                "type": "trackingState",
                "sessionID": workout.id.uuidString,
                "phase": phase,
                "elapsed": elapsed,
                "isPaused": isPaused
            ],
            queued: false
        )
    }

    @discardableResult
    func stopLiveWorkout(sessionID: UUID?, reps: Int, duration: TimeInterval, endedAt: Date) -> HealthKitWriteOwner {
        guard var workout = activeWorkout else { return .phone }
        guard sessionID == nil || workout.id == sessionID else { return .phone }

        workout.lastReps = reps
        workout.lastDuration = duration
        workout.endedAt = endedAt

        switch workout.ownership {
        case .accepted:
            workout.ownership = .stopped
            activeWorkout = workout
            watchWorkoutStatus = "WATCH STOPPED"
            sendToWatch(
                [
                    "type": "sessionStopped",
                    "sessionID": workout.id.uuidString,
                    "reps": reps,
                    "duration": duration,
                    "endedAt": endedAt.timeIntervalSinceReferenceDate
                ],
                queued: true
            )
            return .watch

        case .requested:
            activeWorkout = workout
            watchWorkoutStatus = "PHONE FALLBACK"
            sendToWatch(
                [
                    "type": "sessionCancelled",
                    "sessionID": workout.id.uuidString
                ],
                queued: true
            )
            return .phone

        case .phone, .stopped, .committed, .discarded:
            activeWorkout = workout
            return workout.ownership == .stopped ? .watch : .phone
        }
    }

    @discardableResult
    func commitStoppedWorkout(sessionID: UUID?) -> HealthKitWriteOwner {
        guard var workout = activeWorkout else { return .phone }
        guard sessionID == nil || workout.id == sessionID else { return .phone }

        if workout.ownership == .stopped {
            workout.ownership = .committed
            activeWorkout = workout
            sendToWatch(
                [
                    "type": "sessionSave",
                    "sessionID": workout.id.uuidString,
                    "reps": workout.lastReps,
                    "duration": workout.lastDuration,
                    "endedAt": (workout.endedAt ?? Date()).timeIntervalSinceReferenceDate
                ],
                queued: true
            )
            clearActiveWorkout()
            return .watch
        }

        clearActiveWorkout()
        return .phone
    }

    func discardStoppedWorkout(sessionID: UUID?) {
        guard var workout = activeWorkout else { return }
        guard sessionID == nil || workout.id == sessionID else { return }

        if workout.requestedWatch {
            workout.ownership = .discarded
            sendToWatch(
                [
                    "type": "sessionDiscard",
                    "sessionID": workout.id.uuidString
                ],
                queued: true
            )
        }

        activeWorkout = workout
        clearActiveWorkout()
    }

    func cancelLiveWorkout(sessionID: UUID?) {
        guard let workout = activeWorkout else { return }
        guard sessionID == nil || workout.id == sessionID else { return }

        if workout.requestedWatch {
            sendToWatch(
                [
                    "type": "sessionCancelled",
                    "sessionID": workout.id.uuidString
                ],
                queued: true
            )
        }

        clearActiveWorkout()
    }

    func sendSnapshot() {
        guard WCSession.isSupported() else { return }
        let context = snapshotPayload()

        try? WCSession.default.updateApplicationContext(context)

        if let groupDefaults = UserDefaults(suiteName: appGroupID), let store {
            groupDefaults.set(store.todayCount, forKey: "todayCount")
            groupDefaults.set(store.streak, forKey: "streak")
            groupDefaults.set(store.bestDay, forKey: "bestDay")
            groupDefaults.set(store.totalAllTime, forKey: "allTime")
        }
    }

    private func clearActiveWorkout() {
        activeWorkout = nil
        currentHeartRate = 0
        lastLiveUpdateSent = nil
        refreshWatchState()
        sendSnapshot()
    }

    private func refreshWatchState() {
        guard WCSession.isSupported() else {
            isWatchConnected = false
            isWatchAppInstalled = false
            watchWorkoutStatus = "IPHONE ONLY"
            return
        }

        let session = WCSession.default
        isWatchConnected = session.isReachable
        isWatchAppInstalled = session.isPaired && session.isWatchAppInstalled

        if activeWorkout == nil {
            watchWorkoutStatus = isWatchAppInstalled ? "WATCH READY" : "IPHONE ONLY"
        }
    }

    private func startWatchWorkoutApp(for sessionID: UUID) async {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .functionalStrengthTraining
        configuration.locationType = .indoor

        do {
            try await healthStore.startWatchApp(toHandle: configuration)
            await MainActor.run {
                guard self.activeWorkout?.id == sessionID else { return }
                self.watchWorkoutStatus = "WATCH LAUNCHED"
                self.sendToWatch(self.startMessage(for: sessionID), queued: true)
            }
        } catch {
            await MainActor.run {
                guard var workout = self.activeWorkout, workout.id == sessionID, workout.ownership == .requested else { return }
                workout.ownership = .phone
                self.activeWorkout = workout
                self.watchWorkoutStatus = "PHONE FALLBACK"
            }
        }
    }

    private func startMessage(for sessionID: UUID) -> [String: Any] {
        guard let workout = activeWorkout, workout.id == sessionID else {
            return ["type": "noop"]
        }

        return [
            "type": "sessionStarted",
            "sessionID": workout.id.uuidString,
            "startedAt": workout.startedAt.timeIntervalSinceReferenceDate,
            "healthOwner": "watch"
        ]
    }

    private func snapshotPayload() -> [String: Any] {
        var payload: [String: Any] = [
            "type": "snapshot",
            "todayCount": store?.todayCount ?? 0,
            "streak": store?.streak ?? 0,
            "bestDay": store?.bestDay ?? 0,
            "allTime": store?.totalAllTime ?? 0,
            "activeSession": false
        ]

        if let workout = activeWorkout, workout.requestedWatch {
            payload["activeSession"] = true
            payload["sessionID"] = workout.id.uuidString
            payload["startedAt"] = workout.startedAt.timeIntervalSinceReferenceDate
            payload["reps"] = workout.lastReps
            payload["elapsed"] = workout.lastDuration
            payload["ownership"] = "\(workout.ownership)"
        }

        return payload
    }

    private func sendToWatch(_ message: [String: Any], queued: Bool) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default

        if session.isReachable {
            session.sendMessage(
                message,
                replyHandler: nil,
                errorHandler: { [weak self] _ in
                    guard queued else { return }
                    session.transferUserInfo(message)
                    Task { @MainActor in
                        self?.sendSnapshot()
                    }
                }
            )
        } else if queued {
            session.transferUserInfo(message)
            sendSnapshot()
        }
    }

    private func handleMessage(_ message: [String: Any]) -> [String: Any] {
        guard let type = message["type"] as? String else { return snapshotPayload() }

        switch type {
        case "addReps":
            if let count = message["count"] as? Int {
                store?.addManualReps(count)
            }
            sendSnapshot()
            return snapshotPayload()

        case "requestSync":
            sendSnapshot()
            return snapshotPayload()

        case "heartRate":
            if let bpm = message["bpm"] as? Double {
                currentHeartRate = bpm
            }

        case "sessionAck":
            handleSessionAck(message)

        case "watchControl":
            handleWatchControl(message)

        case "workoutStopped":
            watchWorkoutStatus = "WATCH STOPPED"

        case "workoutSaved":
            watchWorkoutStatus = "WATCH SAVED"

        case "workoutFailed":
            if let idString = message["sessionID"] as? String,
               let sessionID = UUID(uuidString: idString),
               var workout = activeWorkout,
               workout.id == sessionID,
               workout.ownership == .requested || workout.ownership == .accepted
            {
                workout.ownership = .phone
                activeWorkout = workout
            }
            watchWorkoutStatus = "WATCH FAILED"

        default:
            break
        }

        return snapshotPayload()
    }

    private func handleSessionAck(_ message: [String: Any]) {
        guard
            let idString = message["sessionID"] as? String,
            let sessionID = UUID(uuidString: idString),
            var workout = activeWorkout,
            workout.id == sessionID
        else { return }

        let accepted = message["accepted"] as? Bool ?? false
        workout.ownership = accepted ? .accepted : .phone
        activeWorkout = workout
        watchWorkoutStatus = accepted ? "WATCH RECORDING" : "PHONE FALLBACK"
    }

    private func handleWatchControl(_ message: [String: Any]) {
        guard
            let idString = message["sessionID"] as? String,
            let sessionID = UUID(uuidString: idString),
            let actionString = message["action"] as? String,
            let action = WatchControlRequest.Action(rawValue: actionString)
        else { return }

        watchControlRequest = WatchControlRequest(sessionID: sessionID, action: action)
    }
}

extension PhoneSessionManager: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            self.refreshWatchState()
            self.sendSnapshot()
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.refreshWatchState()
            self.sendSnapshot()

            if let workout = self.activeWorkout, workout.requestedWatch {
                self.sendToWatch(self.startMessage(for: workout.id), queued: true)
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            _ = self.handleMessage(message)
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        Task { @MainActor in
            replyHandler(self.handleMessage(message))
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}
