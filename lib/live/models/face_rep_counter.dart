//
//  pushlog
//  face_rep_counter.dart
//
//  Created by Ngonidzashe Mangudya on 2026/08/21.
//  Copyright (c) 2026 Codecraft Solutions. All rights reserved.
//

import 'dart:math' as math;

/// Where the body is in the rep, judged from how close the face is.
enum FaceRepPhase {
  /// No baseline yet, so nothing can be judged.
  calibrating,

  /// Arms extended, face at its furthest from the phone.
  up,

  /// Chest down, face near the phone.
  down,
}

/// Why a frame did not count, in the user's terms.
enum FaceRepIssue {
  /// Nothing wrong.
  none,

  /// No face in frame at all.
  notVisible,

  /// Calibrating, and the face is still moving too much to trust.
  holdStill,

  /// Calibrating while already low. Calibrating here would set the top of
  /// the rep to a position that is really the bottom, after which no rep
  /// could ever look deep enough to count.
  tooClose,

  /// Came down, but not far enough to count.
  tooShallow,
}

/// The counter's view of the world after one frame.
class FaceRepTick {
  const FaceRepTick({
    required this.reps,
    required this.phase,
    required this.issue,
    required this.countedRep,
    required this.isCalibrated,
    this.sizeRatio,
    this.depthRatio,
  });

  final int reps;
  final FaceRepPhase phase;
  final FaceRepIssue issue;

  /// True only on the frame that completed a repetition.
  final bool countedRep;

  /// Whether a baseline has been locked in. Until it has, nothing counts.
  final bool isCalibrated;

  /// Apparent face width over the calibrated baseline. 1.0 is the top of the
  /// rep; larger means closer to the phone. Null before calibration.
  final double? sizeRatio;

  /// How deep the last completed rep went, 0 to 1. Null until a rep
  /// completes.
  final double? depthRatio;
}

/// Counts push-ups from the apparent size of the user's face.
///
/// The phone lies screen-up on the floor and the user descends toward it, so
/// distance to the camera is the whole signal. Apparent size is the cheapest
/// way to read that distance: a face is a fixed real width, so its width in
/// pixels varies inversely with how far away it is, on every phone with a
/// front camera. A depth sensor would measure the same thing more precisely
/// and only on hardware that has one.
///
/// Width rather than height or area, because looking down tucks the chin and
/// foreshortens the face vertically. Temple-to-temple survives that; it also
/// survives an open mouth, which matters by the end of a set.
///
/// The swing is large — roughly half a metre at the top against fifteen
/// centimetres at the bottom, so the face more than doubles in width — which
/// is what makes a plain size ratio sufficient here.
///
/// Deliberately holds no camera or ML types, so all of this is testable
/// without a device.
class FaceRepCounter {
  FaceRepCounter({
    this.downRatio = 1.45,
    this.upRatio = 1.15,
    this.fullDepthRatio = 2,
    this.minRepInterval = const Duration(milliseconds: 400),
    this.calibrationSampleCount = 12,
    this.calibrationTolerance = 0.12,
    this.maxBaselineFaceFraction = 0.45,
  });

  /// Size ratio at or above which the user counts as having descended.
  final double downRatio;

  /// Size ratio at or below which the user counts as back at the top. Kept
  /// well clear of [downRatio]: a single midpoint would count repeatedly as
  /// the measurement jitters across it, which is the classic failure of
  /// naive rep counters.
  final double upRatio;

  /// Size ratio treated as a full-depth rep. Scores depth only, never
  /// decides whether a rep counted.
  final double fullDepthRatio;

  /// Rejects a second rep arriving impossibly soon after the last. Real
  /// push-ups do not come faster than this; jitter does.
  final Duration minRepInterval;

  /// Frames of a held position needed before a baseline is accepted.
  final int calibrationSampleCount;

  /// How much the samples in the calibration window may spread, relative to
  /// their median, and still be considered a held position.
  final double calibrationTolerance;

  /// Largest share of the frame width a face may fill and still be believed
  /// to be at the top of a rep.
  final double maxBaselineFaceFraction;

  final List<double> _window = [];

  int _reps = 0;
  double? _baselineWidth;
  FaceRepPhase _phase = FaceRepPhase.calibrating;
  DateTime? _lastRepAt;
  double? _largestRatioThisRep;

  int get reps => _reps;

  FaceRepPhase get phase => _phase;

  bool get isCalibrated => _baselineWidth != null;

  /// The face width, in pixels, that counts as the top of a rep. Null until
  /// calibration completes.
  double? get baselineWidth => _baselineWidth;

  /// Feeds one frame in and returns the resulting state.
  ///
  /// [faceWidth] is the detected face's width in pixels, or null when no
  /// face was found. [frameWidth] is the width of the frame it was found in,
  /// used only to sanity-check calibration.
  FaceRepTick update({
    required DateTime timestamp,
    required double? faceWidth,
    required double frameWidth,
  }) {
    if (faceWidth == null || faceWidth <= 0) {
      // A lost face mid-rep is not just noise here: the face leaving the
      // frame is what happens at the very bottom, when it is close enough to
      // overflow a front camera's view. Clearing the window would stall
      // calibration, and resetting the phase would drop the rep in progress,
      // so both are deliberately preserved.
      _window.clear();
      return _tick(issue: FaceRepIssue.notVisible);
    }

    final baseline = _baselineWidth;
    if (baseline == null) return _calibrate(faceWidth, frameWidth);

    final ratio = faceWidth / baseline;

    switch (_phase) {
      case FaceRepPhase.calibrating:
        // Only ever enter the cycle at the top, however the baseline was
        // arrived at. Entering it low would count the first push back up as
        // a full rep the user never did.
        if (ratio <= upRatio) _phase = FaceRepPhase.up;

      case FaceRepPhase.up:
        if (ratio >= downRatio) {
          _phase = FaceRepPhase.down;
          _largestRatioThisRep = ratio;
        } else if (ratio >= _shallowRatio) {
          return _tick(issue: FaceRepIssue.tooShallow, sizeRatio: ratio);
        }

      case FaceRepPhase.down:
        _largestRatioThisRep = math.max(_largestRatioThisRep ?? ratio, ratio);
        if (ratio <= upRatio) {
          _phase = FaceRepPhase.up;
          final deepest = _largestRatioThisRep;
          _largestRatioThisRep = null;
          if (_canCount(timestamp)) {
            _reps++;
            _lastRepAt = timestamp;
            return _tick(
              countedRep: true,
              sizeRatio: ratio,
              depthRatio: _depthRatio(deepest),
            );
          }
        }
    }

    return _tick(sizeRatio: ratio);
  }

  /// Adds a rep the camera missed, without disturbing the state machine.
  void addManual(int count) {
    if (count <= 0) return;
    _reps += count;
  }

  /// Zeroes the count for a session that is starting, keeping the calibrated
  /// baseline and the current phase. Reps counted while the user was still
  /// getting into position should not carry into the session, but making
  /// them recalibrate to start it would be pointless.
  void startSession() {
    _reps = 0;
    _lastRepAt = null;
    _largestRatioThisRep = null;
  }

  /// Clears everything, including the baseline.
  void reset() {
    _reps = 0;
    _baselineWidth = null;
    _phase = FaceRepPhase.calibrating;
    _lastRepAt = null;
    _largestRatioThisRep = null;
    _window.clear();
  }

  /// Throws away the baseline so the next held position sets a new one,
  /// keeping the reps already counted.
  void recalibrate() {
    _baselineWidth = null;
    _phase = FaceRepPhase.calibrating;
    _largestRatioThisRep = null;
    _window.clear();
  }

  /// Ratio that reads as a genuine attempt at a rep rather than drift, used
  /// to tell the user they are going down but not far enough.
  double get _shallowRatio => 1 + (downRatio - 1) * 0.5;

  FaceRepTick _calibrate(double faceWidth, double frameWidth) {
    if (frameWidth > 0 && faceWidth / frameWidth > maxBaselineFaceFraction) {
      _window.clear();
      return _tick(issue: FaceRepIssue.tooClose);
    }

    _window.add(faceWidth);
    if (_window.length > calibrationSampleCount) _window.removeAt(0);
    if (_window.length < calibrationSampleCount) {
      return _tick(issue: FaceRepIssue.holdStill);
    }

    final median = _median(_window);
    // Spread rather than a standard deviation: the question is whether the
    // face held still, and one large excursion matters even if the rest of
    // the window was steady enough to hide it in an average.
    final spread = _window.reduce(math.max) - _window.reduce(math.min);
    if (median <= 0 || spread / median > calibrationTolerance) {
      return _tick(issue: FaceRepIssue.holdStill);
    }

    // The phase deliberately stays at calibrating. Entering the rep cycle is
    // the state machine's job, and it will only do it from the top — see the
    // calibrating branch in [update].
    _baselineWidth = median;
    _window.clear();
    return _tick(sizeRatio: 1);
  }

  bool _canCount(DateTime timestamp) {
    final last = _lastRepAt;
    if (last == null) return true;
    return timestamp.difference(last) >= minRepInterval;
  }

  double? _depthRatio(double? deepest) {
    if (deepest == null) return null;
    final span = fullDepthRatio - downRatio;
    if (span <= 0) return 1;
    return ((deepest - downRatio) / span).clamp(0.0, 1.0);
  }

  FaceRepTick _tick({
    FaceRepIssue issue = FaceRepIssue.none,
    bool countedRep = false,
    double? sizeRatio,
    double? depthRatio,
  }) => FaceRepTick(
    reps: _reps,
    phase: _phase,
    issue: issue,
    countedRep: countedRep,
    isCalibrated: _baselineWidth != null,
    sizeRatio: sizeRatio,
    depthRatio: depthRatio,
  );

  static double _median(List<double> values) {
    final sorted = [...values]..sort();
    final middle = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[middle];
    return (sorted[middle - 1] + sorted[middle]) / 2;
  }
}
