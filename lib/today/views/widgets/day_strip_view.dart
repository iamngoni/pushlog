//
//  pushlog
//  day_strip_view.dart
//
//  Created by Ngonidzashe Mangudya on 2026/04/16.
//  Copyright (c) 2026 Codecraft Solutions. All rights reserved.
//

import 'package:flutter/material.dart';
import 'package:pushlog/core/configs/colors.dart';
import 'package:pushlog/core/configs/typography.dart';
import 'package:pushlog/workout/models/data/day_summary.dart';

class DayStripView extends StatelessWidget {
  const DayStripView({
    required this.summary,
    required this.theme,
    super.key,
  });

  final List<DaySummary> summary;
  final AppTheme theme;

  int get maxCount {
    if (summary.isEmpty) return 1;
    final max = summary
        .map((s) => s.count)
        .reduce(
          (a, b) => a > b ? a : b,
        );
    return max == 0 ? 1 : max;
  }

  double barHeight(int count) {
    const minH = 4.0;
    const maxH = 44.0;
    if (count <= 0) return minH;
    return minH + (maxH - minH) * count.toDouble() / maxCount.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: summary.map((day) {
          final Color color;
          if (day.isToday) {
            color = theme.accent;
          } else if (day.count > 0) {
            color = theme.ink;
          } else {
            color = theme.divider;
          }
          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 14,
                  height: barHeight(day.count),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _weekday(day.date.weekday),
                  style: AppTypography.labelMono(
                    size: 10,
                    color: day.isToday ? theme.ink : theme.secondaryInk,
                    weight: day.isToday ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  String _weekday(int weekday) {
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return labels[weekday - 1];
  }
}
