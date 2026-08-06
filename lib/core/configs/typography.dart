//
//  pushlog
//  typography.dart
//
//  Created by Ngonidzashe Mangudya on 2026/04/16.
//  Copyright (c) 2026 Codecraft Solutions. All rights reserved.
//

import 'package:flutter/material.dart';

/// The Pushlog type system.
///
/// Sizes are hand-picked rather than generated from a ratio:
///
///     11 · 12 · 13 · 15 · 17 · 20 · 24 · 28 · 32 · 40 · 48 · 56 · 72
///
/// A modular scale would produce fractional sizes that round inconsistently
/// and would leave gaps exactly where the UI needs one — between 15 and 17,
/// for instance, which is the difference between a caption and body copy.
///
/// Three families do all the work:
///
/// * **Metric** — training numbers. Heavy, tightly tracked, and always set
///   with tabular figures so a counter animating from 9 to 10 does not
///   shift the glyphs beside it.
/// * **Heading** and **body** — proportional figures, normal tracking.
/// * **Label** — small, semi-bold, for metadata and controls.
///
/// Hierarchy is carried by weight and colour as much as by size. Two
/// weights and three ink levels cover the whole app; pushing size alone
/// leaves body copy too large and captions too small to read.
class AppTypography {
  const AppTypography._();

  /// Smallest size the app will render. Anything below this fails at arm's
  /// length on a phone, so requests for smaller sizes are clamped rather
  /// than honoured.
  static const double minSize = 10;

  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  // ---------------------------------------------------------------------
  // Metric — training values
  // ---------------------------------------------------------------------

  /// Builds a metric style. Prefer the named steps below; this exists for
  /// the rare value that must be sized to fit its container.
  static TextStyle metric({
    required double size,
    Color? color,
    FontWeight weight = FontWeight.w800,
    double height = 1,
    double? letterSpacing,
  }) => TextStyle(
    fontSize: size < minSize ? minSize : size,
    fontWeight: weight,
    height: height,
    letterSpacing: letterSpacing ?? _metricTracking(size),
    fontFeatures: _tabular,
    color: color,
  );

  /// Large type needs negative tracking to stop the counters from looking
  /// like they are drifting apart; small type needs none.
  static double _metricTracking(double size) {
    if (size >= 64) return -3.2;
    if (size >= 48) return -2.4;
    if (size >= 36) return -1.6;
    if (size >= 28) return -1.2;
    if (size >= 22) return -0.8;
    return -0.2;
  }

  /// Today's count. One per screen, at most.
  static TextStyle metricHero({Color? color}) => metric(size: 72, color: color);

  static TextStyle metricXLarge({Color? color}) =>
      metric(size: 56, color: color);

  static TextStyle metricLarge({Color? color}) =>
      metric(size: 40, color: color);

  static TextStyle metricMedium({Color? color}) =>
      metric(size: 32, color: color);

  static TextStyle metricSmall({Color? color}) =>
      metric(size: 24, color: color);

  /// Inline values sitting beside a label — stat rows, leaderboard counts.
  static TextStyle metricCompact({Color? color}) => metric(
    size: 20,
    color: color,
    weight: FontWeight.w700,
  );

  /// Table-style figures at body size. Keeps columns of numbers aligned.
  static TextStyle metricInline({Color? color, FontWeight? weight}) => metric(
    size: 15,
    color: color,
    weight: weight ?? FontWeight.w600,
    height: 1.3,
  );

  // ---------------------------------------------------------------------
  // Headings
  // ---------------------------------------------------------------------

  /// Reserved for entry screens — sign-in, the first onboarding beat.
  static TextStyle headingXLarge({Color? color}) => TextStyle(
    fontSize: 48,
    fontWeight: FontWeight.w800,
    height: 1.02,
    letterSpacing: -2,
    color: color,
  );

  /// Page titles and onboarding questions.
  ///
  /// Deliberately smaller than the old 40pt: a question that wraps to three
  /// lines reads as a wall, and the answer tiles below it are what the user
  /// actually needs to see.
  static TextStyle headingLarge({Color? color}) => TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    height: 1.08,
    letterSpacing: -1,
    color: color,
  );

  static TextStyle headingMedium({Color? color}) => TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.14,
    letterSpacing: -0.6,
    color: color,
  );

  static TextStyle headingSmall({Color? color}) => TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.2,
    color: color,
  );

  /// Row and card titles.
  static TextStyle title({Color? color}) => TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    height: 1.3,
    letterSpacing: -0.1,
    color: color,
  );

  // ---------------------------------------------------------------------
  // Body
  // ---------------------------------------------------------------------

  /// Lead paragraphs and the sentence under a page title.
  static TextStyle bodyLarge({Color? color}) => TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: color,
  );

  static TextStyle body({Color? color, FontWeight? weight}) => TextStyle(
    fontSize: 15,
    fontWeight: weight ?? FontWeight.w400,
    height: 1.5,
    color: color,
  );

  /// Supporting copy under a value or control.
  static TextStyle bodySmall({Color? color, FontWeight? weight}) => TextStyle(
    fontSize: 13,
    fontWeight: weight ?? FontWeight.w400,
    height: 1.45,
    color: color,
  );

  // ---------------------------------------------------------------------
  // Labels
  // ---------------------------------------------------------------------

  /// Control labels and metadata in sentence case.
  static TextStyle label({Color? color, FontWeight? weight}) => TextStyle(
    fontSize: 12,
    fontWeight: weight ?? FontWeight.w600,
    height: 1.3,
    letterSpacing: 0.1,
    color: color,
  );

  static TextStyle labelSmall({Color? color, FontWeight? weight}) => TextStyle(
    fontSize: 11,
    fontWeight: weight ?? FontWeight.w600,
    height: 1.25,
    letterSpacing: 0.2,
    color: color,
  );

  /// Short all-caps labels — section headers, the wordmark, tab captions.
  ///
  /// Capitals share too many outlines to read well when packed at normal
  /// tracking, so every uppercase style here opens up by roughly 0.12em.
  /// Uppercase is for labels only; a sentence never gets this treatment.
  static TextStyle overline({
    Color? color,
    double size = 11,
    FontWeight weight = FontWeight.w700,
    double? letterSpacing,
  }) => TextStyle(
    fontSize: size < minSize ? minSize : size,
    fontWeight: weight,
    height: 1.2,
    letterSpacing: letterSpacing ?? size * 0.12,
    color: color,
  );
}
