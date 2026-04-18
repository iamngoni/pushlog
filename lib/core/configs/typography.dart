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

  // Display: HelveticaNeue-CondensedBlack
  static TextStyle displayLarge({Color? color}) => TextStyle(
        fontFamily: 'HelveticaNeue-CondensedBlack',
        fontSize: 150,
        fontWeight: FontWeight.w900,
        height: 1,
        color: color,
      );

  static TextStyle displayMedium({Color? color}) => TextStyle(
        fontFamily: 'HelveticaNeue-CondensedBlack',
        fontSize: 120,
        fontWeight: FontWeight.w900,
        height: 1,
        color: color,
      );

  static TextStyle displaySmall({Color? color}) => TextStyle(
        fontFamily: 'HelveticaNeue-CondensedBlack',
        fontSize: 64,
        fontWeight: FontWeight.w900,
        height: 1,
        color: color,
      );

  static TextStyle displayAction({Color? color}) => TextStyle(
        fontFamily: 'HelveticaNeue-CondensedBlack',
        fontSize: 30,
        fontWeight: FontWeight.w900,
        height: 1,
        color: color,
      );

  static TextStyle displayCompact({Color? color}) => TextStyle(
        fontFamily: 'HelveticaNeue-CondensedBlack',
        fontSize: 42,
        fontWeight: FontWeight.w900,
        height: 1,
        color: color,
      );

  static TextStyle displayUndo({Color? color}) => TextStyle(
        fontFamily: 'HelveticaNeue-CondensedBlack',
        fontSize: 34,
        fontWeight: FontWeight.w900,
        height: 1,
        color: color,
      );

  // Monospaced labels
  static TextStyle labelMono({
    double size = 10,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double? letterSpacing,
  }) =>
      TextStyle(
        fontFamily: 'Courier',
        fontSize: size,
        fontWeight: weight,
        fontFamilyFallback: const ['Courier New', 'monospace'],
        letterSpacing: letterSpacing,
        color: color,
      );
}
