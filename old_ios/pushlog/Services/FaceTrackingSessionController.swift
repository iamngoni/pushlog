import ARKit
import AVFoundation
import Combine
import Foundation
import SceneKit
import SwiftUI
import UIKit

@MainActor
final class FaceTrackingSessionController: NSObject, ObservableObject {
    enum Phase: Equatable {
        case setup
        case calibrating
        case locked
        case countdown
        case lost
        case paused
        case unavailable
    }

    enum MotionState {
        case up
        case down
    }

    enum CameraAccessState: Equatable {
        case unknown
        case ready
        case denied
    }

    private enum SessionMode {
        case setup
        case preflight
        case active
    }

    private enum PauseReason {
        case manual
        case trackingLoss
    }

    @Published private(set) var phase: Phase
    @Published private(set) var repCount = 0
    @Published private(set) var statusLabel = "READY"
    @Published private(set) var movementLabel = "READY"
    @Published private(set) var metricsLine = "ALIGN FACE WITH FRAME"
    @Published private(set) var cameraAccess: CameraAccessState
    @Published private(set) var countdownValue: Int?

    private weak var sceneView: ARSCNView?
    private var sessionStartedAt: Date?
    private var lastAnchorAt: Date?
    private var baselineDistance: Float?
    private var smoothedDistance: Float?
    private var calibrationSamples: [Float] = []
    private var motionState: MotionState = .up
    private var downTimestamp: Date?
    private var repDurations: [TimeInterval] = []
    private var repTimestamps: [Date] = []
    private var manualAdjustmentCount = 0
    private var shouldStartWhenAttached = false
    private var sessionMode: SessionMode = .setup
    private var pauseReason: PauseReason?
    private var lossBeganAt: Date?
    private var countdownTask: Task<Void, Never>?
    private let impactGenerator = UIImpactFeedbackGenerator(style: .rigid)

    var isSupported: Bool {
        ARFaceTrackingConfiguration.isSupported
    }

    var canStartSession: Bool {
        isSupported && cameraAccess != .denied
    }

    var canBeginCountdown: Bool {
        sessionMode == .preflight && phase == .locked && countdownValue == nil
    }

    var isInPreflightMode: Bool {
        sessionMode == .preflight
    }

    var isActivelyCounting: Bool {
        sessionMode == .active
    }

    var setupTitle: String {
        guard isSupported else { return "TRUEDEPTH REQUIRED" }

        switch cameraAccess {
        case .unknown:
            return "ALLOW FRONT CAMERA"
        case .ready:
            return "READY FOR PRE-FLIGHT"
        case .denied:
            return "CAMERA BLOCKED"
        }
    }

    var setupChecklist: String {
        guard isSupported else {
            return "FRONT TRUEDEPTH IPHONE\nFACE ID HARDWARE NEEDED\nLIVE MODE DISABLED"
        }

        switch cameraAccess {
        case .unknown:
            return "FACE IN FRAME\nALLOW CAMERA ACCESS\nHOLD TOP POSITION"
        case .ready:
            return "FACE IN FRAME\nSHOULDERS VISIBLE\nPHONE AT 45°"
        case .denied:
            return "OPEN IOS SETTINGS\nALLOW CAMERA ACCESS\nRETURN TO LIVE MODE"
        }
    }

    var setupFootnote: String {
        guard isSupported else {
            return "LIVE COUNTING NEEDS TRUEDEPTH FACE TRACKING HARDWARE."
        }

        switch cameraAccess {
        case .unknown:
            return "START WILL TRIGGER THE CAMERA PROMPT, THEN OPEN PRE-FLIGHT."
        case .ready:
            return "PRE-FLIGHT CONFIRMS FACE LOCK, THEN A SHORT COUNTDOWN STARTS THE SESSION."
        case .denied:
            return "CAMERA ACCESS IS OFF FOR PUSHLOG. ENABLE IT IN SETTINGS."
        }
    }

    var preflightTitle: String {
        switch phase {
        case .calibrating:
            return "LOCKING"
        case .locked:
            return countdownValue == nil ? "LOCK CONFIRMED" : "COUNTDOWN"
        case .countdown:
            return "COUNTDOWN"
        case .lost:
            return "FACE LOST"
        case .paused:
            return "PAUSED"
        case .unavailable:
            return "UNAVAILABLE"
        case .setup:
            return "READY"
        }
    }

    var preflightPrimaryActionTitle: String {
        if let countdownValue {
            return "\(countdownValue)"
        }

        if canBeginCountdown {
            return "BEGIN"
        }

        return phase == .lost ? "REALIGN" : "HOLD"
    }

    var overlayTitle: String? {
        if let countdownValue {
            return "\(countdownValue)"
        }

        switch phase {
        case .calibrating:
            return "LOCKING"
        case .lost:
            return "FACE LOST"
        case .paused:
            return pauseReason == .trackingLoss ? "AUTO PAUSED" : "PAUSED"
        case .unavailable:
            return "UNAVAILABLE"
        case .setup, .locked, .countdown:
            return nil
        }
    }

    var overlayDetail: String? {
        if countdownValue != nil {
            return "HOLD THE TOP POSITION. COUNTING STARTS WHEN THE COUNTDOWN ENDS."
        }

        switch phase {
        case .calibrating:
            return "HOLD THE TOP POSITION AND LET THE FRONT CAMERA ESTABLISH YOUR BASELINE."
        case .lost:
            return "BRING YOUR FACE AND SHOULDERS BACK INTO FRAME. THE SESSION WILL RESUME WHEN LOCK RETURNS."
        case .paused:
            return pauseReason == .trackingLoss
                ? "TRACKING DROPPED LONG ENOUGH TO PAUSE COUNTING. LOCK WILL RESUME AUTOMATICALLY."
                : "TRACKING IS PAUSED. RESUME WHEN YOU ARE READY."
        case .unavailable:
            return "THIS DEVICE CANNOT RUN TRUEDEPTH FACE TRACKING."
        case .setup, .locked, .countdown:
            return nil
        }
    }

    var actionTitle: String {
        switch phase {
        case .unavailable:
            return "NO LOCK"
        case .paused:
            return "PAUSED"
        case .lost:
            return "HOLD"
        default:
            return movementLabel
        }
    }

    override init() {
        cameraAccess = Self.resolveCameraAccess()
        phase = ARFaceTrackingConfiguration.isSupported ? .setup : .unavailable
        super.init()
        restoreSetupState()
    }

    func attach(to sceneView: ARSCNView) {
        self.sceneView = sceneView
        sceneView.session.delegate = self
        sceneView.delegate = self
        sceneView.scene = SCNScene()
        sceneView.automaticallyUpdatesLighting = true
        sceneView.preferredFramesPerSecond = 60
        sceneView.contentMode = .scaleAspectFill
        sceneView.backgroundColor = .clear

        if shouldStartWhenAttached, cameraAccess == .ready {
            shouldStartWhenAttached = false
            runFaceTrackingSession(on: sceneView, options: [.resetTracking, .removeExistingAnchors])
        }
    }

    func startTracking() {
        guard isSupported else {
            restoreSetupState()
            return
        }

        refreshCameraAccess()

        switch cameraAccess {
        case .ready:
            beginPreflightWhenPossible()
        case .unknown:
            requestCameraAccessAndStart()
        case .denied:
            phase = .setup
            statusLabel = "BLOCKED"
            movementLabel = "SETTINGS"
            metricsLine = "ALLOW CAMERA ACCESS TO CONTINUE"
        }
    }

    func confirmFaceLock() {
        guard canBeginCountdown else { return }

        countdownTask?.cancel()
        countdownTask = Task { [weak self] in
            guard let self else { return }

            self.phase = .countdown

            for value in stride(from: 3, through: 1, by: -1) {
                self.countdownValue = value
                self.statusLabel = "COUNTDOWN"
                self.movementLabel = "HOLD"
                self.metricsLine = "GOING LIVE IN \(value)"
                try? await Task.sleep(for: .seconds(1))

                if Task.isCancelled || self.phase == .lost || self.phase == .paused {
                    self.countdownValue = nil
                    return
                }
            }

            self.countdownValue = nil
            self.sessionMode = .active
            self.sessionStartedAt = Date()
            self.phase = .locked
            self.statusLabel = "LOCKED"
            self.movementLabel = "UP"
            self.metricsLine = "PACE --   DEPTH READY   TRACK STABLE"
            self.motionState = .up
            self.downTimestamp = nil
            self.repCount = 0
            self.repDurations.removeAll(keepingCapacity: true)
            self.repTimestamps.removeAll(keepingCapacity: true)
            self.lossBeganAt = nil
            self.pauseReason = nil
            self.impactGenerator.prepare()
        }
    }

    func togglePause() {
        guard isSupported, let sceneView else { return }

        if phase == .paused, pauseReason == .manual {
            runFaceTrackingSession(on: sceneView, options: [])
            pauseReason = nil
            phase = sessionMode == .active ? .locked : .calibrating
            statusLabel = sessionMode == .active ? "LOCKED" : "LOCKING"
            movementLabel = sessionMode == .active ? movementLabel : "READY"
            metricsLine = sessionMode == .active ? "PACE \(paceString)   DEPTH READY   TRACK STABLE" : "HOLD TOP POSITION"
            return
        }

        if phase != .paused {
            countdownTask?.cancel()
            sceneView.session.pause()
            phase = .paused
            pauseReason = .manual
            statusLabel = "PAUSED"
            movementLabel = "PAUSED"
            metricsLine = "SESSION HOLD"
        }
    }

    func addManualRep() {
        repCount += 1
        manualAdjustmentCount += 1
        repTimestamps.append(Date())
        metricsLine = "MANUAL ADJUSTMENT ADDED"
        impactGenerator.impactOccurred(intensity: 0.85)
        impactGenerator.prepare()
    }

    func finishSession() -> LiveSessionResult {
        countdownTask?.cancel()
        sceneView?.session.pause()
        shouldStartWhenAttached = false

        let duration = max(0, Date().timeIntervalSince(sessionStartedAt ?? Date()))
        let averageRepDuration = repDurations.isEmpty ? nil : repDurations.reduce(0, +) / Double(repDurations.count)
        let result = LiveSessionResult(
            reps: repCount,
            duration: duration,
            averageRepDuration: averageRepDuration,
            manualAdjustments: manualAdjustmentCount
        )

        restoreSetupState()
        return result
    }

    func resetForNewSession() {
        countdownTask?.cancel()
        sceneView?.session.pause()
        restoreSetupState()
    }

    private func beginPreflightWhenPossible() {
        resetSessionState()
        sessionMode = .preflight
        phase = .calibrating
        statusLabel = "LOCKING"
        movementLabel = "READY"
        metricsLine = "HOLD TOP POSITION"
        sessionStartedAt = Date()

        guard let sceneView else {
            shouldStartWhenAttached = true
            metricsLine = "PREPARING FRONT CAMERA"
            return
        }

        runFaceTrackingSession(on: sceneView, options: [.resetTracking, .removeExistingAnchors])
    }

    private func runFaceTrackingSession(on sceneView: ARSCNView, options: ARSession.RunOptions) {
        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = true
        sceneView.session.run(configuration, options: options)
    }

    private func requestCameraAccessAndStart() {
        statusLabel = "CAMERA"
        movementLabel = "PROMPT"
        metricsLine = "ALLOW FRONT CAMERA ACCESS"

        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            guard let controller = self else { return }

            Task { @MainActor [controller] in
                controller.refreshCameraAccess()

                if granted {
                    controller.beginPreflightWhenPossible()
                } else {
                    controller.phase = .setup
                    controller.statusLabel = "BLOCKED"
                    controller.movementLabel = "SETTINGS"
                    controller.metricsLine = "ALLOW CAMERA ACCESS TO CONTINUE"
                }
            }
        }
    }

    private func restoreSetupState() {
        refreshCameraAccess()
        resetSessionState()
        shouldStartWhenAttached = false
        countdownTask?.cancel()
        countdownValue = nil

        guard isSupported else {
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

    private func refreshCameraAccess() {
        cameraAccess = Self.resolveCameraAccess()
    }

    private static func resolveCameraAccess() -> CameraAccessState {
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
        sessionMode = .setup
        pauseReason = nil
        lossBeganAt = nil
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
                movementLabel = sessionMode == .active ? "UP" : "READY"
                metricsLine = sessionMode == .active
                    ? "PACE --   DEPTH READY   TRACK STABLE"
                    : "FACE LOCK CONFIRMED   TAP BEGIN"
            }

            return
        }

        guard sessionMode == .active, pauseReason == nil else {
            metricsLine = phase == .locked ? "FACE LOCK CONFIRMED   READY TO BEGIN" : metricsLine
            return
        }

        guard let baselineDistance else { return }

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
                impactGenerator.impactOccurred(intensity: 0.9)
                impactGenerator.prepare()
            }
        }
    }

    private var paceString: String {
        guard !repDurations.isEmpty else { return "--" }
        let average = repDurations.reduce(0, +) / Double(repDurations.count)
        return String(format: "%.1fs", average)
    }
}

extension FaceTrackingSessionController: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard phase != .unavailable else { return }

        let now = Date()

        if let lastAnchorAt, now.timeIntervalSince(lastAnchorAt) > 0.7, phase != .calibrating, countdownValue == nil {
            phase = .lost
            statusLabel = "LOST"
            movementLabel = "HOLD"
            metricsLine = "BRING FACE BACK INTO FRAME"
            lossBeganAt = lossBeganAt ?? now
        }

        if sessionMode == .active,
           let lossBeganAt,
           now.timeIntervalSince(lossBeganAt) > 1.6,
           phase == .lost
        {
            phase = .paused
            pauseReason = .trackingLoss
            statusLabel = "PAUSED"
            movementLabel = "PAUSED"
            metricsLine = "AUTO PAUSED · WAITING FOR LOCK"
        }

        switch frame.camera.trackingState {
        case .notAvailable, .limited:
            if phase == .locked {
                phase = .lost
                statusLabel = "LOST"
                movementLabel = "HOLD"
                metricsLine = "MOVE PHONE INTO BETTER LIGHT"
                lossBeganAt = lossBeganAt ?? now
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
            phase = baselineDistance == nil ? .calibrating : .locked
            statusLabel = baselineDistance == nil ? "LOCKING" : "LOCKED"
            movementLabel = baselineDistance == nil ? "READY" : "UP"
            metricsLine = sessionMode == .active
                ? "TRACK RESTORED   RESUMING LIVE COUNT"
                : "FACE LOCK CONFIRMED   READY TO BEGIN"
            pauseReason = nil
        }

        let translation = faceAnchor.transform.columns.3
        let distance = abs(translation.z)
        process(distance: distance, at: timestamp)
    }
}

extension FaceTrackingSessionController: ARSCNViewDelegate { }

struct FaceTrackingCameraView: UIViewRepresentable {
    @ObservedObject var controller: FaceTrackingSessionController

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView(frame: .zero)
        controller.attach(to: view)
        return view
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {
        controller.attach(to: uiView)
    }

    static func dismantleUIView(_ uiView: ARSCNView, coordinator: ()) {
        uiView.session.pause()
    }
}
