import ARKit
import AVFoundation
import Combine
import Foundation
import SceneKit
import SwiftUI

@MainActor
final class FaceTrackingSessionController: NSObject, ObservableObject {
    enum Phase: Equatable {
        case setup
        case calibrating
        case locked
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

    @Published private(set) var phase: Phase
    @Published private(set) var repCount = 0
    @Published private(set) var statusLabel = "READY"
    @Published private(set) var movementLabel = "READY"
    @Published private(set) var metricsLine = "ALIGN FACE WITH FRAME"
    @Published private(set) var cameraAccess: CameraAccessState

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

    var isSupported: Bool {
        ARFaceTrackingConfiguration.isSupported
    }

    var canStartSession: Bool {
        isSupported && cameraAccess != .denied
    }

    var setupTitle: String {
        guard isSupported else { return "TRUEDEPTH REQUIRED" }

        switch cameraAccess {
        case .unknown:
            return "ALLOW FRONT CAMERA"
        case .ready:
            return "READY TO LOCK"
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
            return "START WILL TRIGGER THE CAMERA PERMISSION PROMPT."
        case .ready:
            return "START LIVE THEN HOLD THE TOP OF THE REP FOR A QUICK LOCK."
        case .denied:
            return "CAMERA ACCESS IS OFF FOR PUSHLOG. ENABLE IT IN SETTINGS."
        }
    }

    var overlayTitle: String? {
        switch phase {
        case .calibrating:
            return "LOCKING"
        case .lost:
            return "FACE LOST"
        case .paused:
            return "PAUSED"
        case .unavailable:
            return "UNAVAILABLE"
        case .setup, .locked:
            return nil
        }
    }

    var overlayDetail: String? {
        switch phase {
        case .calibrating:
            return "Hold the top position and let the front camera establish your baseline."
        case .lost:
            return "Bring your face and shoulders back into frame. Counting will continue once lock returns."
        case .paused:
            return "Tracking is paused. Resume when you're set to continue."
        case .unavailable:
            return "This device cannot run TrueDepth face tracking."
        case .setup, .locked:
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
            beginTrackingWhenPossible()
        case .unknown:
            requestCameraAccessAndStart()
        case .denied:
            phase = .setup
            statusLabel = "BLOCKED"
            movementLabel = "SETTINGS"
            metricsLine = "ALLOW CAMERA ACCESS TO CONTINUE"
        }
    }

    func togglePause() {
        guard isSupported, let sceneView else { return }

        if phase == .paused {
            runFaceTrackingSession(on: sceneView, options: [])
            phase = baselineDistance == nil ? .calibrating : .locked
            statusLabel = baselineDistance == nil ? "LOCKING" : "LOCKED"
            movementLabel = baselineDistance == nil ? "READY" : movementLabel
            metricsLine = baselineDistance == nil ? "HOLD TOP POSITION" : metricsLine
        } else {
            sceneView.session.pause()
            phase = .paused
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
    }

    func finishSession() -> LiveSessionResult {
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
        sceneView?.session.pause()
        restoreSetupState()
    }

    private func beginTrackingWhenPossible() {
        resetSessionState()
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
                    controller.beginTrackingWhenPossible()
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
                movementLabel = "UP"
                metricsLine = "PACE --   DEPTH READY   TRACK STABLE"
            }

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
        guard phase != .paused, phase != .unavailable else { return }

        if let lastAnchorAt, Date().timeIntervalSince(lastAnchorAt) > 0.6, phase != .calibrating {
            phase = .lost
            statusLabel = "LOST"
            movementLabel = "HOLD"
            metricsLine = "BRING FACE BACK INTO FRAME"
        }

        switch frame.camera.trackingState {
        case .notAvailable, .limited:
            if phase == .locked {
                phase = .lost
                statusLabel = "LOST"
                movementLabel = "HOLD"
                metricsLine = "MOVE PHONE INTO BETTER LIGHT"
            }
        case .normal:
            break
        }
    }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        guard phase != .paused, phase != .unavailable else { return }
        guard let faceAnchor = anchors.compactMap({ $0 as? ARFaceAnchor }).first else { return }

        let timestamp = Date()
        lastAnchorAt = timestamp

        if phase == .lost {
            phase = baselineDistance == nil ? .calibrating : .locked
            statusLabel = baselineDistance == nil ? "LOCKING" : "LOCKED"
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
