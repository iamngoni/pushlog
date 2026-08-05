//
//  pushlog
//  typography.dart
//
//  Created by Ngonidzashe Mangudya on 2026/04/16.
//  Copyright (c) 2026 Codecraft Solutions. All rights reserved.
//

import 'package:flutter/material.dart';

class AppTypography {
  const AppTypography._();

  static TextStyle displayLarge({Color? color}) => TextStyle(
    fontSize: 104,
    fontWeight: FontWeight.w900,
    height: 1,
    color: color,
  );

  static TextStyle displayMedium({Color? color}) => TextStyle(
    fontSize: 64,
    fontWeight: FontWeight.w900,
    height: 1,
    color: color,
  );

  static TextStyle displaySmall({Color? color}) => TextStyle(
    fontSize: 48,
    fontWeight: FontWeight.w900,
    height: 1,
    color: color,
  );

  static TextStyle displayAction({Color? color}) => TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w900,
    height: 1,
    color: color,
  );

  static TextStyle displayCompact({Color? color}) => TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w900,
    height: 1,
    color: color,
  );

  static TextStyle displayUndo({Color? color}) => TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w900,
    height: 1,
    color: color,
  );

  static TextStyle headingLarge({Color? color}) => TextStyle(
    fontSize: 40,
    fontWeight: FontWeight.w800,
    height: 1.05,
    letterSpacing: -1.2,
    color: color,
  );

  static TextStyle headingMedium({Color? color}) => TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    height: 1.1,
    letterSpacing: -0.5,
    color: color,
  );

  static TextStyle title({Color? color}) => TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 1.25,
    color: color,
  );

  static TextStyle bodyLarge({Color? color}) => TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w400,
    height: 1.45,
    color: color,
  );

  static TextStyle body({Color? color}) => TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.45,
    color: color,
  );

  // Monospaced labels
  static TextStyle labelMono({
    double size = 12,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double? letterSpacing,
  }) => TextStyle(
    fontFamily: 'SF Mono',
    fontSize: size,
    fontWeight: weight,
    fontFamilyFallback: const ['Menlo', 'Monaco', 'monospace'],
    height: 1.45,
    letterSpacing: letterSpacing,
    color: color,
  );
}
