//
//  pushlog
//  push_up_rep_counter.dart
//
//  Created by Ngonidzashe Mangudya on 2026/04/16.
//  Copyright (c) 2026 Codecraft Solutions. All rights reserved.
//

import 'dart:math' as math;

/// One tracked body point.
///
/// Deliberately not an ML Kit type. Counting is pure arithmetic over
/// coordinates, so it stays testable without a camera, a device, or a model
/// — the adapter that turns a detected pose into these lives elsewhere.
class PosePoint {
  const PosePoint({
    required this.x,
    required this.y,
    required this.likelihood,
  });

  final double x;
  final double y;

  /// 0–1 confidence that this point was located correctly.
  final double likelihood;
}

/// The joints one side of the body contributes to a push-up.
class PoseSide {
  const PoseSide({
    required this.shoulder,
    required this.elbow,
    required this.wrist,
    required this.hip,
    required this.knee,
  });

  final PosePoint shoulder;
  final PosePoint elbow;
  final PosePoint wrist;
  final PosePoint hip;
  final PosePoint knee;

  /// The weakest link. One badly located joint invalidates the angles that
  /// depend on it, so the whole side is only as trustworthy as its worst
  /// point.
  double get likelihood => [
    shoulder.likelihood,
    elbow.likelihood,
    wrist.likelihood,
    hip.likelihood,
    knee.likelihood,
  ].reduce(math.min);

  /// Shoulder–elbow–wrist. ~180° arms locked out, ~90° at the bottom.
  double get elbowAngle =>
      PushUpRepCounter.angleAt(vertex: elbow, from: shoulder, to: wrist);

  /// Shoulder–hip–knee. Near 180° in a plank; collapses when the hips sag
  /// or pike, which is what separates a push-up from a knee-bend.
  double get bodyLineAngle =>
      PushUpRepCounter.angleAt(vertex: hip, from: shoulder, to: knee);
}

/// Why a frame was not counted.
enum PushUpFormIssue {
  /// Nothing wrong.
  none,

  /// The model could not place the joints confidently enough to judge.
  notVisible,

  /// Hips sagging or piked. The arms may be bending, but this is not a
  /// push-up.
  bodyNotStraight,

  /// Came down, but not far enough to count.
  tooShallow,
}

enum PushUpPhase {
  /// No usable pose yet.
  waiting,

  /// Arms extended, top of the rep.
  up,

  /// Arms bent, bottom of the rep.
  down,
}

/// The counter's view of the world after one frame.
class PushUpTick {
  const PushUpTick({
    required this.reps,
    required this.phase,
    required this.issue,
    required this.countedRep,
    this.elbowAngle,
    this.depthRatio,
  });

  final int reps;
  final PushUpPhase phase;
  final PushUpFormIssue issue;

  /// True only on the frame that completed a repetition.
  final bool countedRep;

  final double? elbowAngle;

  /// How deep the last completed rep went. 0 means it only just reached the
  /// counting threshold; 1 means it reached full depth. Null until a rep
  /// completes.
  ///
  /// Measured against [PushUpRepCounter.fullDepthAngle] rather than the
  /// counting threshold, because every rep that counts is by definition at
  /// or past the threshold — normalising against it would report 1.0 for
  /// everything and tell the user nothing.
  final double? depthRatio;
}

/// Counts push-ups from a stream of poses.
///
/// The rep is a state machine over the elbow angle with hysteresis: the arm
/// must bend past [downAngle] and then straighten past [upAngle] before
/// anything is counted. Two separate thresholds matter — a single midpoint
/// would count several reps as the angle jitters across it, which is the
/// classic failure of naive rep counters.
///
/// Body line is checked as well as elbow angle. Bending your arms while
/// sitting is not a push-up, and the old face-distance tracker could not
/// tell the difference.
class PushUpRepCounter {
  PushUpRepCounter({
    this.downAngle = 100,
    this.upAngle = 150,
    this.fullDepthAngle = 90,
    this.minBodyLineAngle = 135,
    this.minLikelihood = 0.5,
    this.minRepInterval = const Duration(milliseconds: 400),
  });

  /// Elbow angle at or below which the arm counts as bent.
  final double downAngle;

  /// Elbow angle at or above which the arm counts as extended.
  final double upAngle;

  /// Elbow angle treated as a full-depth repetition — roughly the forearm
  /// perpendicular to the upper arm. Used only to score depth, never to
  /// decide whether a rep counted.
  final double fullDepthAngle;

  /// Shoulder–hip–knee angle below which the body is too folded to be in a
  /// push-up position.
  final double minBodyLineAngle;

  /// Confidence floor for a side to be usable.
  final double minLikelihood;

  /// Rejects a second rep arriving impossibly soon after the last. Real
  /// push-ups do not come faster than this; jitter does.
  final Duration minRepInterval;

  int _reps = 0;
  PushUpPhase _phase = PushUpPhase.waiting;
  DateTime? _lastRepAt;
  double? _deepestAngleThisRep;

  int get reps => _reps;

  PushUpPhase get phase => _phase;

  /// Feeds one frame in and returns the resulting state.
  ///
  /// [left] and [right] are the two sides of the body; the more confident of
  /// the two is used. A single side is enough, because at most camera angles
  /// one arm occludes the other.
  PushUpTick update({
    required DateTime timestamp,
    PoseSide? left,
    PoseSide? right,
  }) {
    final side = _bestSide(left, right);

    if (side == null) {
      // Phase is deliberately preserved rather than reset. Losing the pose
      // for a few frames mid-rep is normal; forgetting that the user is at
      // the bottom would drop the rep entirely when tracking returns.
      return PushUpTick(
        reps: _reps,
        phase: _phase,
        issue: PushUpFormIssue.notVisible,
        countedRep: false,
      );
    }

    final elbow = side.elbowAngle;

    if (side.bodyLineAngle < minBodyLineAngle) {
      return PushUpTick(
        reps: _reps,
        phase: _phase,
        issue: PushUpFormIssue.bodyNotStraight,
        countedRep: false,
        elbowAngle: elbow,
      );
    }

    switch (_phase) {
      case PushUpPhase.waiting:
        // Only ever enter at the top. Starting mid-rep would count the
        // first push back up as a full repetition the user never did.
        if (elbow >= upAngle) _phase = PushUpPhase.up;

      case PushUpPhase.up:
        if (elbow <= downAngle) {
          _phase = PushUpPhase.down;
          _deepestAngleThisRep = elbow;
        }

      case PushUpPhase.down:
        _deepestAngleThisRep = math.min(
          _deepestAngleThisRep ?? elbow,
          elbow,
        );
        if (elbow >= upAngle) {
          _phase = PushUpPhase.up;
          if (_canCount(timestamp)) {
            _reps++;
            _lastRepAt = timestamp;
            final depth = _depthRatio(_deepestAngleThisRep);
            _deepestAngleThisRep = null;
            return PushUpTick(
              reps: _reps,
              phase: _phase,
              issue: PushUpFormIssue.none,
              countedRep: true,
              elbowAngle: elbow,
              depthRatio: depth,
            );
          }
          _deepestAngleThisRep = null;
        }
    }

    return PushUpTick(
      reps: _reps,
      phase: _phase,
      issue: PushUpFormIssue.none,
      countedRep: false,
      elbowAngle: elbow,
    );
  }

  /// Adds a rep the camera missed, without disturbing the state machine.
  void addManual(int count) {
    if (count <= 0) return;
    _reps += count;
  }

  /// Clears the count and the phase. Used when a session starts.
  void reset() {
    _reps = 0;
    _phase = PushUpPhase.waiting;
    _lastRepAt = null;
    _deepestAngleThisRep = null;
  }

  bool _canCount(DateTime timestamp) {
    final last = _lastRepAt;
    if (last == null) return true;
    return timestamp.difference(last) >= minRepInterval;
  }

  double? _depthRatio(double? deepest) {
    if (deepest == null) return null;
    final span = downAngle - fullDepthAngle;
    if (span <= 0) return 1;
    return ((downAngle - deepest) / span).clamp(0.0, 1.0);
  }

  PoseSide? _bestSide(PoseSide? left, PoseSide? right) {
    final candidates = [left, right]
        .whereType<PoseSide>()
        .where((side) => side.likelihood >= minLikelihood)
        .toList();
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => b.likelihood.compareTo(a.likelihood));
    return candidates.first;
  }

  /// Interior angle at [vertex], in degrees, between the rays to [from] and
  /// [to].
  ///
  /// Computed in 2D. ML Kit does report a z coordinate, but its depth is far
  /// noisier than its x/y, and for a limb roughly parallel to the image
  /// plane it adds error rather than accuracy.
  static double angleAt({
    required PosePoint vertex,
    required PosePoint from,
    required PosePoint to,
  }) {
    final ax = from.x - vertex.x;
    final ay = from.y - vertex.y;
    final bx = to.x - vertex.x;
    final by = to.y - vertex.y;

    final magnitude =
        math.sqrt(ax * ax + ay * ay) * math.sqrt(bx * bx + by * by);
    if (magnitude == 0) return 180;

    final cosine = ((ax * bx + ay * by) / magnitude).clamp(-1.0, 1.0);
    return math.acos(cosine) * 180 / math.pi;
  }
}
