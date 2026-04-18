//
//  pushlog
//  stats_block.dart
//
//  Created by Ngonidzashe Mangudya on 2026/04/16.
//  Copyright (c) 2026 Codecraft Solutions. All rights reserved.
//

import 'package:flutter/material.dart';
import 'package:pushlog/core/configs/colors.dart';
import 'package:pushlog/core/configs/typography.dart';

class StatsBlock extends StatelessWidget {
  const StatsBlock({
    required this.streak,
    required this.bestDay,
    required this.totalAllTime,
    required this.theme,
    super.key,
  });

  final int streak;
  final int bestDay;
  final int totalAllTime;
  final AppTheme theme;

  String twoDigit(int value) =>
      value.toString().padLeft(2, '0');

  String abbreviated(int value) {
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}k';
    }
    return '$value';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: StatColumn(
            value: twoDigit(streak),
            label: 'STREAK',
            theme: theme,
          ),
        ),
        Expanded(
          child: StatColumn(
            value: '$bestDay',
            label: 'BEST',
            theme: theme,
          ),
        ),
        Expanded(
          child: StatColumn(
            value: abbreviated(totalAllTime),
            label: 'ALL TIME',
            theme: theme,
          ),
        ),
      ],
    );
  }
}

class StatColumn extends StatelessWidget {
  const StatColumn({
    required this.value,
    required this.label,
    required this.theme,
    super.key,
  });

  final String value;
  final String label;
  final AppTheme theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: AppTypography.labelMono(
            size: 20,
            weight: FontWeight.w500,
            color: theme.ink,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: AppTypography.labelMono(
            size: 8,
            color: theme.secondaryInk,
            letterSpacing: 1.3,
          ),
        ),
      ],
    );
  }
}
