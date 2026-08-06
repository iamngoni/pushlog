//
//  pushlog
//  spacing.dart
//
//  Created by Ngonidzashe Mangudya on 2026/04/16.
//  Copyright (c) 2026 Codecraft Solutions. All rights reserved.
//

import 'package:flutter/widgets.dart';

/// Non-linear spacing scale.
///
/// Steps are roughly 25% apart at the small end and widen as the scale
/// climbs, because a 4px change is obvious at 12px and invisible at 96px.
/// Every gap, pad, and inset in the app should come from here — a value
/// that is not on the scale is a bug, not a judgement call.
class AppSpacing {
  const AppSpacing._();

  /// Hairline separation inside a tightly bound pair.
  static const double xxs = 2;

  /// Value-to-caption, icon-to-glyph.
  static const double xs = 4;

  /// Label-to-value inside one group.
  static const double sm = 6;

  /// Default gap between related lines of text.
  static const double md = 8;

  /// Gap between controls in a row.
  static const double lg = 12;

  /// Default internal padding for compact surfaces.
  static const double xl = 16;

  /// Internal padding for primary surfaces.
  static const double xxl = 20;

  /// Screen gutter, and gap between stacked blocks.
  static const double block = 24;

  /// Gap between distinct sections of a page.
  static const double section = 32;

  /// Gap above a major heading that starts a new region.
  static const double sectionLarge = 40;

  /// Hero breathing room on entry screens.
  static const double hero = 48;

  /// Maximum vertical rhythm — top of an onboarding or auth screen.
  static const double heroLarge = 64;

  /// Horizontal page gutter. Content never touches the screen edge.
  static const double gutter = 24;

  /// Longest comfortable measure for prose, in logical pixels.
  ///
  /// Roughly 65 characters at the body size, which sits inside the
  /// 45–75 character band that keeps line tracking easy.
  static const double proseMaxWidth = 460;

  /// Minimum tappable dimension required by both platforms.
  static const double minTapTarget = 44;

  /// Standard control height — buttons, fields, rows.
  static const double controlHeight = 56;
}

/// Corner radii.
///
/// Pushlog is architectural rather than pill-shaped: radii stay modest and
/// scale with the surface they wrap, so a small chip never looks rounder
/// than the card containing it.
class AppRadius {
  const AppRadius._();

  static const double none = 0;

  /// Progress bars and other thin indicators.
  static const double indicator = 4;

  /// Chips, badges, compact controls.
  static const double xs = 8;

  /// Buttons and small tiles.
  static const double sm = 12;

  /// Action cells and inputs.
  static const double md = 14;

  /// Cards, choice tiles, toasts.
  static const double lg = 18;

  /// Primary surfaces — the daily score block.
  static const double xl = 24;

  /// Sheets and full-width modal surfaces.
  static const double xxl = 28;

  /// Circular. Use for avatars and dot indicators only.
  static const double full = 999;

  static BorderRadius all(double radius) => BorderRadius.circular(radius);

  /// Top-only rounding for sheets that rise from the bottom edge.
  static BorderRadius top(double radius) => BorderRadius.vertical(
    top: Radius.circular(radius),
  );
}
