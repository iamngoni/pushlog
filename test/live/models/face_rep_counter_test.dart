import 'package:flutter_test/flutter_test.dart';
import 'package:pushlog/live/models/face_rep_counter.dart';

/// Frame width used throughout. Wide enough that a baseline-sized face is
/// nowhere near the too-close guard.
const _frameWidth = 720.0;

/// The apparent face width at the top of a rep, in pixels.
const _topWidth = 120.0;

void main() {
  late FaceRepCounter counter;
  late DateTime clock;

  setUp(() {
    counter = FaceRepCounter();
    clock = DateTime(2026, 8, 21, 6);
  });

  /// Feeds one frame, advancing the clock so reps are never debounced away
  /// unless a test means them to be.
  FaceRepTick feed(
    double? width, {
    Duration step = const Duration(seconds: 1),
  }) {
    clock = clock.add(step);
    return counter.update(
      timestamp: clock,
      faceWidth: width,
      frameWidth: _frameWidth,
    );
  }

  /// Holds still until a baseline locks in. The phase is still calibrating
  /// on return: entering the rep cycle takes one more frame at the top.
  FaceRepTick lockBaseline({double width = _topWidth}) {
    FaceRepTick tick;
    do {
      tick = feed(width, step: const Duration(milliseconds: 50));
    } while (!tick.isCalibrated);
    return tick;
  }

  /// Locks a baseline and settles at the top, ready to count.
  FaceRepTick calibrate() {
    lockBaseline();
    return feed(_topWidth, step: const Duration(milliseconds: 50));
  }

  /// One full rep: down past the counting threshold, then back to the top.
  FaceRepTick fullRep({double depth = 1.8}) {
    feed(_topWidth * depth);
    return feed(_topWidth);
  }

  group('calibration', () {
    test('locks a baseline once the face holds still', () {
      final tick = calibrate();

      expect(tick.isCalibrated, isTrue);
      expect(counter.baselineWidth, closeTo(_topWidth, 0.001));
      expect(tick.phase, FaceRepPhase.up);
    });

    test('does not calibrate before enough samples land', () {
      final tick = counter.update(
        timestamp: clock,
        faceWidth: _topWidth,
        frameWidth: _frameWidth,
      );

      expect(tick.isCalibrated, isFalse);
      expect(tick.issue, FaceRepIssue.holdStill);
      expect(tick.phase, FaceRepPhase.calibrating);
    });

    test('refuses to settle while the face is still moving', () {
      // Alternating wide and narrow: a spread no held position would show.
      for (var i = 0; i < 40; i++) {
        final tick = feed(i.isEven ? _topWidth : _topWidth * 1.6);
        expect(tick.isCalibrated, isFalse);
      }

      expect(counter.baselineWidth, isNull);
    });

    test('refuses to calibrate while the face fills the frame', () {
      // Calibrating here would fix the top of the rep at what is really the
      // bottom, after which nothing could ever look deep enough to count.
      for (var i = 0; i < 40; i++) {
        final tick = feed(_frameWidth * 0.7);
        expect(tick.isCalibrated, isFalse);
        expect(tick.issue, FaceRepIssue.tooClose);
      }
    });

    test('a lost face does not stall calibration permanently', () {
      feed(_topWidth);
      feed(null);

      expect(lockBaseline().isCalibrated, isTrue);
    });

    test('recalibrate keeps the reps already counted', () {
      calibrate();
      fullRep();
      expect(counter.reps, 1);

      counter.recalibrate();

      expect(counter.reps, 1);
      expect(counter.isCalibrated, isFalse);
      expect(counter.phase, FaceRepPhase.calibrating);
    });

    test('does not count the first climb when the baseline lands low', () {
      // The baseline is set, but the next frame is already deep — the user
      // was mid-rep as calibration finished. Entering the cycle there would
      // count the push back up as a rep that was never performed.
      lockBaseline();

      feed(_topWidth * 1.8);
      expect(counter.phase, FaceRepPhase.calibrating);

      feed(_topWidth);
      expect(counter.reps, 0);
      expect(counter.phase, FaceRepPhase.up);

      // From here the cycle is live and a real rep does count.
      expect(fullRep().reps, 1);
    });
  });

  group('rep counting', () {
    test('counts one rep for a full descent and return', () {
      calibrate();

      feed(_topWidth * 1.8);
      expect(counter.phase, FaceRepPhase.down);
      final tick = feed(_topWidth);

      expect(tick.countedRep, isTrue);
      expect(tick.reps, 1);
      expect(tick.phase, FaceRepPhase.up);
    });

    test('counts three reps for three cycles', () {
      calibrate();

      for (var i = 0; i < 3; i++) {
        fullRep();
      }

      expect(counter.reps, 3);
    });

    test('does not count until the face returns to the top', () {
      calibrate();

      feed(_topWidth * 1.8);
      feed(_topWidth * 1.7);
      feed(_topWidth * 1.6);

      expect(counter.reps, 0);
      expect(counter.phase, FaceRepPhase.down);
    });

    test('ignores jitter across a single midpoint', () {
      calibrate();

      // Hovering right at the counting threshold. A counter using one
      // midpoint instead of a separate down and up would ratchet up a rep
      // per frame here.
      for (var i = 0; i < 20; i++) {
        feed(_topWidth * (i.isEven ? 1.46 : 1.44));
      }

      expect(counter.reps, 0);
    });

    test('rejects a dip that never gets deep enough', () {
      calibrate();

      feed(_topWidth * 1.3);
      final tick = feed(_topWidth);

      expect(tick.countedRep, isFalse);
      expect(counter.reps, 0);
    });

    test('flags a dip that is clearly an attempt but too shallow', () {
      calibrate();

      final tick = feed(_topWidth * 1.3);

      expect(tick.issue, FaceRepIssue.tooShallow);
      expect(counter.reps, 0);
    });

    test('debounces reps arriving faster than a human can move', () {
      calibrate();
      fullRep();

      feed(_topWidth * 1.8, step: const Duration(milliseconds: 50));
      final tick = feed(_topWidth, step: const Duration(milliseconds: 50));

      expect(tick.countedRep, isFalse);
      expect(counter.reps, 1);
    });

    test('holds the phase through a face lost at the bottom', () {
      calibrate();

      // The face leaving frame is what happens at the very bottom, where it
      // can overflow a front camera's view. Forgetting the descent would
      // drop the rep outright.
      feed(_topWidth * 1.8);
      feed(null);
      feed(null);
      expect(counter.phase, FaceRepPhase.down);

      final tick = feed(_topWidth);

      expect(tick.countedRep, isTrue);
      expect(counter.reps, 1);
    });

    test('reports a missing face without counting', () {
      calibrate();

      final tick = feed(null);

      expect(tick.issue, FaceRepIssue.notVisible);
      expect(tick.countedRep, isFalse);
    });

    test('treats a non-positive width as no face', () {
      calibrate();

      expect(feed(0).issue, FaceRepIssue.notVisible);
    });
  });

  group('depth', () {
    test('scores a deep rep near the top of the range', () {
      calibrate();

      feed(_topWidth * 2.2);
      final tick = feed(_topWidth);

      expect(tick.depthRatio, 1.0);
    });

    test('scores a barely-deep-enough rep near the bottom', () {
      calibrate();

      feed(_topWidth * 1.5);
      final tick = feed(_topWidth);

      expect(tick.depthRatio, closeTo(0.09, 0.02));
    });

    test('measures the deepest point, not the last frame before rising', () {
      calibrate();

      feed(_topWidth * 2.2);
      feed(_topWidth * 1.6);
      final tick = feed(_topWidth);

      expect(tick.depthRatio, 1.0);
    });
  });

  group('manual adjustment and session state', () {
    test('manual additions do not disturb the state machine', () {
      calibrate();
      feed(_topWidth * 1.8);

      counter.addManual(10);

      expect(counter.reps, 10);
      expect(counter.phase, FaceRepPhase.down);
      expect(feed(_topWidth).reps, 11);
    });

    test('ignores non-positive manual additions', () {
      calibrate();

      counter
        ..addManual(0)
        ..addManual(-5);

      expect(counter.reps, 0);
    });

    test('startSession zeroes reps but keeps the calibrated range', () {
      calibrate();
      fullRep();
      expect(counter.reps, 1);

      counter.startSession();

      expect(counter.reps, 0);
      expect(counter.isCalibrated, isTrue);
      // Counting resumes immediately, with no second hold-still step.
      expect(fullRep().reps, 1);
    });

    test('reset clears the count and the range', () {
      calibrate();
      fullRep();

      counter.reset();

      expect(counter.reps, 0);
      expect(counter.isCalibrated, isFalse);
      expect(counter.phase, FaceRepPhase.calibrating);
    });
  });
}
