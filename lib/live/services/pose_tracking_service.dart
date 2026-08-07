//
//  pushlog
//  pose_tracking_service.dart
//
//  Created by Ngonidzashe Mangudya on 2026/04/16.
//  Copyright (c) 2026 Codecraft Solutions. All rights reserved.
//

import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pushlog/live/models/push_up_rep_counter.dart';

enum PoseTrackingPhase {
  /// Nothing running.
  idle,

  /// Opening the camera.
  starting,

  /// No usable camera on this device.
  unavailable,

  /// The user declined camera access.
  permissionDenied,

  /// Running, but no confident pose in frame yet.
  searching,

  /// A pose is visible and reps are being counted.
  counting,

  /// Held by the user.
  paused,
}

@immutable
class PoseTrackingSnapshot {
  const PoseTrackingSnapshot({
    this.phase = PoseTrackingPhase.idle,
    this.reps = 0,
    this.manualAdjustments = 0,
    this.issue = PushUpFormIssue.none,
    this.elbowAngle,
    this.lastDepthRatio,
  });

  final PoseTrackingPhase phase;
  final int reps;
  final int manualAdjustments;
  final PushUpFormIssue issue;
  final double? elbowAngle;
  final double? lastDepthRatio;

  bool get isRunning =>
      phase == PoseTrackingPhase.searching ||
      phase == PoseTrackingPhase.counting ||
      phase == PoseTrackingPhase.paused;

  bool get isPaused => phase == PoseTrackingPhase.paused;

  bool get isUsable =>
      phase != PoseTrackingPhase.unavailable &&
      phase != PoseTrackingPhase.permissionDenied;

  /// One short line telling the user what to do next.
  String get guidance => switch (phase) {
    PoseTrackingPhase.idle => 'Ready when you are',
    PoseTrackingPhase.starting => 'Opening the camera…',
    PoseTrackingPhase.unavailable => 'No camera available on this device',
    PoseTrackingPhase.permissionDenied =>
      'Allow camera access to count automatically',
    PoseTrackingPhase.paused => 'Paused',
    PoseTrackingPhase.searching =>
      'Prop your phone up so your whole body is in frame',
    PoseTrackingPhase.counting => switch (issue) {
      PushUpFormIssue.none => 'Counting',
      PushUpFormIssue.notVisible => 'Move back so your body fits in frame',
      PushUpFormIssue.bodyNotStraight => 'Keep your hips in line',
      PushUpFormIssue.tooShallow => 'Go a little deeper',
    },
  };

  PoseTrackingSnapshot copyWith({
    PoseTrackingPhase? phase,
    int? reps,
    int? manualAdjustments,
    PushUpFormIssue? issue,
    double? elbowAngle,
    double? lastDepthRatio,
  }) => PoseTrackingSnapshot(
    phase: phase ?? this.phase,
    reps: reps ?? this.reps,
    manualAdjustments: manualAdjustments ?? this.manualAdjustments,
    issue: issue ?? this.issue,
    elbowAngle: elbowAngle ?? this.elbowAngle,
    lastDepthRatio: lastDepthRatio ?? this.lastDepthRatio,
  );
}

/// Counts push-ups from the camera using on-device pose detection.
///
/// Replaces the TrueDepth face-distance tracker, which only ran on iPhones
/// with a front depth camera and could not tell a push-up from any other
/// movement toward the phone. ML Kit ships the same model on both platforms,
/// so the counting behaves identically — and because it locates joints, it
/// can check depth and body line rather than guessing from proximity.
///
/// Frames never leave the device.
class PoseTrackingService {
  PoseTrackingService({PushUpRepCounter? counter})
    : _counter = counter ?? PushUpRepCounter();

  /// Maps device orientation to the rotation ML Kit expects on Android.
  static const _orientationDegrees = <DeviceOrientation, int>{
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  final PushUpRepCounter _counter;
  final _controllerStream = StreamController<PoseTrackingSnapshot>.broadcast();

  PoseDetector? _detector;
  CameraController? _camera;
  CameraDescription? _description;
  PoseTrackingSnapshot _snapshot = const PoseTrackingSnapshot();

  /// Guards against queueing frames faster than the model can clear them.
  /// Without it the stream backs up within seconds and latency grows without
  /// bound.
  bool _isBusy = false;

  Stream<PoseTrackingSnapshot> get snapshots => _controllerStream.stream;

  PoseTrackingSnapshot get snapshot => _snapshot;

  /// The live controller, for rendering a preview. Null until [start].
  CameraController? get cameraController => _camera;

  /// Opens the camera and begins detecting.
  Future<PoseTrackingSnapshot> start() async {
    if (_camera != null) return _snapshot;
    _emit(_snapshot.copyWith(phase: PoseTrackingPhase.starting));

    final List<CameraDescription> cameras;
    try {
      cameras = await availableCameras();
    } on CameraException {
      return _emit(
        _snapshot.copyWith(phase: PoseTrackingPhase.unavailable),
      );
    }
    if (cameras.isEmpty) {
      return _emit(_snapshot.copyWith(phase: PoseTrackingPhase.unavailable));
    }

    // Back camera by default: the phone is propped up a metre away facing
    // the user, and the rear lens is both wider and better quality.
    final description = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
    _description = description;

    final camera = CameraController(
      description,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );

    try {
      await camera.initialize();
    } on CameraException catch (error) {
      final denied =
          error.code == 'CameraAccessDenied' ||
          error.code == 'CameraAccessDeniedWithoutPrompt' ||
          error.code == 'CameraAccessRestricted';
      return _emit(
        _snapshot.copyWith(
          phase: denied
              ? PoseTrackingPhase.permissionDenied
              : PoseTrackingPhase.unavailable,
        ),
      );
    }

    _camera = camera;
    _detector = PoseDetector(options: PoseDetectorOptions());
    _counter.reset();

    await camera.startImageStream(_onFrame);
    return _emit(
      _snapshot.copyWith(
        phase: PoseTrackingPhase.searching,
        reps: 0,
        manualAdjustments: 0,
      ),
    );
  }

  /// Holds counting without tearing the camera down, so resuming is instant.
  PoseTrackingSnapshot pause() {
    if (!_snapshot.isRunning || _snapshot.isPaused) return _snapshot;
    return _emit(_snapshot.copyWith(phase: PoseTrackingPhase.paused));
  }

  PoseTrackingSnapshot resume() {
    if (!_snapshot.isPaused) return _snapshot;
    return _emit(_snapshot.copyWith(phase: PoseTrackingPhase.searching));
  }

  /// Adds reps the camera missed. Unlike the old bridge this honours the
  /// amount asked for rather than always adding one.
  PoseTrackingSnapshot addManualReps(int count) {
    if (count <= 0) return _snapshot;
    _counter.addManual(count);
    return _emit(
      _snapshot.copyWith(
        reps: _counter.reps,
        manualAdjustments: _snapshot.manualAdjustments + 1,
      ),
    );
  }

  /// Stops the camera and returns the final count.
  Future<PoseTrackingSnapshot> stop() async {
    final camera = _camera;
    _camera = null;
    if (camera != null) {
      if (camera.value.isStreamingImages) {
        try {
          await camera.stopImageStream();
        } on CameraException {
          // Already torn down; the dispose below is what matters.
        }
      }
      await camera.dispose();
    }
    await _detector?.close();
    _detector = null;
    return _snapshot;
  }

  Future<void> dispose() async {
    await stop();
    await _controllerStream.close();
  }

  Future<void> _onFrame(CameraImage image) async {
    if (_isBusy || _snapshot.isPaused) return;
    final detector = _detector;
    final description = _description;
    final camera = _camera;
    if (detector == null || description == null || camera == null) return;

    _isBusy = true;
    try {
      final input = _toInputImage(image, description, camera);
      if (input == null) return;

      final poses = await detector.processImage(input);
      if (poses.isEmpty) {
        _emit(
          _snapshot.copyWith(
            phase: PoseTrackingPhase.searching,
            issue: PushUpFormIssue.notVisible,
          ),
        );
        return;
      }

      final pose = poses.first;
      final tick = _counter.update(
        timestamp: DateTime.now(),
        left: _side(
          pose,
          shoulder: PoseLandmarkType.leftShoulder,
          elbow: PoseLandmarkType.leftElbow,
          wrist: PoseLandmarkType.leftWrist,
          hip: PoseLandmarkType.leftHip,
          knee: PoseLandmarkType.leftKnee,
        ),
        right: _side(
          pose,
          shoulder: PoseLandmarkType.rightShoulder,
          elbow: PoseLandmarkType.rightElbow,
          wrist: PoseLandmarkType.rightWrist,
          hip: PoseLandmarkType.rightHip,
          knee: PoseLandmarkType.rightKnee,
        ),
      );

      _emit(
        _snapshot.copyWith(
          phase: PoseTrackingPhase.counting,
          reps: tick.reps,
          issue: tick.issue,
          elbowAngle: tick.elbowAngle,
          lastDepthRatio: tick.depthRatio ?? _snapshot.lastDepthRatio,
        ),
      );
    } on PlatformException {
      // A dropped frame is not worth surfacing; the next one will land.
    } finally {
      _isBusy = false;
    }
  }

  PoseSide? _side(
    Pose pose, {
    required PoseLandmarkType shoulder,
    required PoseLandmarkType elbow,
    required PoseLandmarkType wrist,
    required PoseLandmarkType hip,
    required PoseLandmarkType knee,
  }) {
    final points = [
      shoulder,
      elbow,
      wrist,
      hip,
      knee,
    ].map((type) => pose.landmarks[type]).toList();
    if (points.any((landmark) => landmark == null)) return null;

    PosePoint toPoint(PoseLandmark landmark) => PosePoint(
      x: landmark.x,
      y: landmark.y,
      likelihood: landmark.likelihood,
    );

    return PoseSide(
      shoulder: toPoint(points[0]!),
      elbow: toPoint(points[1]!),
      wrist: toPoint(points[2]!),
      hip: toPoint(points[3]!),
      knee: toPoint(points[4]!),
    );
  }

  /// Wraps a camera frame for ML Kit.
  ///
  /// The plugin only accepts single-plane NV21 on Android and BGRA8888 on
  /// iOS, which is why the controller is configured with those formats up
  /// front rather than converting here.
  InputImage? _toInputImage(
    CameraImage image,
    CameraDescription description,
    CameraController camera,
  ) {
    final rotation = _rotationFor(description, camera);
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw as int);
    if (format == null) return null;
    if (image.planes.length != 1) return null;

    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  InputImageRotation? _rotationFor(
    CameraDescription description,
    CameraController camera,
  ) {
    if (Platform.isIOS) {
      return InputImageRotationValue.fromRawValue(
        description.sensorOrientation,
      );
    }

    final deviceRotation = _orientationDegrees[camera.value.deviceOrientation];
    if (deviceRotation == null) return null;

    // The front camera is mirrored, so its compensation runs the other way.
    final compensated = description.lensDirection == CameraLensDirection.front
        ? (description.sensorOrientation + deviceRotation) % 360
        : (description.sensorOrientation - deviceRotation + 360) % 360;
    return InputImageRotationValue.fromRawValue(compensated);
  }

  PoseTrackingSnapshot _emit(PoseTrackingSnapshot next) {
    _snapshot = next;
    if (!_controllerStream.isClosed) _controllerStream.add(next);
    return next;
  }
}
