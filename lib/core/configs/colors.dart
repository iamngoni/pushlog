//
//  pushlog
//  colors.dart
//
//  Created by Ngonidzashe Mangudya on 2026/04/16.
//  Copyright (c) 2026 Codecraft Solutions. All rights reserved.
//

import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  // Background
  static const Color backgroundDark = Color(0xFF0A0908);
  static const Color backgroundLight = Color(0xFFFAFAF8);

  // Surface
  static const Color surfaceDark = Color(0xFF141210);
  static const Color surfaceLight = Color(0x99FFFFFF);

  // Ink
  static const Color inkDark = Color(0xFFF8F5F0);
  static const Color inkLight = Color(0xFF0A0908);

  // Secondary Ink
  static const Color secondaryInkDark = Color(0xFFB7B1A9);
  static const Color secondaryInkLight = Color(0xFF625D58);

  // Divider
  static const Color dividerDark = Color(0xFF282522);
  static const Color dividerLight = Color(0xFFD5D2CE);

  // Accent — same in both modes
  static const Color accent = Color(0xFFD7FF1F);

  // Accent Ink
  static const Color accentInkDark = Color(0xFFD7FF1F);
  static const Color accentInkLight = Color(0xFF718500);

  // Accent Stroke
  static const Color accentStrokeDark = Color(0x29F8F5F0);
  static const Color accentStrokeLight = Color(0x240A0908);

  // Fixed dark ink (for accent backgrounds)
  static const Color fixedDark = Color(0xFF0A0908);
}

class AppTheme {
  const AppTheme({
    required this.background,
    required this.surface,
    required this.ink,
    required this.secondaryInk,
    required this.divider,
    required this.accent,
    required this.accentInk,
    required this.accentStroke,
  });

  factory AppTheme.dark() => const AppTheme(
    background: AppColors.backgroundDark,
    surface: AppColors.surfaceDark,
    ink: AppColors.inkDark,
    secondaryInk: AppColors.secondaryInkDark,
    divider: AppColors.dividerDark,
    accent: AppColors.accent,
    accentInk: AppColors.accentInkDark,
    accentStroke: AppColors.accentStrokeDark,
  );

  factory AppTheme.light() => const AppTheme(
    background: AppColors.backgroundLight,
    surface: AppColors.surfaceLight,
    ink: AppColors.inkLight,
    secondaryInk: AppColors.secondaryInkLight,
    divider: AppColors.dividerLight,
    accent: AppColors.accent,
    accentInk: AppColors.accentInkLight,
    accentStroke: AppColors.accentStrokeLight,
  );

  final Color background;
  final Color surface;
  final Color ink;
  final Color secondaryInk;
  final Color divider;
  final Color accent;
  final Color accentInk;
  final Color accentStroke;

  // ignore: prefer_constructors_over_static_methods - mirrors Theme.of convention
  static AppTheme of(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? AppTheme.dark() : AppTheme.light();
  }

  ThemeData toMaterialTheme(Brightness brightness) {
    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: accent,
        onPrimary: AppColors.fixedDark,
        secondary: accent,
        onSecondary: AppColors.fixedDark,
        error: Colors.redAccent,
        onError: Colors.white,
        surface: surface,
        onSurface: ink,
      ),
      dividerColor: divider,
    );
  }
}
