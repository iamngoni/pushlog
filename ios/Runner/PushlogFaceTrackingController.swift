import ARKit
import AVFoundation
import Flutter
import Foundation

final class PushlogFaceTrackingController: NSObject {
  private enum Phase: String {
    case unavailable
    case setup
    case calibrating
    case locked
    case countdown
    case active
    case lost
    case paused
  }

  private enum CameraAccess: String {
    case unknown
    case ready
    case denied
  }

  private enum MotionState {
    case up
    case down
  }

  private enum PauseReason {
    case manual
    case trackingLoss
  }

  private let session = ARSession()
  private var eventSink: FlutterEventSink?
  private var phase: Phase = ARFaceTrackingConfiguration.isSupported ? .setup : .unavailable
  private var cameraAccess = PushlogFaceTrackingController.resolveCameraAccess()
  private var repCount = 0
  private var statusLabel = "READY"
  private var movementLabel = "ALIGN"
  private var metricsLine = "ALIGN FACE WITH FRAME"
  private var countdownValue: Int?
  private var baselineDistance: Float?
  private var smoothedDistance: Float?
  private var calibrationSamples: [Float] = []
  private var motionState = MotionState.up
  private var downTimestamp: Date?
  private var repDurations: [TimeInterval] = []
  private var repTimestamps: [Date] = []
  private var manualAdjustmentCount = 0
  private var sessionStartedAt: Date?
  private var lastAnchorAt: Date?
  private var lossBeganAt: Date?
  private var pauseReason: PauseReason?
  private var countdownTask: Task<Void, Never>?

  override init() {
    super.init()
    session.delegate = self
    restoreSetupState()
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    DispatchQueue.main.async {
      switch call.method {
      case "status":
        self.refreshCameraAccess()
        result(self.snapshot())
      case "startPreflight":
        self.startPreflight(result: result)
      case "beginCountdown":
        self.beginCountdown()
        result(self.snapshot())
      case "togglePause":
        self.togglePause()
        result(self.snapshot())
      case "addManualRep":
        self.addManualRep()
        result(self.snapshot())
      case "finish":
        result(self.finishSession())
      case "cancel":
        self.cancel()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func startPreflight(result: @escaping FlutterResult) {
    guard ARFaceTrackingConfiguration.isSupported else {
      restoreSetupState()
      result(snapshot())
      return
    }

    refreshCameraAccess()
    switch cameraAccess {
    case .ready:
      beginPreflight()
      result(snapshot())
    case .denied:
      phase = .setup
      statusLabel = "BLOCKED"
      movementLabel = "SETTINGS"
      metricsLine = "ALLOW CAMERA ACCESS TO CONTINUE"
      emit()
      result(snapshot())
    case .unknown:
      statusLabel = "CAMERA"
      movementLabel = "PROMPT"
      metricsLine = "ALLOW FRONT CAMERA ACCESS"
      emit()
      AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
        DispatchQueue.main.async {
          guard let self else { return }
          self.refreshCameraAccess()
          if granted {
            self.beginPreflight()
          } else {
            self.phase = .setup
            self.statusLabel = "BLOCKED"
            self.movementLabel = "SETTINGS"
            self.metricsLine = "ALLOW CAMERA ACCESS TO CONTINUE"
            self.emit()
          }
          result(self.snapshot())
        }
      }
    }
  }

  private func beginPreflight() {
    resetSessionState()
    phase = .calibrating
    statusLabel = "LOCKING"
    movementLabel = "READY"
    metricsLine = "HOLD TOP POSITION"
    sessionStartedAt = Date()
    runFaceTrackingSession()
    emit()
  }

  private func beginCountdown() {
    guard phase == .locked, countdownValue == nil else { return }

    countdownTask?.cancel()
    countdownTask = Task { [weak self] in
      for value in stride(from: 3, through: 1, by: -1) {
        await MainActor.run {
          guard let self else { return }
          self.phase = .countdown
          self.countdownValue = value
          self.statusLabel = "COUNTDOWN"
          self.movementLabel = "HOLD"
          self.metricsLine = "GOING LIVE IN \(value)"
          self.emit()
        }

        try? await Task.sleep(nanoseconds: 1_000_000_000)
        if Task.isCancelled { return }
      }

      await MainActor.run {
        guard let self else { return }
        self.countdownValue = nil
        self.phase = .active
        self.statusLabel = "LOCKED"
        self.movementLabel = "UP"
        self.metricsLine = "PACE --   DEPTH READY   TRACK STABLE"
        self.motionState = .up
        self.downTimestamp = nil
        self.repCount = 0
        self.repDurations.removeAll(keepingCapacity: true)
        self.repTimestamps.removeAll(keepingCapacity: true)
        self.manualAdjustmentCount = 0
        self.sessionStartedAt = Date()
        self.lossBeganAt = nil
        self.pauseReason = nil
        self.emit()
      }
    }
  }

  private func togglePause() {
    guard ARFaceTrackingConfiguration.isSupported else { return }

    if phase == .paused, pauseReason == .manual {
      pauseReason = nil
      phase = sessionStartedAt == nil ? .calibrating : .active
      statusLabel = phase == .active ? "LOCKED" : "LOCKING"
      movementLabel = phase == .active ? movementLabel : "READY"
      metricsLine = phase == .active
        ? "PACE \(paceString)   DEPTH READY   TRACK STABLE"
        : "HOLD TOP POSITION"
      runFaceTrackingSession()
      emit()
      return
    }

    if phase != .paused {
      countdownTask?.cancel()
      session.pause()
      phase = .paused
      pauseReason = .manual
      statusLabel = "PAUSED"
      movementLabel = "PAUSED"
      metricsLine = "SESSION HOLD"
      emit()
    }
  }

  private func addManualRep() {
    repCount += 1
    manualAdjustmentCount += 1
    repTimestamps.append(Date())
    metricsLine = "MANUAL ADJUSTMENT ADDED"
    emit()
  }

  private func finishSession() -> [String: Any] {
    countdownTask?.cancel()
    session.pause()
    let finished = snapshot()
    restoreSetupState()
    emit()
    return finished
  }

  private func cancel() {
    countdownTask?.cancel()
    session.pause()
    restoreSetupState()
    emit()
  }

  private func runFaceTrackingSession() {
    let configuration = ARFaceTrackingConfiguration()
    configuration.isLightEstimationEnabled = true
    session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
  }

  private func restoreSetupState() {
    refreshCameraAccess()
    resetSessionState()
    countdownTask?.cancel()
    countdownValue = nil

    guard ARFaceTrackingConfiguration.isSupported else {
      phase = .unavailable
      statusLabel = "UNAVAILABLE"
      movementLabel = "FACE ID ONLY"
      metricsLine = "TRUEDEPTH FRONT CAMERA REQUIRED"
      return
    }

    phase = .setup
    statusLabel = "READY"
    movementLabel = "ALIGN"

    switch cameraAccess {
    case .unknown:
      metricsLine = "ALLOW FRONT CAMERA ACCESS"
    case .ready:
      metricsLine = "ALIGN FACE WITH FRAME"
    case .denied:
      metricsLine = "OPEN SETTINGS TO ENABLE CAMERA"
    }
  }

  private func resetSessionState() {
    repCount = 0
    baselineDistance = nil
    smoothedDistance = nil
    calibrationSamples.removeAll(keepingCapacity: true)
    motionState = .up
    downTimestamp = nil
    repDurations.removeAll(keepingCapacity: true)
    repTimestamps.removeAll(keepingCapacity: true)
    sessionStartedAt = nil
    lastAnchorAt = nil
    manualAdjustmentCount = 0
    pauseReason = nil
    lossBeganAt = nil
  }

  private func refreshCameraAccess() {
    cameraAccess = Self.resolveCameraAccess()
  }

  private static func resolveCameraAccess() -> CameraAccess {
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized:
      return .ready
    case .notDetermined:
      return .unknown
    case .denied, .restricted:
      return .denied
    @unknown default:
      return .denied
    }
  }

  private func process(distance rawDistance: Float, at timestamp: Date) {
    let smoothed = smoothedDistance.map { ($0 * 0.84) + (rawDistance * 0.16) } ?? rawDistance
    smoothedDistance = smoothed

    if baselineDistance == nil || phase == .calibrating {
      calibrationSamples.append(smoothed)

      if calibrationSamples.count >= 18 {
        let sorted = calibrationSamples.sorted()
        baselineDistance = sorted[sorted.count / 2]
        phase = .locked
        statusLabel = "LOCKED"
        movementLabel = "READY"
        metricsLine = "FACE LOCK CONFIRMED   TAP BEGIN"
        emit()
      }
      return
    }

    guard phase == .active, pauseReason == nil, let baselineDistance else {
      metricsLine = phase == .locked ? "FACE LOCK CONFIRMED   READY TO BEGIN" : metricsLine
      return
    }

    let downThreshold = baselineDistance * 0.78
    let upThreshold = baselineDistance * 0.93
    let eligibleForRep = repTimestamps.last.map { timestamp.timeIntervalSince($0) > 0.45 } ?? true

    switch motionState {
    case .up:
      movementLabel = "UP"
      if smoothed < downThreshold {
        motionState = .down
        downTimestamp = timestamp
        movementLabel = "DOWN"
        metricsLine = "DEPTH GOOD   PRESS UP"
        emit()
      } else {
        metricsLine = "PACE \(paceString)   DEPTH READY   TRACK STABLE"
      }
    case .down:
      movementLabel = "DOWN"
      if smoothed > upThreshold, eligibleForRep {
        motionState = .up
        repCount += 1
        repTimestamps.append(timestamp)

        if let downTimestamp {
          repDurations.append(timestamp.timeIntervalSince(downTimestamp))
        }

        movementLabel = "UP"
        metricsLine = "PACE \(paceString)   DEPTH GOOD   TRACK STABLE"
        emit()
      }
    }
  }

  private var paceString: String {
    guard !repDurations.isEmpty else { return "--" }
    let average = repDurations.reduce(0, +) / Double(repDurations.count)
    return String(format: "%.1fs", average)
  }

  private func snapshot() -> [String: Any] {
    var payload: [String: Any] = [
      "isSupported": ARFaceTrackingConfiguration.isSupported,
      "cameraAccess": cameraAccess.rawValue,
      "phase": phase.rawValue,
      "repCount": repCount,
      "manualAdjustments": manualAdjustmentCount,
      "statusLabel": statusLabel,
      "movementLabel": movementLabel,
      "metricsLine": metricsLine
    ]

    if let countdownValue {
      payload["countdownValue"] = countdownValue
    }
    if !repDurations.isEmpty {
      payload["averageRepDuration"] = repDurations.reduce(0, +) / Double(repDurations.count)
    }
    return payload
  }

  private func emit() {
    eventSink?(snapshot())
  }
}

extension PushlogFaceTrackingController: FlutterStreamHandler {
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

extension PushlogFaceTrackingController: ARSessionDelegate {
  func session(_ session: ARSession, didUpdate frame: ARFrame) {
    guard phase != .unavailable else { return }

    let now = Date()
    if let lastAnchorAt, now.timeIntervalSince(lastAnchorAt) > 0.7, phase != .calibrating, countdownValue == nil {
      phase = .lost
      statusLabel = "LOST"
      movementLabel = "HOLD"
      metricsLine = "BRING FACE BACK INTO FRAME"
      lossBeganAt = lossBeganAt ?? now
      emit()
    }

    if phase == .lost,
       let lossBeganAt,
       now.timeIntervalSince(lossBeganAt) > 1.6,
       sessionStartedAt != nil
    {
      phase = .paused
      pauseReason = .trackingLoss
      statusLabel = "PAUSED"
      movementLabel = "PAUSED"
      metricsLine = "AUTO PAUSED · WAITING FOR LOCK"
      emit()
    }

    switch frame.camera.trackingState {
    case .notAvailable, .limited:
      if phase == .locked || phase == .active {
        phase = .lost
        statusLabel = "LOST"
        movementLabel = "HOLD"
        metricsLine = "MOVE PHONE INTO BETTER LIGHT"
        lossBeganAt = lossBeganAt ?? now
        emit()
      }
    case .normal:
      break
    }
  }

  func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
    guard phase != .unavailable else { return }
    guard let faceAnchor = anchors.compactMap({ $0 as? ARFaceAnchor }).first else { return }

    let timestamp = Date()
    lastAnchorAt = timestamp
    lossBeganAt = nil

    if phase == .lost || (phase == .paused && pauseReason == .trackingLoss) {
      phase = baselineDistance == nil ? .calibrating : .active
      statusLabel = baselineDistance == nil ? "LOCKING" : "LOCKED"
      movementLabel = baselineDistance == nil ? "READY" : "UP"
      metricsLine = sessionStartedAt == nil
        ? "FACE LOCK CONFIRMED   READY TO BEGIN"
        : "TRACK RESTORED   RESUMING LIVE COUNT"
      pauseReason = nil
      emit()
    }

    let translation = faceAnchor.transform.columns.3
    let distance = abs(translation.z)
    process(distance: distance, at: timestamp)
  }
}
