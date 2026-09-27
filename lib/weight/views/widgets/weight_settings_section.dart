import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pushlog/core/configs/colors.dart';
import 'package:pushlog/core/configs/spacing.dart';
import 'package:pushlog/core/configs/typography.dart';
import 'package:pushlog/weight/models/data/weight_settings.dart';
import 'package:pushlog/weight/state/weight_cubit.dart';
import 'package:pushlog/weight/state/weight_state.dart';

class WeightSettingsSection extends StatelessWidget {
  const WeightSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return BlocBuilder<WeightCubit, WeightState>(
      builder: (context, state) {
        final settings = state.settings;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'WEIGHT',
              style: AppTypography.overline(color: theme.tertiaryInk),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Unit, goal, and what friends can see.',
              style: AppTypography.body(color: theme.secondaryInk),
            ),
            const SizedBox(height: AppSpacing.lg),
            SegmentedButton<WeightUnit>(
              segments: const [
                ButtonSegment(value: WeightUnit.kg, label: Text('kg')),
                ButtonSegment(value: WeightUnit.lb, label: Text('lb')),
              ],
              selected: {settings.unit},
              onSelectionChanged: (value) {
                unawaited(
                  context.read<WeightCubit>().updateSettings(
                    settings.copyWith(unit: value.first, dirty: true),
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            SegmentedButton<WeightGoal>(
              segments: const [
                ButtonSegment(value: WeightGoal.lose, label: Text('Lose')),
                ButtonSegment(value: WeightGoal.maintain, label: Text('Hold')),
                ButtonSegment(value: WeightGoal.gain, label: Text('Gain')),
              ],
              selected: {settings.goal},
              onSelectionChanged: (value) {
                unawaited(
                  context.read<WeightCubit>().updateSettings(
                    settings.copyWith(goal: value.first, dirty: true),
                  ),
                );
              },
            ),
            _ShareSwitch(
              title: 'Share progress with friends',
              detail: 'They see your 28-day change and goal, not your weight.',
              value: settings.shareProgress,
              onChanged: (value) {
                unawaited(
                  context.read<WeightCubit>().updateSettings(
                    settings.copyWith(
                      shareProgress: value,
                      shareLatestWeight: value && settings.shareLatestWeight,
                      dirty: true,
                    ),
                  ),
                );
              },
            ),
            _ShareSwitch(
              title: 'Share latest weight',
              detail: 'Adds the latest number. Off unless progress is shared.',
              value: settings.shareProgress && settings.shareLatestWeight,
              onChanged: settings.shareProgress
                  ? (value) {
                      unawaited(
                        context.read<WeightCubit>().updateSettings(
                          settings.copyWith(
                            shareLatestWeight: value,
                            dirty: true,
                          ),
                        ),
                      );
                    }
                  : null,
            ),
          ],
        );
      },
    );
  }
}

class _ShareSwitch extends StatelessWidget {
  const _ShareSwitch({
    required this.title,
    required this.detail,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String detail;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.body(
                    color: theme.ink,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  detail,
                  style: AppTypography.bodySmall(color: theme.secondaryInk),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Switch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
