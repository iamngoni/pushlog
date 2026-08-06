//
//  pushlog
//  action_strip.dart
//
//  Created by Ngonidzashe Mangudya on 2026/04/16.
//  Copyright (c) 2026 Codecraft Solutions. All rights reserved.
//

import 'package:flutter/material.dart';
import 'package:pushlog/core/configs/colors.dart';
import 'package:pushlog/core/configs/motion.dart';
import 'package:pushlog/core/configs/spacing.dart';
import 'package:pushlog/core/configs/typography.dart';
import 'package:pushlog/core/views/widgets/pushlog_button.dart';

/// The persistent logging bar.
///
/// Three cells, not four. The fourth used to open a live session, which is
/// the same destination as the labelled button at the top of the screen —
/// two entry points to one place, with the duplicate reduced to a four-
/// character label in the smallest control on the page. Dropping it gives
/// the remaining cells room to be comfortably tappable, and leaves the strip
/// doing one job: recording reps that were already done.
class ActionStrip extends StatelessWidget {
  const ActionStrip({
    required this.theme,
    required this.onAddReps,
    this.suggestedSet,
    super.key,
  });

  final AppTheme theme;
  final void Function(int reps) onAddReps;

  /// Reps in one set of today's plan. Null on a recovery day.
  final int? suggestedSet;

  @override
  Widget build(BuildContext context) {
    final planned = suggestedSet ?? 10;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.lg,
        AppSpacing.gutter,
        AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: theme.background,
        border: Border(top: BorderSide(color: theme.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: ActionCell(
              reps: 1,
              theme: theme,
              onTap: () => onAddReps(1),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          // The only Signal Lime on the screen while the target is
          // outstanding. This is the next action.
          Expanded(
            flex: 2,
            child: ActionCell(
              reps: planned,
              caption: suggestedSet == null ? null : 'One set',
              emphasized: true,
              theme: theme,
              onTap: () => onAddReps(planned),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: ActionCell(
              reps: 25,
              theme: theme,
              onTap: () => onAddReps(25),
            ),
          ),
        ],
      ),
    );
  }
}

class ActionCell extends StatelessWidget {
  const ActionCell({
    required this.reps,
    required this.theme,
    required this.onTap,
    this.caption,
    this.emphasized = false,
    this.isEnabled = true,
    super.key,
  });

  final int reps;
  final String? caption;
  final bool emphasized;
  final bool isEnabled;
  final AppTheme theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = emphasized ? theme.onAccent : theme.ink;
    final subInk = emphasized ? theme.onAccentMuted : theme.secondaryInk;

    return PressFeedback(
      enabled: isEnabled,
      onTap: onTap,
      haptic: AppHaptics.tick,
      semanticLabel: 'Log $reps reps',
      child: AnimatedContainer(
        duration: AppMotion.duration(context, AppMotion.fast),
        height: AppSpacing.controlHeight,
        decoration: BoxDecoration(
          color: emphasized ? theme.accent : theme.surface,
          borderRadius: AppRadius.all(AppRadius.md),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '+$reps',
                style: AppTypography.metricCompact(color: ink),
              ),
              if (caption != null) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  caption!,
                  style: AppTypography.labelSmall(color: subInk),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
