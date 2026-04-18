//
//  pushlog
//  history_entry_row.dart
//
//  Created by Ngonidzashe Mangudya on 2026/04/16.
//  Copyright (c) 2026 Codecraft Solutions. All rights reserved.
//

import 'package:flutter/material.dart';
import 'package:pushlog/core/configs/colors.dart';
import 'package:pushlog/core/configs/typography.dart';
import 'package:pushlog/workout/models/data/history_entry.dart';

class HistoryEntryRow extends StatelessWidget {
  const HistoryEntryRow({
    required this.entry,
    required this.theme,
    required this.onTap,
    super.key,
  });

  final HistoryEntry entry;
  final AppTheme theme;
  final VoidCallback onTap;

  String rowTitle(DateTime date) {
    final now = DateTime.now();
    final isToday = date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
    if (isToday) return 'TODAY';

    const days = [
      'MON', 'TUE', 'WED', 'THU',
      'FRI', 'SAT', 'SUN',
    ];
    const months = [
      'JAN', 'FEB', 'MAR', 'APR',
      'MAY', 'JUN', 'JUL', 'AUG',
      'SEP', 'OCT', 'NOV', 'DEC',
    ];
    final dow = days[date.weekday - 1];
    final mon = months[date.month - 1];
    final d = date.day.toString().padLeft(2, '0');
    return '$dow $d $mon';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 14,
            ),
            child: Text(
              rowTitle(entry.date),
              style: AppTypography.labelMono(
                size: 11,
                color: entry.isToday
                    ? theme.accentInk
                    : theme.secondaryInk,
                letterSpacing: 1.6,
              ),
            ),
          ),
          Divider(height: 1, color: theme.divider),
        ],
      ),
    );
  }
}
