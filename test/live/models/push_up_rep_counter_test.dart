import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:pushlog/live/models/push_up_rep_counter.dart';

/// Builds a side whose elbow sits at [elbowAngle] degrees.
///
/// The shoulder is placed on the +x axis from the elbow and the wrist is
/// rotated to the requested angle, so the geometry the counter measures is
/// exactly what the test asked for rather than something eyeballed.
PoseSide sideWith({
  required double elbowAngle,
  double bodyLineAngle = 180,
  double likelihood = 0.9,
}) {
  const elbow = PosePoint(x: 0, y: 0, likelihood: 0.9);
  final shoulder = PosePoint(x: 100, y: 0, likelihood: likelihood);
  final radians = elbowAngle * math.pi / 180;
  final wrist = PosePoint(
    x: 100 * math.cos(radians),
    y: 100 * math.sin(radians),
    likelihood: likelihood,
  );

  // Hip is the vertex of the body line. The shoulder already sits at
  // x = 100, so from the hip it lies along 180°; the knee is therefore
  // placed at (180° - bodyLineAngle) to open exactly that angle between
  // them. Placing it at bodyLineAngle directly would put both limbs on the
  // same side of the hip and measure 0° for a straight plank.
  const hip = PosePoint(x: 200, y: 0, likelihood: 0.9);
  final bodyRadians = (180 - bodyLineAngle) * math.pi / 180;
  final knee = PosePoint(
    x: 200 + 100 * math.cos(bodyRadians),
    y: 100 * math.sin(bodyRadians),
    likelihood: likelihood,
  );

  return PoseSide(
    shoulder: shoulder,
    elbow: elbow,
    wrist: wrist,
    hip: hip,
    knee: knee,
  );
}

/// Pushes one frame into [counter] at time [at].
PushUpTick feed(
  PushUpRepCounter counter, {
  required DateTime at,
  double? elbow,
  double bodyLine = 180,
  double likelihood = 0.9,
  double? rightElbow,
  double rightLikelihood = 0.9,
}) {
  return counter.update(
    timestamp: at,
    left: elbow == null
        ? null
        : sideWith(
            elbowAngle: elbow,
            bodyLineAngle: bodyLine,
            likelihood: likelihood,
          ),
    right: rightElbow == null
        ? null
        : sideWith(
            elbowAngle: rightElbow,
            bodyLineAngle: bodyLine,
            likelihood: rightLikelihood,
          ),
  );
}

/// Drives a full rep: top, bottom, top. Returns the tick from the frame that
/// completes it.
PushUpTick doRep(
  PushUpRepCounter counter, {
  required DateTime at,
  double bottomAngle = 80,
  double topAngle = 170,
}) {
  feed(counter, at: at, elbow: topAngle);
  feed(
    counter,
    at: at.add(const Duration(milliseconds: 300)),
    elbow: bottomAngle,
  );
  return feed(
    counter,
    at: at.add(const Duration(milliseconds: 600)),
    elbow: topAngle,
  );
}

void main() {
  final t0 = DateTime(2026, 8, 7, 10);

  group('angle measurement', () {
    test('measures a right angle at the vertex', () {
      const vertex = PosePoint(x: 0, y: 0, likelihood: 1);
      const from = PosePoint(x: 10, y: 0, likelihood: 1);
      const to = PosePoint(x: 0, y: 10, likelihood: 1);
      expect(
        PushUpRepCounter.angleAt(vertex: vertex, from: from, to: to),
        closeTo(90, 0.001),
      );
    });

    test('measures a straight arm as 180 degrees', () {
      const vertex = PosePoint(x: 0, y: 0, likelihood: 1);
      const from = PosePoint(x: 10, y: 0, likelihood: 1);
      const to = PosePoint(x: -10, y: 0, likelihood: 1);
      expect(
        PushUpRepCounter.angleAt(vertex: vertex, from: from, to: to),
        closeTo(180, 0.001),
      );
    });

    test('is stable when points coincide', () {
      const vertex = PosePoint(x: 5, y: 5, likelihood: 1);
      expect(
        PushUpRepCounter.angleAt(vertex: vertex, from: vertex, to: vertex),
        180,
      );
    });
  });

  group('rep counting', () {
    test('counts one rep for a full down and up', () {
      final counter = PushUpRepCounter();
      final tick = doRep(counter, at: t0);
      expect(counter.reps, 1);
      expect(counter.phase, PushUpPhase.up);
      expect(tick.countedRep, isTrue);
    });

    test('counts three reps for three cycles', () {
      final counter = PushUpRepCounter();
      for (var i = 0; i < 3; i++) {
        doRep(counter, at: t0.add(Duration(seconds: i * 2)));
      }
      expect(counter.reps, 3);
    });

    test('does not count until the arm returns to the top', () {
      final counter = PushUpRepCounter();
      feed(counter, at: t0, elbow: 170);
      final tick = feed(
        counter,
        at: t0.add(const Duration(milliseconds: 300)),
        elbow: 80,
      );
      expect(tick.phase, PushUpPhase.down);
      expect(counter.reps, 0);
    });

    test('ignores jitter across a single midpoint', () {
      final counter = PushUpRepCounter();
      feed(counter, at: t0, elbow: 170);
      // Oscillating between the thresholds must not latch a transition.
      for (var i = 0; i < 20; i++) {
        feed(
          counter,
          at: t0.add(Duration(milliseconds: 50 * i)),
          elbow: i.isEven ? 128 : 122,
        );
      }
      expect(counter.reps, 0);
      expect(counter.phase, PushUpPhase.up);
    });

    test('does not count a rep that starts mid-descent', () {
      final counter = PushUpRepCounter();
      // First observation is already at the bottom — the user was not seen
      // going down, so pushing back up is not a completed rep.
      feed(counter, at: t0, elbow: 80);
      feed(counter, at: t0.add(const Duration(milliseconds: 300)), elbow: 170);
      expect(counter.reps, 0);
    });

    test('rejects a shallow dip that never bends far enough', () {
      final counter = PushUpRepCounter();
      feed(counter, at: t0, elbow: 170);
      feed(counter, at: t0.add(const Duration(milliseconds: 300)), elbow: 120);
      feed(counter, at: t0.add(const Duration(milliseconds: 600)), elbow: 170);
      expect(counter.reps, 0);
    });

    test('debounces reps arriving faster than a human can move', () {
      final counter = PushUpRepCounter(
        minRepInterval: const Duration(milliseconds: 900),
      );
      doRep(counter, at: t0);
      expect(counter.reps, 1);
      // A second full cycle well inside the interval is noise, not a rep.
      feed(counter, at: t0.add(const Duration(milliseconds: 700)), elbow: 80);
      feed(counter, at: t0.add(const Duration(milliseconds: 800)), elbow: 170);
      expect(counter.reps, 1);
    });
  });

  group('form gating', () {
    test('does not count arm bends when the body is folded', () {
      final counter = PushUpRepCounter();
      feed(counter, at: t0, elbow: 170, bodyLine: 90);
      final tick = feed(
        counter,
        at: t0.add(const Duration(milliseconds: 300)),
        elbow: 80,
        bodyLine: 90,
      );
      expect(tick.issue, PushUpFormIssue.bodyNotStraight);
      expect(counter.reps, 0);
    });

    test('reports when the pose is not confidently visible', () {
      final counter = PushUpRepCounter();
      final tick = feed(counter, at: t0, elbow: 170, likelihood: 0.2);
      expect(tick.issue, PushUpFormIssue.notVisible);
    });

    test('keeps its phase through a brief tracking dropout', () {
      final counter = PushUpRepCounter();
      feed(counter, at: t0, elbow: 170);
      feed(counter, at: t0.add(const Duration(milliseconds: 200)), elbow: 80);
      expect(counter.phase, PushUpPhase.down);

      // Pose lost for a few frames at the bottom.
      for (var i = 0; i < 5; i++) {
        feed(counter, at: t0.add(Duration(milliseconds: 250 + i * 30)));
      }
      expect(counter.phase, PushUpPhase.down);

      // Coming back up still completes the rep.
      feed(counter, at: t0.add(const Duration(milliseconds: 600)), elbow: 170);
      expect(counter.reps, 1);
    });

    test('uses whichever side the model saw more confidently', () {
      final counter = PushUpRepCounter();
      // The left arm reads as straight but is barely visible; the right is
      // clearly bent. The confident side must win.
      feed(
        counter,
        at: t0,
        elbow: 170,
        likelihood: 0.1,
        rightElbow: 170,
        rightLikelihood: 0.95,
      );
      final tick = feed(
        counter,
        at: t0.add(const Duration(milliseconds: 300)),
        elbow: 170,
        likelihood: 0.1,
        rightElbow: 80,
        rightLikelihood: 0.95,
      );
      expect(tick.phase, PushUpPhase.down);
    });
  });

  group('depth and manual adjustment', () {
    test('reports a high depth ratio for a deep rep', () {
      final counter = PushUpRepCounter();
      final tick = doRep(counter, at: t0, bottomAngle: 70);
      expect(tick.countedRep, isTrue);
      expect(tick.depthRatio, isNotNull);
      expect(tick.depthRatio, greaterThan(0.9));
    });

    test('reports a lower depth ratio for a barely-deep-enough rep', () {
      final counter = PushUpRepCounter();
      final tick = doRep(counter, at: t0, bottomAngle: 99);
      expect(tick.countedRep, isTrue);
      expect(tick.depthRatio, lessThan(1.0));
    });

    test('manual additions do not disturb the state machine', () {
      final counter = PushUpRepCounter();
      feed(counter, at: t0, elbow: 170);
      feed(counter, at: t0.add(const Duration(milliseconds: 300)), elbow: 80);
      counter.addManual(10);
      expect(counter.reps, 10);
      expect(counter.phase, PushUpPhase.down);

      // The in-flight rep still lands on top of the manual reps.
      feed(counter, at: t0.add(const Duration(milliseconds: 600)), elbow: 170);
      expect(counter.reps, 11);
    });

    test('ignores non-positive manual additions', () {
      final counter = PushUpRepCounter()
        ..addManual(0)
        ..addManual(-5);
      expect(counter.reps, 0);
    });

    test('reset clears count and phase', () {
      final counter = PushUpRepCounter();
      doRep(counter, at: t0);
      counter.reset();
      expect(counter.reps, 0);
      expect(counter.phase, PushUpPhase.waiting);
    });
  });
}
