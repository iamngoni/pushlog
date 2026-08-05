import 'package:flutter/material.dart';
import 'package:pushlog/core/configs/colors.dart';
import 'package:pushlog/core/configs/typography.dart';
import 'package:pushlog/training/models/training_plan.dart';

class DailyPlanBlock extends StatelessWidget {
  const DailyPlanBlock({
    required this.session,
    required this.completedReps,
    required this.theme,
    super.key,
  });

  final PlannedSession session;
  final int completedReps;
  final AppTheme theme;

  @override
  Widget build(BuildContext context) {
    final target = session.totalReps;
    final progress = target == 0
        ? 0.0
        : (completedReps / target).clamp(0.0, 1.0);
    final isComplete = target > 0 && completedReps >= target;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.surface,
        border: Border.all(color: isComplete ? theme.accent : theme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                session.isTrainingDay ? "TODAY'S SESSION" : 'RECOVERY DAY',
                style: AppTypography.labelMono(
                  size: 10,
                  color: theme.secondaryInk,
                  letterSpacing: 1.6,
                ),
              ),
              const Spacer(),
              Text(
                'WEEK ${session.weekNumber}',
                style: AppTypography.labelMono(
                  size: 10,
                  color: theme.secondaryInk,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _title(isComplete),
            style: AppTypography.title(color: theme.ink),
          ),
          const SizedBox(height: 5),
          Text(
            _detail(isComplete),
            style: AppTypography.body(color: theme.secondaryInk),
          ),
          if (session.isTrainingDay) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                minHeight: 5,
                value: progress,
                color: theme.accent,
                backgroundColor: theme.divider,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${completedReps.clamp(0, target)} / $target REPS',
              style: AppTypography.labelMono(
                size: 10,
                color: theme.secondaryInk,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _title(bool isComplete) {
    if (!session.isTrainingDay) return 'Recovery is part of the plan.';
    if (isComplete) return 'Session complete.';
    return '${session.sets} sets × ${session.repsPerSet} clean reps';
  }

  String _detail(bool isComplete) {
    if (!session.isTrainingDay) {
      return 'Move if it feels good. Your next planned day will be ready here.';
    }
    if (isComplete) return 'Extra work is optional. Keep clean form.';
    if (session.isAssessmentWeek) {
      return 'Assessment week. Stop before form breaks and adjust if needed.';
    }
    return 'Rest as needed between sets. Stop if you feel pain.';
  }
}
