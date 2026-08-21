//
//  pushlog
//  face_tracking_service.dart
//
//  Created by Ngonidzashe Mangudya on 2026/08/21.
//  Copyright (c) 2026 Codecraft Solutions. All rights reserved.
//

import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:pushlog/live/models/face_rep_counter.dart';

enum FaceTrackingPhase {
  /// Nothing running.
  idle,

  /// Opening the camera.
  starting,

  /// No usable front camera on this device.
  unavailable,

  /// The user declined camera access.
  permissionDenied,

  /// Running, but no face over the phone yet.
  searching,

  /// A face is in frame; measuring the top of the rep.
  calibrating,

  /// Range locked. Waiting for the user to start the session.
  ready,

  /// Session live, reps counting.
  counting,

  /// Held by the user.
  paused,
}

@immutable
class FaceTrackingSnapshot {
  const FaceTrackingSnapshot({
    this.phase = FaceTrackingPhase.idle,
    this.reps = 0,
    this.manualAdjustments = 0,
    this.issue = FaceRepIssue.none,
    this.sizeRatio,
    this.lastDepthRatio,
  });

  final FaceTrackingPhase phase;
  final int reps;
  final int manualAdjustments;
  final FaceRepIssue issue;

  /// How close the face is right now, as a multiple of its calibrated size
  /// at the top of a rep. Null before calibration.
  final double? sizeRatio;

  /// Depth of the most recently completed rep, 0 to 1.
  final double? lastDepthRatio;

  bool get isRunning =>
      phase == FaceTrackingPhase.searching ||
      phase == FaceTrackingPhase.calibrating ||
      phase == FaceTrackingPhase.ready ||
      phase == FaceTrackingPhase.counting ||
      phase == FaceTrackingPhase.paused;

  bool get isPaused => phase == FaceTrackingPhase.paused;

  bool get isUsable =>
      phase != FaceTrackingPhase.unavailable &&
      phase != FaceTrackingPhase.permissionDenied;

  /// Whether the range is set, so a session can start counting.
  bool get isReadyToCount =>
      phase == FaceTrackingPhase.ready ||
      phase == FaceTrackingPhase.counting ||
      phase == FaceTrackingPhase.paused;

  /// One short line telling the user what to do next.
  String get guidance => switch (phase) {
    FaceTrackingPhase.idle => 'Ready when you are',
    FaceTrackingPhase.starting => 'Opening the camera…',
    FaceTrackingPhase.unavailable => 'No front camera available on this device',
    FaceTrackingPhase.permissionDenied =>
      'Allow camera access to count automatically',
    FaceTrackingPhase.paused => 'Paused',
    FaceTrackingPhase.searching =>
      'Lay your phone on the floor, screen up, under your face',
    FaceTrackingPhase.calibrating => switch (issue) {
      FaceRepIssue.tooClose => 'Straighten your arms and hold at the top',
      _ => 'Hold at the top while we set your range',
    },
    FaceTrackingPhase.ready => 'Range set — start when you are ready',
    FaceTrackingPhase.counting => switch (issue) {
      FaceRepIssue.notVisible => 'Keep your face over the phone',
      FaceRepIssue.tooShallow => 'Go a little deeper',
      _ => 'Counting',
    },
  };

  FaceTrackingSnapshot copyWith({
    FaceTrackingPhase? phase,
    int? reps,
    int? manualAdjustments,
    FaceRepIssue? issue,
    double? sizeRatio,
    double? lastDepthRatio,
  }) => FaceTrackingSnapshot(
    phase: phase ?? this.phase,
    reps: reps ?? this.reps,
    manualAdjustments: manualAdjustments ?? this.manualAdjustments,
    issue: issue ?? this.issue,
    sizeRatio: sizeRatio ?? this.sizeRatio,
    lastDepthRatio: lastDepthRatio ?? this.lastDepthRatio,
  );
}

/// Counts push-ups from the front camera while the phone lies screen-up on
/// the floor.
///
/// This is the arrangement the feature was always built around — phone down,
/// face descending toward it — and the one the TrueDepth tracker it replaces
/// used. The difference is what reads the distance: TrueDepth face tracking
/// only ever ran on iPhones with a depth camera and left Android with no
/// automatic counting at all, whereas apparent face size works on any front
/// camera. See [FaceRepCounter] for why size is a sound proxy for distance.
///
/// Frames never leave the device.
class FaceTrackingService {
  FaceTrackingService({FaceRepCounter? counter})
    : _counter = counter ?? FaceRepCounter();

  final FaceRepCounter _counter;
  final _controllerStream = StreamController<FaceTrackingSnapshot>.broadcast();

  FaceDetector? _detector;
  CameraController? _camera;
  CameraDescription? _description;
  FaceTrackingSnapshot _snapshot = const FaceTrackingSnapshot();
  bool _isCounting = false;

  /// Guards against queueing frames faster than the model can clear them.
  /// Without it the stream backs up within seconds and latency grows without
  /// bound.
  bool _isBusy = false;

  Stream<FaceTrackingSnapshot> get snapshots => _controllerStream.stream;

  FaceTrackingSnapshot get snapshot => _snapshot;

  /// The live controller, for rendering a preview. Null until [start].
  CameraController? get cameraController => _camera;

  /// Opens the front camera and begins looking for a face.
  Future<FaceTrackingSnapshot> start() async {
    if (_camera != null) return _snapshot;
    _emit(_snapshot.copyWith(phase: FaceTrackingPhase.starting));

    final List<CameraDescription> cameras;
    try {
      cameras = await availableCameras();
    } on CameraException {
      return _emit(_snapshot.copyWith(phase: FaceTrackingPhase.unavailable));
    }
    if (cameras.isEmpty) {
      return _emit(_snapshot.copyWith(phase: FaceTrackingPhase.unavailable));
    }

    // Front camera: the phone is face-up on the floor beneath the user, so
    // the rear lens is pointed at the ground.
    final description = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
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
      // A phone lying flat has no meaningful portrait or landscape, and what
      // the sensors report for it is arbitrary. Pinning the orientation
      // makes the rotation handed to the detector deterministic instead —
      // and it has to be right, because a face fed in sideways usually is
      // not detected at all.
      await camera.lockCaptureOrientation(DeviceOrientation.portraitUp);
    } on CameraException catch (error) {
      final denied =
          error.code == 'CameraAccessDenied' ||
          error.code == 'CameraAccessDeniedWithoutPrompt' ||
          error.code == 'CameraAccessRestricted';
      return _emit(
        _snapshot.copyWith(
          phase: denied
              ? FaceTrackingPhase.permissionDenied
              : FaceTrackingPhase.unavailable,
        ),
      );
    }

    _camera = camera;
    // The defaults are exactly what is wanted: fast mode, and no landmarks,
    // contours, expressions or cross-frame identities. Only the width of the
    // box matters here, and each of those extras costs frame rate that rep
    // timing depends on.
    _detector = FaceDetector(options: FaceDetectorOptions());
    _counter.reset();
    _isCounting = false;

    await camera.startImageStream(_onFrame);
    return _emit(
      _snapshot.copyWith(
        phase: FaceTrackingPhase.searching,
        reps: 0,
        manualAdjustments: 0,
      ),
    );
  }

  /// Starts counting toward a session, discarding any reps that happened
  /// while the user was getting into position. The calibrated range is kept.
  FaceTrackingSnapshot beginCounting() {
    if (!_snapshot.isReadyToCount) return _snapshot;
    _counter.startSession();
    _isCounting = true;
    return _emit(
      _snapshot.copyWith(
        phase: FaceTrackingPhase.counting,
        reps: 0,
        manualAdjustments: 0,
      ),
    );
  }

  /// Throws away the calibrated range so the next held position sets a new
  /// one, keeping the reps already counted.
  FaceTrackingSnapshot recalibrate() {
    _counter.recalibrate();
    return _emit(
      _snapshot.copyWith(
        phase: FaceTrackingPhase.calibrating,
        issue: FaceRepIssue.holdStill,
      ),
    );
  }

  /// Holds counting without tearing the camera down, so resuming is instant.
  FaceTrackingSnapshot pause() {
    if (!_snapshot.isRunning || _snapshot.isPaused) return _snapshot;
    return _emit(_snapshot.copyWith(phase: FaceTrackingPhase.paused));
  }

  FaceTrackingSnapshot resume() {
    if (!_snapshot.isPaused) return _snapshot;
    return _emit(
      _snapshot.copyWith(
        phase: _isCounting
            ? FaceTrackingPhase.counting
            : FaceTrackingPhase.searching,
      ),
    );
  }

  /// Adds reps the camera missed. Unlike the old bridge this honours the
  /// amount asked for rather than always adding one.
  FaceTrackingSnapshot addManualReps(int count) {
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
  Future<FaceTrackingSnapshot> stop() async {
    final camera = _camera;
    _camera = null;
    _isCounting = false;
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
    if (detector == null || description == null) return;

    _isBusy = true;
    try {
      final input = _toInputImage(image, description);
      if (input == null) return;

      final faces = await detector.processImage(input);
      final face = _nearestFace(faces);
      final tick = _counter.update(
        timestamp: DateTime.now(),
        faceWidth: face?.boundingBox.width,
        frameWidth: image.width.toDouble(),
      );

      _emit(
        _snapshot.copyWith(
          phase: _phaseFor(tick),
          reps: tick.reps,
          issue: tick.issue,
          sizeRatio: tick.sizeRatio ?? _snapshot.sizeRatio,
          lastDepthRatio: tick.depthRatio ?? _snapshot.lastDepthRatio,
        ),
      );
    } on PlatformException {
      // A dropped frame is not worth surfacing; the next one will land.
    } finally {
      _isBusy = false;
    }
  }

  /// Which UI phase a counter tick lands in.
  ///
  /// Only [beginCounting] may move into counting, so a rep thrown while the
  /// user is still setting up never lands in a session.
  FaceTrackingPhase _phaseFor(FaceRepTick tick) {
    if (_isCounting) return FaceTrackingPhase.counting;
    if (tick.issue == FaceRepIssue.notVisible) {
      return FaceTrackingPhase.searching;
    }
    return tick.isCalibrated
        ? FaceTrackingPhase.ready
        : FaceTrackingPhase.calibrating;
  }

  /// The largest face in frame, which is the closest one — the user, not
  /// somebody walking past in the background.
  Face? _nearestFace(List<Face> faces) {
    if (faces.isEmpty) return null;
    return faces.reduce((a, b) {
      final areaA = a.boundingBox.width * a.boundingBox.height;
      final areaB = b.boundingBox.width * b.boundingBox.height;
      return areaB > areaA ? b : a;
    });
  }

  /// Wraps a camera frame for ML Kit.
  ///
  /// The plugin only accepts single-plane NV21 on Android and BGRA8888 on
  /// iOS, which is why the controller is configured with those formats up
  /// front rather than converting here.
  InputImage? _toInputImage(CameraImage image, CameraDescription description) {
    final rotation = _rotationFor(description);
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

  /// Capture orientation is locked to portrait in [start], so the device
  /// contributes no rotation of its own and only the sensor's mounting
  /// matters.
  InputImageRotation? _rotationFor(CameraDescription description) {
    if (Platform.isIOS) {
      return InputImageRotationValue.fromRawValue(
        description.sensorOrientation,
      );
    }
    return InputImageRotationValue.fromRawValue(
      description.sensorOrientation % 360,
    );
  }

  FaceTrackingSnapshot _emit(FaceTrackingSnapshot next) {
    _snapshot = next;
    if (!_controllerStream.isClosed) _controllerStream.add(next);
    return next;
  }
}
