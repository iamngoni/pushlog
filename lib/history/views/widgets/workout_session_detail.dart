import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pushlog/core/configs/colors.dart';
import 'package:pushlog/core/configs/spacing.dart';
import 'package:pushlog/core/configs/typography.dart';
import 'package:pushlog/workout/models/data/workout_session.dart';

class WorkoutSessionDetail extends StatelessWidget {
  const WorkoutSessionDetail({
    required this.session,
    required this.theme,
    required this.showDivider,
    this.showDate = false,
    super.key,
  });

  final WorkoutSession session;
  final AppTheme theme;
  final bool showDivider;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final isLive = session.source == WorkoutSource.live;
    final details = <(String, String)>[
      if (session.duration != null)
        ('Duration', _formatDuration(session.duration!)),
      if (session.averageRepDuration != null)
        ('Average rep', _formatDuration(session.averageRepDuration!)),
      if (session.effortScore != null)
        ('Effort', _formatEffort(session.effortScore!)),
      if (session.latestHeartRate != null && session.latestHeartRate! > 0)
        ('Latest heart rate', '${session.latestHeartRate!.round()} BPM'),
      if (session.activeCalories != null && session.activeCalories! > 0)
        ('Active energy', _formatCalories(session.activeCalories!)),
      if (isLive) ('Manual adjustments', '${session.manualAdjustments}'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isLive ? 'LIVE SESSION' : 'MANUAL ENTRY',
                      style: AppTypography.overline(
                        color: isLive ? theme.accentInk : theme.tertiaryInk,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      DateFormat(
                        showDate ? 'd MMM yyyy · HH:mm' : 'HH:mm',
                      ).format(session.date),
                      style: AppTypography.bodySmall(
                        color: theme.secondaryInk,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xl),
              Text(
                '${session.reps} reps',
                style: AppTypography.metricCompact(color: theme.ink),
              ),
            ],
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            for (final detail in details)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        detail.$1,
                        style: AppTypography.bodySmall(
                          color: theme.secondaryInk,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xl),
                    Text(
                      detail.$2,
                      style: AppTypography.metricInline(color: theme.ink),
                    ),
                  ],
                ),
              ),
          ],
          if (showDivider) ...[
            const SizedBox(height: AppSpacing.sm),
            Divider(height: 1, color: theme.dividerSoft),
          ],
        ],
      ),
    );
  }

  static String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  static String _formatEffort(int score) => switch (score) {
    <= 2 => '$score/10 · Light',
    <= 4 => '$score/10 · Easy',
    <= 6 => '$score/10 · Moderate',
    <= 8 => '$score/10 · Hard',
    _ => '$score/10 · All out',
  };

  static String _formatCalories(double calories) {
    final value = calories == calories.roundToDouble()
        ? calories.toStringAsFixed(0)
        : calories.toStringAsFixed(1);
    return '$value kcal';
  }
}
