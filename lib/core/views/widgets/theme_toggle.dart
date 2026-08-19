//
//  pushlog
//  theme_toggle.dart
//
//  Copyright (c) 2026 Codecraft Solutions. All rights reserved.
//

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pushlog/core/configs/colors.dart';
import 'package:pushlog/core/configs/motion.dart';
import 'package:pushlog/core/configs/spacing.dart';
import 'package:pushlog/core/state/theme_mode_cubit.dart';
import 'package:pushlog/core/views/widgets/pushlog_button.dart';

/// Switches the app between light and dark.
///
/// The glyph shows the *destination*, not the current state — a moon while
/// the screen is light, a sun while it is dark. A control that pictures
/// where you already are gives the user nothing to act on.
class ThemeToggle extends StatelessWidget {
  const ThemeToggle({this.size = 20, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    // The rendered brightness, not the stored mode: while the preference is
    // still "system" there is no stored side to read.
    final isDarkNow = Theme.of(context).brightness == Brightness.dark;

    return PressFeedback(
      semanticLabel: isDarkNow
          ? 'Switch to light theme'
          : 'Switch to dark theme',
      onTap: () => unawaited(
        context.read<ThemeModeCubit>().toggle(isDarkNow: isDarkNow),
      ),
      // Padded out to the platform minimum: the glyph itself is well under
      // a comfortable target.
      child: SizedBox(
        width: AppSpacing.minTapTarget,
        height: AppSpacing.minTapTarget,
        child: Center(
          child: AnimatedSwitcher(
            duration: AppMotion.duration(context, AppMotion.base),
            switchInCurve: AppMotion.enter,
            switchOutCurve: AppMotion.exit,
            transitionBuilder: (child, animation) => RotationTransition(
              // A quarter turn, so the swap reads as one control changing
              // rather than two icons cross-fading.
              turns: Tween<double>(begin: 0.75, end: 1).animate(animation),
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: Icon(
              isDarkNow ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              key: ValueKey<bool>(isDarkNow),
              size: size,
              color: theme.secondaryInk,
            ),
          ),
        ),
      ),
    );
  }
}
