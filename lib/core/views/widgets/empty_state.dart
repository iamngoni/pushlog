//
//  pushlog
//  empty_state.dart
//
//  Created by Ngonidzashe Mangudya on 2026/04/16.
//  Copyright (c) 2026 Codecraft Solutions. All rights reserved.
//

import 'package:flutter/material.dart';
import 'package:pushlog/core/configs/colors.dart';
import 'package:pushlog/core/configs/spacing.dart';
import 'package:pushlog/core/configs/typography.dart';
import 'package:pushlog/core/views/widgets/pushlog_button.dart';

/// The first thing a user sees in a feature they have not used yet.
///
/// Treated as onboarding rather than as an error. "No entries found" wastes
/// the most valuable screen in the feature: at this moment the user has
/// nothing to read *except* this, so it explains what the feature is for and
/// offers the one action that fills it.
///
/// Callers should also hide filters, sort controls, and secondary tabs while
/// this is showing — chrome that operates on nothing makes a fresh install
/// look broken.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.compact = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  /// Renders inside a card or list slot rather than filling the screen.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final hasAction = actionLabel != null && onAction != null;
    final hasSecondary =
        secondaryActionLabel != null && onSecondaryAction != null;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpacing.proseMaxWidth),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? AppSpacing.xl : AppSpacing.gutter,
            vertical: compact ? AppSpacing.section : AppSpacing.hero,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Glyph(icon: icon, theme: theme, compact: compact),
              SizedBox(height: compact ? AppSpacing.xl : AppSpacing.block),
              Text(
                title,
                style: compact
                    ? AppTypography.headingSmall(color: theme.ink)
                    : AppTypography.headingMedium(color: theme.ink),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                message,
                style: AppTypography.body(color: theme.secondaryInk),
              ),
              if (hasAction) ...[
                SizedBox(height: compact ? AppSpacing.xl : AppSpacing.block),
                PushlogButton(
                  label: actionLabel!,
                  onPressed: onAction,
                  size: compact
                      ? PushlogButtonSize.medium
                      : PushlogButtonSize.large,
                ),
              ],
              if (hasSecondary) ...[
                const SizedBox(height: AppSpacing.lg),
                PushlogButton(
                  label: secondaryActionLabel!,
                  onPressed: onSecondaryAction,
                  variant: PushlogButtonVariant.ghost,
                  size: compact
                      ? PushlogButtonSize.medium
                      : PushlogButtonSize.large,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The icon, wrapped rather than scaled.
///
/// A 24pt glyph blown up to fill this space would just look coarse — it has
/// none of the detail an icon drawn at that size would carry. Keeping it at
/// its native size inside a tinted tile fills the area without the mush.
class _Glyph extends StatelessWidget {
  const _Glyph({
    required this.icon,
    required this.theme,
    required this.compact,
  });

  final IconData icon;
  final AppTheme theme;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final side = compact ? 44.0 : 56.0;
    return Container(
      width: side,
      height: side,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.accentSoft,
        borderRadius: AppRadius.all(AppRadius.md),
      ),
      child: Icon(icon, size: 24, color: theme.accentInk),
    );
  }
}

/// A one-line placeholder for an empty slot inside an otherwise full screen.
///
/// Use where a full [EmptyState] would overstate the situation — an empty
/// requests list on a page that already has content above it.
class EmptyLine extends StatelessWidget {
  const EmptyLine(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Text(
        message,
        style: AppTypography.body(color: theme.tertiaryInk),
      ),
    );
  }
}
