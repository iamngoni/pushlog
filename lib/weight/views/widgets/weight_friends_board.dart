import 'package:flutter/material.dart';
import 'package:pushlog/core/configs/colors.dart';
import 'package:pushlog/core/configs/spacing.dart';
import 'package:pushlog/core/configs/typography.dart';
import 'package:pushlog/weight/models/data/weight_entry.dart';
import 'package:pushlog/weight/models/data/weight_settings.dart';
import 'package:pushlog/weight/models/weight_math.dart';

class WeightFriendsBoard extends StatelessWidget {
  const WeightFriendsBoard({
    required this.entries,
    required this.unit,
    required this.error,
    super.key,
  });

  final List<FriendWeighIn> entries;
  final WeightUnit unit;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Weigh-ins', style: AppTypography.headingSmall(color: theme.ink)),
        const SizedBox(height: AppSpacing.md),
        if (error != null)
          Text(
            'Could not load weigh-ins. Your rep board is unchanged.',
            style: AppTypography.body(color: theme.secondaryInk),
          )
        else if (entries.isEmpty)
          Text(
            'Friends who share progress appear here. '
            'Sharing is off until you turn it on.',
            style: AppTypography.body(color: theme.secondaryInk),
          )
        else
          for (final entry in entries)
            _Row(entry: entry, unit: unit, theme: theme),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.entry, required this.unit, required this.theme});

  final FriendWeighIn entry;
  final WeightUnit unit;
  final AppTheme theme;

  @override
  Widget build(BuildContext context) {
    final name = entry.displayName ?? entry.username ?? 'Friend';
    final change = formatSignedChange(entry.signedChangeGrams, unit);
    final latest = entry.latestWeightGrams == null
        ? ''
        : ' · ${formatWeight(entry.latestWeightGrams!, unit)}';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Text(
        '$name · ${entry.goal} · $change · ${entry.weighInCount} logs$latest',
        style: AppTypography.body(color: theme.ink),
      ),
    );
  }
}
