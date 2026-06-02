//
//  pushlog
//  day_strip_view.dart
//
//  Created by Ngonidzashe Mangudya on 2026/04/16.
//  Copyright (c) 2026 Codecraft Solutions. All rights reserved.
//

import 'package:flutter/material.dart';
import 'package:pushlog/core/configs/colors.dart';
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
    const minH = 3.0;
    const maxH = 28.0;
    if (count <= 0) return minH;
    return minH + (maxH - minH) * count.toDouble() / maxCount.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: summary.map((day) {
        final Color color;
        if (day.isToday) {
          color = theme.accent;
        } else if (day.count > 0) {
          color = theme.ink;
        } else {
          color = theme.divider;
        }
        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Container(
              width: day.isToday ? 10 : 8,
              height: barHeight(day.count),
              color: color,
            ),
          ),
        );
      }).toList(),
    );
  }
}
