import Flutter
import Foundation
import HealthKit
import WatchConnectivity

final class PushlogWatchSessionManager: NSObject {
  private enum Ownership: String {
    case phone
    case requested
    case accepted
    case stopped
    case committed
    case discarded
  }

  private struct ActiveWorkout {
    let id: String
    let startedAt: Date
    let requestedWatch: Bool
    var ownership: Ownership
    var lastReps: Int
    var lastDuration: TimeInterval
    var endedAt: Date?
  }

  private let healthStore = HKHealthStore()
  private var activeWorkout: ActiveWorkout?
  private var eventSink: FlutterEventSink?
  private var lastLiveUpdateSent: Date?
  private var statusLabel = "IPHONE ONLY"
  private var currentHeartRate = 0.0
  private var currentActiveCalories = 0.0
  private var controlAction = ""
  private var controlValue = 0
  private var controlSequence = 0

  override init() {
    super.init()
    activate()
    refreshWatchState()
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    DispatchQueue.main.async {
      switch call.method {
      case "status":
        self.refreshWatchState()
        result(self.snapshot())
      case "beginLiveWorkout":
        result(self.beginLiveWorkout(call.arguments))
      case "sendLiveUpdate":
        self.sendLiveUpdate(call.arguments)
        result(nil)
      case "stopLiveWorkout":
        result(self.stopLiveWorkout(call.arguments))
      case "commitStoppedWorkout":
        result(self.commitStoppedWorkout(call.arguments))
      case "discardStoppedWorkout":
        self.discardStoppedWorkout(call.arguments)
        result(nil)
      case "cancelLiveWorkout":
        self.cancelLiveWorkout(call.arguments)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private var canUseWatchForWorkout: Bool {
    guard WCSession.isSupported() else { return false }
    let session = WCSession.default
    return session.isPaired && session.isWatchAppInstalled
  }

  private func activate() {
    guard WCSession.isSupported() else { return }
    WCSession.default.delegate = self
    WCSession.default.activate()
  }

  private func beginLiveWorkout(_ arguments: Any?) -> [String: Any] {
    refreshWatchState()

    guard
      let payload = arguments as? [String: Any],
      let sessionId = payload["sessionId"] as? String
    else {
      return snapshot()
    }

    let preferWatch = payload["preferWatch"] as? Bool ?? false
    let startedAt = date(
      millis: payload["startedAtMillisecondsSinceEpoch"],
      iso: payload["startedAt"]
    ) ?? Date()
    let shouldUseWatch = preferWatch && canUseWatchForWorkout

    activeWorkout = ActiveWorkout(
      id: sessionId,
      startedAt: startedAt,
      requestedWatch: shouldUseWatch,
      ownership: shouldUseWatch ? .requested : .phone,
      lastReps: 0,
      lastDuration: 0,
      endedAt: nil
    )
    lastLiveUpdateSent = nil
    currentHeartRate = 0
    currentActiveCalories = 0
    controlAction = ""
    controlValue = 0
    statusLabel = shouldUseWatch ? "WATCH REQUESTED" : "IPHONE ONLY"

    guard shouldUseWatch else {
      emit()
      return snapshot()
    }

    sendToWatch(startMessage(for: sessionId), queued: true)
    Task {
      await self.startWatchWorkoutApp(for: sessionId)
    }
    emit()
    return snapshot()
  }

  private func sendLiveUpdate(_ arguments: Any?) {
    guard var workout = activeWorkout else { return }
    guard let payload = arguments as? [String: Any] else { return }

    workout.lastReps = payload["reps"] as? Int ?? workout.lastReps
    workout.lastDuration = payload["elapsedSeconds"] as? Double ?? workout.lastDuration
    activeWorkout = workout

    guard workout.requestedWatch else { return }

    let now = Date()
    if let lastLiveUpdateSent, now.timeIntervalSince(lastLiveUpdateSent) < 0.9 {
      return
    }
    lastLiveUpdateSent = now

    sendToWatch(
      [
        "type": "liveUpdate",
        "sessionID": workout.id,
        "reps": workout.lastReps,
        "phase": payload["phase"] as? String ?? "LIVE",
        "elapsed": workout.lastDuration,
        "trackingState": payload["trackingState"] as? String ?? "READY",
        "isPaused": payload["isPaused"] as? Bool ?? false,
        "isActive": true
      ],
      queued: false
    )
  }

  private func stopLiveWorkout(_ arguments: Any?) -> String {
    guard var workout = activeWorkout else { return "phone" }
    guard matches(workout, arguments: arguments) else { return "phone" }
    guard let payload = arguments as? [String: Any] else { return "phone" }

    workout.lastReps = payload["reps"] as? Int ?? workout.lastReps
    workout.lastDuration = payload["durationSeconds"] as? Double ?? workout.lastDuration
    workout.endedAt = date(
      millis: payload["endedAtMillisecondsSinceEpoch"],
      iso: payload["endedAt"]
    ) ?? Date()

    switch workout.ownership {
    case .accepted:
      workout.ownership = .stopped
      activeWorkout = workout
      statusLabel = "WATCH STOPPED"
      sendToWatch(
        [
          "type": "sessionStopped",
          "sessionID": workout.id,
          "reps": workout.lastReps,
          "duration": workout.lastDuration,
          "endedAt": workout.endedAt?.timeIntervalSinceReferenceDate ?? Date().timeIntervalSinceReferenceDate
        ],
        queued: true
      )
      emit()
      return "watch"
    case .requested:
      workout.ownership = .phone
      activeWorkout = workout
      statusLabel = "PHONE FALLBACK"
      sendToWatch(
        ["type": "sessionCancelled", "sessionID": workout.id],
        queued: true
      )
      emit()
      return "phone"
    case .phone, .stopped, .committed, .discarded:
      activeWorkout = workout
      return workout.ownership == .stopped ? "watch" : "phone"
    }
  }

  private func commitStoppedWorkout(_ arguments: Any?) -> String {
    guard var workout = activeWorkout else { return "phone" }
    guard matches(workout, arguments: arguments) else { return "phone" }

    if workout.ownership == .stopped {
      workout.ownership = .committed
      activeWorkout = workout
      sendToWatch(
        [
          "type": "sessionSave",
          "sessionID": workout.id,
          "reps": workout.lastReps,
          "duration": workout.lastDuration,
          "endedAt": workout.endedAt?.timeIntervalSinceReferenceDate ?? Date().timeIntervalSinceReferenceDate
        ],
        queued: true
      )
      clearActiveWorkout()
      return "watch"
    }

    clearActiveWorkout()
    return "phone"
  }

  private func discardStoppedWorkout(_ arguments: Any?) {
    guard var workout = activeWorkout else { return }
    guard matches(workout, arguments: arguments) else { return }

    if workout.requestedWatch {
      workout.ownership = .discarded
      sendToWatch(
        ["type": "sessionDiscard", "sessionID": workout.id],
        queued: true
      )
    }

    activeWorkout = workout
    clearActiveWorkout()
  }

  private func cancelLiveWorkout(_ arguments: Any?) {
    guard let workout = activeWorkout else { return }
    guard matches(workout, arguments: arguments) else { return }

    if workout.requestedWatch {
      sendToWatch(
        ["type": "sessionCancelled", "sessionID": workout.id],
        queued: true
      )
    }

    clearActiveWorkout()
  }

  private func refreshWatchState() {
    guard WCSession.isSupported() else {
      statusLabel = "IPHONE ONLY"
      return
    }

    let session = WCSession.default
    if activeWorkout == nil {
      statusLabel = session.isPaired && session.isWatchAppInstalled
        ? "WATCH READY"
        : "IPHONE ONLY"
    }
  }

  private func startWatchWorkoutApp(for sessionId: String) async {
    let configuration = HKWorkoutConfiguration()
    configuration.activityType = .functionalStrengthTraining
    configuration.locationType = .indoor

    do {
      try await healthStore.startWatchApp(toHandle: configuration)
      await MainActor.run {
        guard self.activeWorkout?.id == sessionId else { return }
        self.statusLabel = "WATCH LAUNCHED"
        self.sendToWatch(self.startMessage(for: sessionId), queued: true)
        self.emit()
      }
    } catch {
      await MainActor.run {
        guard var workout = self.activeWorkout,
              workout.id == sessionId,
              workout.ownership == .requested
        else { return }
        workout.ownership = .phone
        self.activeWorkout = workout
        self.statusLabel = "PHONE FALLBACK"
        self.emit()
      }
    }
  }

  private func startMessage(for sessionId: String) -> [String: Any] {
    guard let workout = activeWorkout, workout.id == sessionId else {
      return ["type": "noop"]
    }

    return [
      "type": "sessionStarted",
      "sessionID": workout.id,
      "startedAt": workout.startedAt.timeIntervalSinceReferenceDate,
      "healthOwner": "watch"
    ]
  }

  private func sendToWatch(_ message: [String: Any], queued: Bool) {
    guard WCSession.isSupported() else { return }
    let session = WCSession.default

    if session.isReachable {
      session.sendMessage(
        message,
        replyHandler: nil,
        errorHandler: { _ in
          if queued {
            session.transferUserInfo(message)
          }
        }
      )
    } else if queued {
      session.transferUserInfo(message)
    }
  }

  private func handleMessage(_ message: [String: Any]) {
    guard let type = message["type"] as? String else { return }

    switch type {
    case "metrics", "heartRate":
      currentHeartRate = (message["bpm"] as? NSNumber)?.doubleValue ?? currentHeartRate
      currentActiveCalories =
        (message["activeCalories"] as? NSNumber)?.doubleValue ?? currentActiveCalories
    case "sessionAck":
      handleSessionAck(message)
    case "watchControl":
      handleWatchControl(message)
    case "addReps":
      handleAddReps(message)
    case "requestSync":
      break
    case "workoutStopped":
      statusLabel = "WATCH STOPPED"
    case "workoutSaved":
      statusLabel = "WATCH SAVED"
    case "workoutFailed":
      if var workout = activeWorkout {
        workout.ownership = .phone
        activeWorkout = workout
      }
      statusLabel = "WATCH FAILED"
    default:
      break
    }

    emit()
  }

  private func handleSessionAck(_ message: [String: Any]) {
    guard
      let sessionId = message["sessionID"] as? String,
      var workout = activeWorkout,
      workout.id == sessionId
    else { return }

    let accepted = message["accepted"] as? Bool ?? false
    workout.ownership = accepted ? .accepted : .phone
    activeWorkout = workout
    statusLabel = accepted ? "WATCH RECORDING" : "PHONE FALLBACK"
  }

  private func handleWatchControl(_ message: [String: Any]) {
    guard
      let workout = activeWorkout,
      matches(workout, arguments: message),
      let action = message["action"] as? String,
      ["pause", "resume", "end"].contains(action)
    else { return }

    controlAction = action
    controlValue = 0
    controlSequence += 1
  }

  private func handleAddReps(_ message: [String: Any]) {
    let count = (message["count"] as? NSNumber)?.intValue ?? 0
    guard count > 0 else { return }
    controlAction = "addReps"
    controlValue = count
    controlSequence += 1
  }

  private func clearActiveWorkout() {
    activeWorkout = nil
    currentHeartRate = 0
    currentActiveCalories = 0
    lastLiveUpdateSent = nil
    refreshWatchState()
    emit()
  }

  private func matches(_ workout: ActiveWorkout, arguments: Any?) -> Bool {
    guard let payload = arguments as? [String: Any] else { return true }
    guard let sessionId = (payload["sessionId"] ?? payload["sessionID"]) as? String else {
      return true
    }
    return workout.id == sessionId
  }

  private func date(millis: Any?, iso: Any?) -> Date? {
    if let millis = millis as? Double {
      return Date(timeIntervalSince1970: millis / 1000)
    }
    if let millis = millis as? Int {
      return Date(timeIntervalSince1970: Double(millis) / 1000)
    }
    if let raw = iso as? String {
      return ISO8601DateFormatter().date(from: raw)
    }
    return nil
  }

  private func snapshot() -> [String: Any] {
    if WCSession.isSupported() {
      let session = WCSession.default
      var payload: [String: Any] = [
        "type": "snapshot",
        "isSupported": true,
        "isPaired": session.isPaired,
        "isAppInstalled": session.isWatchAppInstalled,
        "isReachable": session.isReachable,
        "statusLabel": statusLabel,
        "currentHeartRate": currentHeartRate,
        "activeCalories": currentActiveCalories,
        "controlAction": controlAction,
        "controlValue": controlValue,
        "controlSequence": controlSequence
      ]
      if let workout = activeWorkout {
        payload["activeSession"] = true
        payload["sessionID"] = workout.id
        payload["startedAt"] = workout.startedAt.timeIntervalSinceReferenceDate
        payload["reps"] = workout.lastReps
        payload["elapsed"] = workout.lastDuration
        payload["ownership"] = workout.ownership.rawValue
      } else {
        payload["activeSession"] = false
      }
      return payload
    }

    return [
      "type": "snapshot",
      "isSupported": false,
      "isPaired": false,
      "isAppInstalled": false,
      "isReachable": false,
      "statusLabel": "IPHONE ONLY",
      "currentHeartRate": 0,
      "activeCalories": 0,
      "controlAction": "",
      "controlValue": 0,
      "controlSequence": controlSequence
    ]
  }

  private func emit() {
    eventSink?(snapshot())
  }
}

extension PushlogWatchSessionManager: FlutterStreamHandler {
  func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    eventSink = events
    emit()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }
}

extension PushlogWatchSessionManager: WCSessionDelegate {
  func session(
    _ session: WCSession,
    activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {
    DispatchQueue.main.async {
      self.refreshWatchState()
      self.emit()
    }
  }

  func sessionReachabilityDidChange(_ session: WCSession) {
    DispatchQueue.main.async {
      self.refreshWatchState()
      self.emit()
    }
  }

  func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
    DispatchQueue.main.async {
      self.handleMessage(message)
    }
  }

  func session(
    _ session: WCSession,
    didReceiveApplicationContext applicationContext: [String: Any]
  ) {
    DispatchQueue.main.async {
      self.handleMessage(applicationContext)
    }
  }

  func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
    DispatchQueue.main.async {
      self.handleMessage(userInfo)
    }
  }

  func session(
    _ session: WCSession,
    didReceiveMessage message: [String: Any],
    replyHandler: @escaping ([String: Any]) -> Void
  ) {
    DispatchQueue.main.async {
      self.handleMessage(message)
      replyHandler(self.snapshot())
    }
  }

  func sessionDidBecomeInactive(_ session: WCSession) {}

  func sessionDidDeactivate(_ session: WCSession) {
    session.activate()
  }
}
