import 'package:flutter/material.dart';
import 'package:pushlog/core/configs/colors.dart';
import 'package:pushlog/core/configs/spacing.dart';
import 'package:pushlog/core/configs/typography.dart';
import 'package:pushlog/weight/models/data/weight_settings.dart';
import 'package:pushlog/weight/models/weight_correlation.dart';
import 'package:pushlog/weight/models/weight_math.dart';

class WeightCorrelationSection extends StatelessWidget {
  const WeightCorrelationSection({
    required this.correlation,
    required this.unit,
    required this.onLog,
    super.key,
  });

  final WeightCorrelation correlation;
  final WeightUnit unit;
  final VoidCallback onLog;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final hasWeighIn = correlation.rows.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Weight and training',
          style: AppTypography.headingSmall(color: theme.ink),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          correlation.showCoefficient
              ? 'Observed association, not a cause. '
                    'r = ${correlation.coefficient!.toStringAsFixed(2)}.'
              : hasWeighIn
              ? 'Not enough weeks yet to show an association.'
              : 'Log a weight to see it next to your reps.',
          style: AppTypography.body(color: theme.secondaryInk),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (!hasWeighIn)
          TextButton(onPressed: onLog, child: const Text('Log weight'))
        else
          for (final row in correlation.rows)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      row.weekStart,
                      style: AppTypography.label(color: theme.ink),
                    ),
                  ),
                  Text(
                    '${row.reps} reps',
                    style: AppTypography.body(color: theme.secondaryInk),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Text(
                    formatWeight(row.meanGrams, unit),
                    style: AppTypography.body(color: theme.ink),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Text(
                    row.changeGrams == null
                        ? '—'
                        : formatSignedChange(row.changeGrams!, unit),
                    style: AppTypography.body(color: theme.secondaryInk),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}
