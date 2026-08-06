//
//  pushlog
//  motion.dart
//
//  Created by Ngonidzashe Mangudya on 2026/04/16.
//  Copyright (c) 2026 Codecraft Solutions. All rights reserved.
//

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Motion tokens.
///
/// Pushlog animates to explain a change, never to decorate one. Every
/// duration here is routed through [AppMotion.duration] so a user who has
/// asked the system to reduce motion gets the same interface without it.
class AppMotion {
  const AppMotion._();

  /// Press feedback and colour changes on a control the finger is on.
  static const Duration instant = Duration(milliseconds: 110);

  /// Selection changes, chip toggles, small state swaps.
  static const Duration fast = Duration(milliseconds: 160);

  /// The default. Tab switches, counter updates, bar growth.
  static const Duration base = Duration(milliseconds: 220);

  /// Entrances that cross a large distance — toasts, sheets.
  static const Duration slow = Duration(milliseconds: 320);

  /// Celebration beats. Used sparingly and never blocking.
  static const Duration deliberate = Duration(milliseconds: 480);

  /// How long a toast stays on screen before dismissing itself.
  static const Duration toastShort = Duration(milliseconds: 2800);

  /// Toast duration when the message carries an action worth reading.
  static const Duration toastLong = Duration(milliseconds: 4600);

  /// Natural deceleration. The default for anything entering the screen.
  static const Curve enter = Curves.easeOutQuart;

  /// Slightly softer deceleration for elements that settle in place.
  static const Curve settle = Curves.easeOutCubic;

  /// Acceleration for anything leaving the screen.
  static const Curve exit = Curves.easeInCubic;

  /// Symmetric easing for values that move both ways, like a progress bar.
  static const Curve standard = Curves.easeInOutCubic;

  /// A restrained overshoot. Reserved for earned moments — never for
  /// routine feedback, and never elastic or bouncy.
  static const Curve emphasis = Curves.easeOutBack;

  /// Returns [value], or [Duration.zero] when the user has asked the
  /// platform to reduce motion.
  ///
  /// Always route durations through this rather than reading the media
  /// query at each call site — animations that skip the check are the
  /// single most common accessibility regression in the app.
  static Duration duration(BuildContext context, Duration value) {
    return MediaQuery.disableAnimationsOf(context) ? Duration.zero : value;
  }

  /// True when animations should be suppressed entirely.
  static bool isReduced(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);
}

/// Haptic feedback, mapped to meaning rather than to intensity.
///
/// Logging reps is a physical act; the taps confirm work landed without
/// the user having to look at the screen mid-set.
class AppHaptics {
  const AppHaptics._();

  /// A rep or small increment was recorded.
  static void tick() => unawaited(HapticFeedback.selectionClick());

  /// A control was pressed — tab change, choice tile, toggle.
  static void tap() => unawaited(HapticFeedback.lightImpact());

  /// A set or session was committed.
  static void commit() => unawaited(HapticFeedback.mediumImpact());

  /// Today's target was reached.
  static void celebrate() => unawaited(HapticFeedback.heavyImpact());

  /// An action failed or was rejected.
  static void warn() => unawaited(HapticFeedback.vibrate());

  static void unawaited(Future<void> future) {
    future.ignore();
  }
}
