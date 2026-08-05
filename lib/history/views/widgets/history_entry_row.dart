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
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
    if (isToday) return 'Today';

    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    final dow = days[date.weekday - 1];
    final mon = months[date.month - 1];
    final d = date.day.toString();
    return '$dow $d $mon';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: theme.divider)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: entry.isToday ? theme.accent : theme.surface,
                shape: BoxShape.circle,
                border: entry.isToday ? null : Border.all(color: theme.divider),
              ),
              child: Icon(
                entry.isToday
                    ? Icons.bolt_rounded
                    : Icons.calendar_today_outlined,
                size: 19,
                color: entry.isToday ? AppColors.fixedDark : theme.secondaryInk,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rowTitle(entry.date),
                    style: AppTypography.title(color: theme.ink),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _date(entry.date),
                    style: AppTypography.body(color: theme.secondaryInk),
                  ),
                ],
              ),
            ),
            Text(
              '${entry.count}',
              style: AppTypography.headingMedium(color: theme.ink),
            ),
            const SizedBox(width: 6),
            Text('reps', style: AppTypography.body(color: theme.secondaryInk)),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, color: theme.secondaryInk),
          ],
        ),
      ),
    );
  }

  String _date(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
