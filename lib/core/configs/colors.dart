//
//  pushlog
//  colors.dart
//
//  Created by Ngonidzashe Mangudya on 2026/04/16.
//  Copyright (c) 2026 Codecraft Solutions. All rights reserved.
//

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// The Pushlog palette.
///
/// Every neutral sits on a warm olive axis (hue ~74°, 9–14% saturation) so
/// the light and dark themes read as the same product rather than two
/// inversions of it. Pure black and pure white are deliberately absent.
///
/// Signal Lime shares that hue, which is why the accent feels native to the
/// neutrals instead of pasted on top of them. Its ramp rotates hue from 66°
/// at the palest tint to 80° at the deepest shade — lightening a saturated
/// colour without rotating it toward yellow drains the life out of it.
///
/// Shades are fixed. Never lighten or darken at the call site; if a value
/// between two steps is needed, add the step here so it exists exactly once.
class AppColors {
  const AppColors._();

  // ---------------------------------------------------------------------
  // Neutral ramp — warm olive, hue ~74°
  // ---------------------------------------------------------------------

  static const Color neutral950 = Color(0xFF0F100C);
  static const Color neutral900 = Color(0xFF151611);
  static const Color neutral850 = Color(0xFF1F211A);
  static const Color neutral800 = Color(0xFF2A2C23);
  static const Color neutral750 = Color(0xFF33362C);
  static const Color neutral700 = Color(0xFF404337);
  static const Color neutral600 = Color(0xFF585C4D);
  static const Color neutral500 = Color(0xFF787D68);
  static const Color neutral400 = Color(0xFF919782);
  static const Color neutral300 = Color(0xFFA9AD9D);
  static const Color neutral250 = Color(0xFFC0C3B6);
  static const Color neutral200 = Color(0xFFD4D6CC);
  static const Color neutral150 = Color(0xFFE3E4DC);
  static const Color neutral100 = Color(0xFFEBECE6);
  static const Color neutral50 = Color(0xFFF3F4EE);
  static const Color neutral25 = Color(0xFFF7F7F2);

  // ---------------------------------------------------------------------
  // Signal Lime ramp — hue rotates 66° → 80° as it darkens
  // ---------------------------------------------------------------------

  static const Color accent100 = Color(0xFFF9FDD9);
  static const Color accent200 = Color(0xFFF0FAB3);
  static const Color accent300 = Color(0xFFE2F67E);
  static const Color accent400 = Color(0xFFD4F358);
  static const Color accent500 = Color(0xFFC8F135);
  static const Color accent600 = Color(0xFFA4D317);
  static const Color accent700 = Color(0xFF78A30A);
  static const Color accent800 = Color(0xFF567C03);
  static const Color accent900 = Color(0xFF3D5A02);

  // ---------------------------------------------------------------------
  // Semantic — always paired with an icon or label, never colour alone
  // ---------------------------------------------------------------------

  /// Warm red. 5.07:1 on the dark surface.
  static const Color dangerDark = Color(0xFFE46B58);

  /// 5.24:1 on paper.
  static const Color dangerLight = Color(0xFFBC3824);
  static const Color dangerSoftDark = Color(0xFF391D18);
  static const Color dangerSoftLight = Color(0xFFFCEBE8);

  /// Amber. 8.71:1 on the dark surface.
  static const Color warningDark = Color(0xFFF5B13D);

  /// 5.77:1 on paper.
  static const Color warningLight = Color(0xFF915108);
  static const Color warningSoftDark = Color(0xFF342A19);
  static const Color warningSoftLight = Color(0xFFFDF4E2);

  // ---------------------------------------------------------------------
  // Named roles — the ramp entries the themes actually bind to
  // ---------------------------------------------------------------------

  static const Color backgroundDark = neutral900;
  static const Color backgroundLight = neutral25;

  static const Color surfaceDark = neutral850;
  static const Color surfaceLight = Color(0xFFFFFFFF);

  /// One tonal step above [surfaceDark] / below [surfaceLight]. Depth in a
  /// flat design comes from tone: lighter than its backdrop reads as closer.
  static const Color surfaceRaisedDark = neutral800;
  static const Color surfaceRaisedLight = Color(0xFFFFFFFF);

  /// Recessed wells — input fields, track backgrounds.
  static const Color surfaceSunkenDark = neutral950;
  static const Color surfaceSunkenLight = neutral50;

  static const Color inkDark = Color(0xFFF3F5EA);
  static const Color inkLight = Color(0xFF171811);

  /// 7.92:1 dark, 5.06:1 light.
  static const Color secondaryInkDark = neutral300;
  static const Color secondaryInkLight = Color(0xFF686B60);

  /// Third level of text emphasis. 6.02:1 dark, 6.40:1 light.
  static const Color tertiaryInkDark = neutral400;
  static const Color tertiaryInkLight = neutral600;

  static const Color dividerDark = neutral750;
  static const Color dividerLight = Color(0xFFDFE1D7);

  /// A softer, wider structural line. Pairing a 1px hairline with a low
  /// contrast colour reads as calmer than a hard divider at full strength.
  static const Color dividerSoftDark = neutral800;
  static const Color dividerSoftLight = neutral100;

  /// Signal Lime. Identical in both themes — it is the one fixed point.
  static const Color accent = accent500;

  /// Lime as *text* on a neutral background. The raw accent is too light to
  /// read on paper, so the light theme uses a deep lime ink instead.
  static const Color accentInkDark = accent500;
  static const Color accentInkLight = Color(0xFF506900);

  /// Tinted lime background for selected rows and soft callouts.
  static const Color accentSoftDark = Color(0xFF232A0D);
  static const Color accentSoftLight = accent100;

  static const Color accentStrokeDark = Color(0x29F8F5F0);
  static const Color accentStrokeLight = Color(0x240A0908);

  /// Fixed dark ink for anything sitting on Signal Lime. 13.69:1.
  static const Color fixedDark = Color(0xFF171811);

  /// Secondary text on Signal Lime, hand-picked in the accent's own hue.
  ///
  /// Dropping the opacity of [fixedDark] instead would leak the lime
  /// through and read as disabled. 5.85:1 against [accent500].
  static const Color onAccentMuted = Color(0xFF485A16);
}

/// The resolved set of colours for one brightness.
///
/// Widgets read `AppTheme.of(context)` rather than reaching into
/// [AppColors] directly, so a screen never has to know which theme is live.
class AppTheme {
  const AppTheme({
    required this.isDark,
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceSunken,
    required this.ink,
    required this.secondaryInk,
    required this.tertiaryInk,
    required this.divider,
    required this.dividerSoft,
    required this.accent,
    required this.accentInk,
    required this.accentSoft,
    required this.accentStroke,
    required this.onAccent,
    required this.onAccentMuted,
    required this.danger,
    required this.dangerSoft,
    required this.warning,
    required this.warningSoft,
    required this.shadow,
  });

  factory AppTheme.dark() => const AppTheme(
    isDark: true,
    background: AppColors.backgroundDark,
    surface: AppColors.surfaceDark,
    surfaceRaised: AppColors.surfaceRaisedDark,
    surfaceSunken: AppColors.surfaceSunkenDark,
    ink: AppColors.inkDark,
    secondaryInk: AppColors.secondaryInkDark,
    tertiaryInk: AppColors.tertiaryInkDark,
    divider: AppColors.dividerDark,
    dividerSoft: AppColors.dividerSoftDark,
    accent: AppColors.accent,
    accentInk: AppColors.accentInkDark,
    accentSoft: AppColors.accentSoftDark,
    accentStroke: AppColors.accentStrokeDark,
    onAccent: AppColors.fixedDark,
    onAccentMuted: AppColors.onAccentMuted,
    danger: AppColors.dangerDark,
    dangerSoft: AppColors.dangerSoftDark,
    warning: AppColors.warningDark,
    warningSoft: AppColors.warningSoftDark,
    shadow: Color(0xFF000000),
  );

  factory AppTheme.light() => const AppTheme(
    isDark: false,
    background: AppColors.backgroundLight,
    surface: AppColors.surfaceLight,
    surfaceRaised: AppColors.surfaceRaisedLight,
    surfaceSunken: AppColors.surfaceSunkenLight,
    ink: AppColors.inkLight,
    secondaryInk: AppColors.secondaryInkLight,
    tertiaryInk: AppColors.tertiaryInkLight,
    divider: AppColors.dividerLight,
    dividerSoft: AppColors.dividerSoftLight,
    accent: AppColors.accent,
    accentInk: AppColors.accentInkLight,
    accentSoft: AppColors.accentSoftLight,
    accentStroke: AppColors.accentStrokeLight,
    onAccent: AppColors.fixedDark,
    onAccentMuted: AppColors.onAccentMuted,
    danger: AppColors.dangerLight,
    dangerSoft: AppColors.dangerSoftLight,
    warning: AppColors.warningLight,
    warningSoft: AppColors.warningSoftLight,
    shadow: Color(0xFF2A2C23),
  );

  final bool isDark;
  final Color background;
  final Color surface;
  final Color surfaceRaised;
  final Color surfaceSunken;
  final Color ink;
  final Color secondaryInk;
  final Color tertiaryInk;
  final Color divider;
  final Color dividerSoft;
  final Color accent;
  final Color accentInk;
  final Color accentSoft;
  final Color accentStroke;
  final Color onAccent;
  final Color onAccentMuted;
  final Color danger;
  final Color dangerSoft;
  final Color warning;
  final Color warningSoft;
  final Color shadow;

  /// Success reuses Signal Lime: in a training ledger, "done" and "next"
  /// are the same signal, and a second green would dilute it.
  Color get success => accentInk;

  Color get successSoft => accentSoft;

  // ignore: prefer_constructors_over_static_methods - mirrors Theme.of convention
  static AppTheme of(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? AppTheme.dark() : AppTheme.light();
  }

  ThemeData toMaterialTheme(Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: accent,
        onPrimary: onAccent,
        primaryContainer: accentSoft,
        onPrimaryContainer: accentInk,
        secondary: ink,
        onSecondary: background,
        error: danger,
        onError: isDark ? AppColors.neutral950 : Colors.white,
        errorContainer: dangerSoft,
        onErrorContainer: danger,
        surface: surface,
        onSurface: ink,
        onSurfaceVariant: secondaryInk,
        outline: divider,
        outlineVariant: dividerSoft,
        shadow: shadow,
      ),
      dividerColor: divider,
      dividerTheme: DividerThemeData(
        color: divider,
        space: 1,
        thickness: 1,
      ),
      splashFactory: InkSparkle.splashFactory,
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: accent,
        selectionColor: accent.withValues(alpha: 0.28),
        selectionHandleColor: accent,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
