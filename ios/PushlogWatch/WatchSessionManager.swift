// Coordinates the live phone session with the sensor session on Apple Watch.

import Combine
import Foundation
import HealthKit
import WatchConnectivity

private let appGroup = "group.za.co.codecraftsolutions.pushlog"

@MainActor
final class WatchSessionManager: NSObject, ObservableObject {

    @Published var todayCount: Int = 0
    @Published var streak: Int = 0
    @Published var bestDay: Int = 0
    @Published var allTime: Int = 0
    @Published var liveReps: Int = 0
    @Published var livePhase: String = "READY"
    @Published var liveElapsed: Double = 0
    @Published var liveStartedAt: Date?
    @Published var trackingState: String = "READY"
    @Published var isLiveActive: Bool = false
    @Published var isPaused: Bool = false
    @Published var currentHeartRate: Double = 0
    @Published var isAwaitingEffort: Bool = false
    @Published var effortScore: Int?

    weak var workoutManager: WatchWorkoutManager? {
        didSet {
            flushPendingStartIfPossible()
        }
    }

    private var activeSessionID: String?
    private var pendingStart: (sessionID: String, startedAt: Date)?
    private var pendingWorkoutConfiguration: HKWorkoutConfiguration?

    override init() {
        super.init()
        loadColdStartFallback()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    func handleWorkoutConfigurationLaunch(
        _ workoutConfiguration: HKWorkoutConfiguration? = nil
    ) {
        if let workoutConfiguration {
            pendingWorkoutConfiguration = workoutConfiguration
        }
        if WCSession.isSupported() {
            // applicationContext is what this Watch sent. Recovery needs the
            // latest context received from the companion iPhone.
            handleMessage(WCSession.default.receivedApplicationContext)
        }
        guard !isLiveActive else { return }
        requestSync()
    }

    func elapsed(at date: Date) -> Double {
        guard isLiveActive, let liveStartedAt else { return liveElapsed }
        return max(liveElapsed, date.timeIntervalSince(liveStartedAt))
    }

    func addReps(_ count: Int) {
        todayCount += count
        persistSnapshot()

        sendToPhone(["type": "addReps", "count": count], queued: true) { [weak self] reply in
            Task { @MainActor in
                self?.handleMessage(reply)
            }
        }
    }

    func requestSync() {
        sendToPhone(["type": "requestSync"], queued: true) { [weak self] reply in
            Task { @MainActor in
                self?.handleMessage(reply)
            }
        }
    }

    func sendMetrics(heartRate bpm: Double, activeCalories: Double, sampledAt: Date = Date()) {
        currentHeartRate = bpm

        var message: [String: Any] = [
            "type": "metrics",
            "bpm": bpm,
            "activeCalories": activeCalories,
            "sampledAtEpochMilliseconds": sampledAt.timeIntervalSince1970 * 1_000
        ]
        if let activeSessionID {
            message["sessionID"] = activeSessionID
        }

        if WCSession.isSupported(),
           WCSession.default.activationState == .activated {
            do {
                try WCSession.default.updateApplicationContext(message)
            } catch {
                NSLog(
                    "[Pushlog][Watch] Failed to publish metrics context: %@",
                    error.localizedDescription
                )
            }
        }

        sendToPhone(message, queued: false)
    }

    func togglePauseFromWatch() {
        guard let activeSessionID else { return }

        let nextPausedState = !isPaused
        isPaused = nextPausedState

        if nextPausedState {
            workoutManager?.pauseWorkout(sessionID: activeSessionID)
        } else {
            workoutManager?.resumeWorkout(sessionID: activeSessionID)
        }

        sendWatchControl(nextPausedState ? "pause" : "resume")
    }

    func requestEndFromWatch() {
        sendWatchControl("end")
    }

    func setEffort(_ score: Int) {
        guard let activeSessionID, (1...10).contains(score) else { return }
        effortScore = score
        sendToPhone(
            [
                "type": "effort",
                "sessionID": activeSessionID,
                "effortScore": score
            ],
            queued: true
        )
    }

    func notifyWorkoutStopped(sessionID: String) {
        sendToPhone(
            [
                "type": "workoutStopped",
                "sessionID": sessionID
            ],
            queued: true
        )
    }

    func notifyWorkoutSaved(sessionID: String) {
        sendToPhone(
            [
                "type": "workoutSaved",
                "sessionID": sessionID
            ],
            queued: true
        )
    }

    func notifyWorkoutFailed(sessionID: String?, reason: String) {
        var message: [String: Any] = [
            "type": "workoutFailed",
            "reason": reason
        ]
        if let sessionID {
            message["sessionID"] = sessionID
        }
        sendToPhone(message, queued: true)
    }

    private func loadColdStartFallback() {
        guard let defaults = UserDefaults(suiteName: appGroup) else { return }
        todayCount = defaults.integer(forKey: "todayCount")
        streak = defaults.integer(forKey: "streak")
        bestDay = defaults.integer(forKey: "bestDay")
        allTime = defaults.integer(forKey: "allTime")
    }

    private func persistSnapshot() {
        guard let defaults = UserDefaults(suiteName: appGroup) else { return }
        defaults.set(todayCount, forKey: "todayCount")
        defaults.set(streak, forKey: "streak")
        defaults.set(bestDay, forKey: "bestDay")
        defaults.set(allTime, forKey: "allTime")
    }

    private func handleMessage(_ message: [String: Any]) {
        guard let type = message["type"] as? String else { return }

        switch type {
        case "snapshot":
            applySnapshot(message)

        case "sessionStarted":
            guard
                let sessionID = PushlogWatchProtocol.sessionID(in: message)
            else { return }

            let startDate = (message["startedAt"] as? Double).map {
                Date(timeIntervalSinceReferenceDate: $0)
            } ?? Date()
            startLiveSession(sessionID: sessionID, startedAt: startDate)

        case "liveUpdate":
            guard matchesActiveSession(message) else { return }
            if let reps = message["reps"] as? Int { liveReps = reps }
            if let phase = message["phase"] as? String { livePhase = phase }
            if let elapsed = message["elapsed"] as? Double { liveElapsed = elapsed }
            if let state = message["trackingState"] as? String { trackingState = state }
            if let paused = message["isPaused"] as? Bool { isPaused = paused }
            if let active = message["isActive"] as? Bool { isLiveActive = active }

        case "trackingState":
            guard matchesActiveSession(message) else { return }
            if let phase = message["phase"] as? String { trackingState = phase }
            if let elapsed = message["elapsed"] as? Double { liveElapsed = elapsed }
            if let paused = message["isPaused"] as? Bool { isPaused = paused }
            applyWorkoutPauseState()

        case "sessionStopped":
            guard
                matchesActiveSession(message),
                let sessionID = activeSessionID
            else { return }

            let reps = message["reps"] as? Int ?? liveReps
            let duration = message["duration"] as? Double ?? liveElapsed
            let endedAt = (message["endedAt"] as? Double).map {
                Date(timeIntervalSinceReferenceDate: $0)
            } ?? Date()

            liveElapsed = duration
            isLiveActive = false
            isPaused = false
            isAwaitingEffort = true
            workoutManager?.stopWorkout(
                sessionID: sessionID,
                reps: reps,
                duration: duration,
                endedAt: endedAt
            )

        case "sessionSave":
            guard matchesActiveSession(message), let sessionID = activeSessionID else { return }
            let reps = message["reps"] as? Int ?? liveReps
            let duration = message["duration"] as? Double ?? liveElapsed
            let endedAt = (message["endedAt"] as? Double).map {
                Date(timeIntervalSinceReferenceDate: $0)
            } ?? Date()
            let savedEffort = (message["effortScore"] as? NSNumber)?.intValue ?? effortScore
            workoutManager?.saveStoppedWorkout(
                sessionID: sessionID,
                reps: reps,
                duration: duration,
                endedAt: endedAt,
                effortScore: savedEffort
            )
            clearLiveState()

        case "sessionDiscard", "sessionCancelled":
            guard matchesActiveSession(message), let sessionID = activeSessionID else { return }
            workoutManager?.discardWorkout(sessionID: sessionID)
            clearLiveState()

        default:
            break
        }
    }

    private func applySnapshot(_ message: [String: Any]) {
        if let today = message["todayCount"] as? Int { todayCount = today }
        if let s = message["streak"] as? Int { streak = s }
        if let best = message["bestDay"] as? Int { bestDay = best }
        if let at = message["allTime"] as? Int { allTime = at }
        persistSnapshot()

        guard
            (message["activeSession"] as? Bool) == true,
            (message["requestedWatch"] as? Bool) == true,
            let sessionID = PushlogWatchProtocol.sessionID(in: message)
        else { return }

        let ownership = message["ownership"] as? String
        guard ownership != "stopped", ownership != "committed", ownership != "discarded" else { return }

        if let reps = message["reps"] as? Int { liveReps = reps }
        if let elapsed = message["elapsed"] as? Double { liveElapsed = elapsed }

        let startDate = (message["startedAt"] as? Double).map {
            Date(timeIntervalSinceReferenceDate: $0)
        } ?? Date().addingTimeInterval(-liveElapsed)

        startLiveSession(sessionID: sessionID, startedAt: startDate)
    }

    private func startLiveSession(sessionID: String, startedAt: Date) {
        guard let workoutManager else {
            pendingStart = (sessionID, startedAt)
            return
        }

        if activeSessionID == sessionID, isLiveActive {
            sendSessionAck(sessionID: sessionID, accepted: true)
            return
        }

        if let activeSessionID, activeSessionID != sessionID {
            workoutManager.discardWorkout(sessionID: activeSessionID)
        }

        activeSessionID = sessionID
        liveStartedAt = startedAt
        liveReps = 0
        liveElapsed = 0
        livePhase = "READY"
        trackingState = "LOCKED"
        isPaused = false
        isAwaitingEffort = false
        effortScore = nil

        let accepted = workoutManager.startWorkout(
            sessionID: sessionID,
            startDate: startedAt,
            configuration: pendingWorkoutConfiguration
        )
        if accepted {
            pendingWorkoutConfiguration = nil
        }
        isLiveActive = accepted
        sendSessionAck(sessionID: sessionID, accepted: accepted)
    }

    private func flushPendingStartIfPossible() {
        guard let pendingStart, workoutManager != nil else { return }
        self.pendingStart = nil
        startLiveSession(sessionID: pendingStart.sessionID, startedAt: pendingStart.startedAt)
    }

    private func applyWorkoutPauseState() {
        guard let activeSessionID else { return }
        if isPaused {
            workoutManager?.pauseWorkout(sessionID: activeSessionID)
        } else {
            workoutManager?.resumeWorkout(sessionID: activeSessionID)
        }
    }

    private func matchesActiveSession(_ message: [String: Any]) -> Bool {
        guard let activeSessionID else { return false }
        return PushlogWatchProtocol.matches(
            sessionID: activeSessionID,
            message: message
        )
    }

    private func sendSessionAck(sessionID: String, accepted: Bool) {
        sendToPhone(
            [
                "type": "sessionAck",
                "sessionID": sessionID,
                "accepted": accepted
            ],
            queued: true
        )
    }

    private func sendWatchControl(_ action: String) {
        guard let activeSessionID else { return }
        sendToPhone(
            [
                "type": "watchControl",
                "sessionID": activeSessionID,
                "action": action
            ],
            queued: true
        )
    }

    private func sendToPhone(
        _ message: [String: Any],
        queued: Bool,
        replyHandler: (([String: Any]) -> Void)? = nil
    ) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else {
            session.activate()
            return
        }

        if session.isReachable {
            session.sendMessage(
                message,
                replyHandler: replyHandler,
                errorHandler: { error in
                    NSLog(
                        "[Pushlog][Watch] Immediate phone transfer failed: %@",
                        error.localizedDescription
                    )
                    if queued, session.activationState == .activated {
                        session.transferUserInfo(message)
                    }
                }
            )
        } else if queued {
            session.transferUserInfo(message)
        }
    }

    private func clearLiveState() {
        activeSessionID = nil
        pendingStart = nil
        isLiveActive = false
        isPaused = false
        liveReps = 0
        liveElapsed = 0
        liveStartedAt = nil
        livePhase = "READY"
        trackingState = "READY"
        currentHeartRate = 0
        isAwaitingEffort = false
        effortScore = nil
    }
}

extension WatchSessionManager: WCSessionDelegate {

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if activationState == .activated {
            Task { @MainActor in
                self.requestSync()
                self.handleMessage(session.receivedApplicationContext)
            }
        } else if let error {
            NSLog(
                "[Pushlog][Watch] WCSession activation failed: %@",
                error.localizedDescription
            )
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        Task { @MainActor in
            self.handleMessage(message)
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        Task { @MainActor in
            self.handleMessage(message)
            replyHandler([:])
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        Task { @MainActor in
            self.handleMessage(applicationContext)
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any] = [:]
    ) {
        Task { @MainActor in
            self.handleMessage(userInfo)
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        if session.isReachable {
            Task { @MainActor in
                self.requestSync()
            }
        }
    }
}
