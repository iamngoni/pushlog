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
