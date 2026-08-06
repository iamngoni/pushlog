//
//  pushlog
//  avatar_badge.dart
//
//  Created by Ngonidzashe Mangudya on 2026/04/16.
//  Copyright (c) 2026 Codecraft Solutions. All rights reserved.
//

import 'package:flutter/material.dart';
import 'package:pushlog/core/configs/colors.dart';
import 'package:pushlog/core/configs/elevation.dart';
import 'package:pushlog/core/configs/spacing.dart';
import 'package:pushlog/core/configs/typography.dart';

/// An initials avatar.
///
/// Faces in a leaderboard have to be told apart at a glance, but handing
/// each user a different hue would scatter colour across a palette that
/// reserves it for one job. The tints here are steps along the app's own
/// neutral ramp instead: separation comes from lightness, which is both
/// on-brand and more reliable for colour-blind users than distinct hues.
///
/// Signal Lime is spent on exactly one avatar — the signed-in user — so
/// "which row is me" is answerable without reading a single word.
class AvatarBadge extends StatelessWidget {
  const AvatarBadge({
    required this.initials,
    this.seed,
    this.size = 40,
    this.isMe = false,
    this.rank,
    super.key,
  });

  final String initials;

  /// Username or uid. Picks the tint, so the same person keeps the same
  /// avatar between sessions and devices.
  final String? seed;

  final double size;
  final bool isMe;

  /// Draws a small rank chip on the lower edge. 1-based.
  final int? rank;

  static const List<Color> _darkTints = [
    AppColors.neutral800,
    AppColors.neutral750,
    AppColors.neutral700,
    AppColors.neutral600,
    AppColors.neutral500,
  ];

  static const List<Color> _lightTints = [
    AppColors.neutral150,
    AppColors.neutral200,
    AppColors.neutral250,
    AppColors.neutral300,
    AppColors.neutral400,
  ];

  Color _tint(AppTheme theme) {
    if (isMe) return theme.accent;
    final key = seed ?? initials;
    if (key.isEmpty) return theme.surfaceRaised;
    final tints = theme.isDark ? _darkTints : _lightTints;
    final index =
        key.codeUnits.fold<int>(0, (sum, unit) => sum + unit) % tints.length;
    return tints[index];
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final tint = _tint(theme);
    final ink = isMe
        ? theme.onAccent
        : theme.isDark
        ? theme.ink
        : AppColors.neutral900;

    final avatar = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
      // An inset hairline rather than a border: it defines the edge without
      // a hard stroke, so an avatar whose tint lands near the page colour
      // still reads as a distinct object instead of melting into it.
      foregroundDecoration: AppElevation.innerEdge(
        theme,
        shape: BoxShape.circle,
      ),
      child: Text(
        initials.isEmpty ? '?' : initials.toUpperCase(),
        style: AppTypography.labelSmall(
          color: ink,
          weight: FontWeight.w800,
        ).copyWith(fontSize: size * 0.34),
      ),
    );

    if (rank == null) {
      return Semantics(
        label: isMe ? 'You' : null,
        image: true,
        child: avatar,
      );
    }

    return Semantics(
      label: isMe ? 'You, rank $rank' : 'Rank $rank',
      excludeSemantics: true,
      // The chip breaks the circle's outline. Letting one element cross the
      // boundary of another is the cheapest way to build a sense of layers
      // in a design that has no shadows to spend.
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          avatar,
          Positioned(
            bottom: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 1,
              ),
              decoration: BoxDecoration(
                color: isMe ? theme.accent : theme.surfaceRaised,
                borderRadius: AppRadius.all(AppRadius.full),
                border: Border.all(color: theme.background, width: 2),
              ),
              child: Text(
                '$rank',
                style: AppTypography.metric(
                  size: 10,
                  color: isMe ? theme.onAccent : theme.secondaryInk,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
