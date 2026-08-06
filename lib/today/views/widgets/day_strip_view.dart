//
//  pushlog
//  day_strip_view.dart
//
//  Created by Ngonidzashe Mangudya on 2026/04/16.
//  Copyright (c) 2026 Codecraft Solutions. All rights reserved.
//

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pushlog/core/configs/colors.dart';
import 'package:pushlog/core/configs/motion.dart';
import 'package:pushlog/core/configs/spacing.dart';
import 'package:pushlog/core/configs/typography.dart';
import 'package:pushlog/workout/models/data/day_summary.dart';

/// The last seven days as bars.
///
/// Today is the only bar in Signal Lime. Days with work are ink; days
/// without are a divider-weight stub rather than nothing at all, so the
/// week reads as seven slots with gaps in it instead of a chart that
/// mysteriously starts on Wednesday.
class DayStripView extends StatelessWidget {
  const DayStripView({
    required this.summary,
    required this.theme,
    super.key,
  });

  final List<DaySummary> summary;
  final AppTheme theme;

  static const double _minHeight = 4;
  static const double _maxHeight = 56;

  int get maxCount {
    if (summary.isEmpty) return 1;
    final max = summary.map((s) => s.count).reduce((a, b) => a > b ? a : b);
    return max == 0 ? 1 : max;
  }

  double barHeight(int count) {
    if (count <= 0) return _minHeight;
    return _minHeight +
        (_maxHeight - _minHeight) * count.toDouble() / maxCount.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    // Tall enough for the count, the full-height bar, the gap, and the
    // weekday initial at the largest text scale the app allows.
    return SizedBox(
      height: 112,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final day in summary)
            Expanded(
              child: _DayBar(
                day: day,
                theme: theme,
                height: barHeight(day.count),
              ),
            ),
        ],
      ),
    );
  }
}

class _DayBar extends StatelessWidget {
  const _DayBar({
    required this.day,
    required this.theme,
    required this.height,
  });

  final DaySummary day;
  final AppTheme theme;
  final double height;

  @override
  Widget build(BuildContext context) {
    final Color color;
    if (day.isToday) {
      color = theme.accent;
    } else if (day.count > 0) {
      color = theme.ink;
    } else {
      color = theme.divider;
    }

    return Semantics(
      label: '${DateFormat('EEEE').format(day.date)}: '
          '${day.count} ${day.count == 1 ? 'rep' : 'reps'}'
          '${day.isToday ? ', today' : ''}',
      excludeSemantics: true,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (day.count > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Text(
                '${day.count}',
                style: AppTypography.metric(
                  size: 11,
                  color: day.isToday ? theme.ink : theme.tertiaryInk,
                  weight: day.isToday ? FontWeight.w800 : FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
            ),
          AnimatedContainer(
            duration: AppMotion.duration(context, AppMotion.base),
            curve: AppMotion.settle,
            width: 12,
            height: height,
            decoration: BoxDecoration(
              color: color,
              borderRadius: AppRadius.all(AppRadius.indicator),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            DateFormat('EEEEE').format(day.date),
            style: AppTypography.labelSmall(
              color: day.isToday ? theme.ink : theme.tertiaryInk,
              weight: day.isToday ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
