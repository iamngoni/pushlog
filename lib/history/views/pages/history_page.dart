//
//  pushlog
//  history_page.dart
//
//  Created by Ngonidzashe Mangudya on 2026/04/16.
//  Copyright (c) 2026 Codecraft Solutions. All rights reserved.
//

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:pushlog/core/configs/colors.dart';
import 'package:pushlog/core/configs/spacing.dart';
import 'package:pushlog/core/configs/typography.dart';
import 'package:pushlog/core/views/widgets/empty_state.dart';
import 'package:pushlog/history/views/widgets/history_entry_row.dart';
import 'package:pushlog/today/views/widgets/stats_block.dart';
import 'package:pushlog/workout/models/data/history_entry.dart';
import 'package:pushlog/workout/models/data/workout_session.dart';
import 'package:pushlog/workout/state/workout/workout_bloc.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return BlocBuilder<WorkoutBloc, WorkoutState>(
      builder: (context, state) {
        if (state is WorkoutLoaded) {
          return buildLoaded(context, theme, state);
        }
        return buildLoading(theme);
      },
    );
  }

  Widget buildLoaded(
    BuildContext context,
    AppTheme theme,
    WorkoutLoaded state,
  ) {
    final isEmpty = state.historyEntries.isEmpty;

    return ColoredBox(
      color: theme.background,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.gutter,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.xxl),
              buildHeader(theme),
              const SizedBox(height: AppSpacing.block),
              // The month summary is hidden until there is a month to
              // summarise. A row of zeroes above an empty list makes a
              // fresh install look like a failed load rather than a
              // feature the user has not started yet.
              if (!isEmpty) ...[
                buildMonthBlock(theme, state),
                const SizedBox(height: AppSpacing.block),
                Divider(height: 1, color: theme.divider),
                const SizedBox(height: AppSpacing.xxl),
              ],
              Expanded(child: buildHistoryBody(context, theme, state)),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildHeader(AppTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PUSHLOG',
          style: AppTypography.overline(color: theme.tertiaryInk),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'History',
          style: AppTypography.headingLarge(color: theme.ink),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          DateFormat('MMMM yyyy').format(DateTime.now()),
          style: AppTypography.bodyLarge(color: theme.secondaryInk),
        ),
      ],
    );
  }

  Widget buildMonthBlock(
    AppTheme theme,
    WorkoutLoaded state,
  ) {
    final monthTotal = computeMonthTotal(state);
    final monthBest = computeMonthBest(state);
    final monthAvg = computeMonthAvg(state);
    final liveSessions = computeLiveSessions(state);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            '$monthTotal',
            style: AppTypography.metricXLarge(color: theme.ink),
          ),
        ),
        Text(
          'reps logged this month',
          style: AppTypography.body(color: theme.secondaryInk),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: StatColumn(
                value: '$monthBest',
                label: 'BEST',
                theme: theme,
              ),
            ),
            Expanded(
              child: StatColumn(
                value: '$monthAvg',
                label: 'AVG',
                theme: theme,
              ),
            ),
            Expanded(
              child: StatColumn(
                value: '$liveSessions',
                label: 'LIVE',
                theme: theme,
              ),
            ),
          ],
        ),
      ],
    );
  }

  int computeMonthTotal(WorkoutLoaded state) {
    final now = DateTime.now();
    return state.dayTotals.entries
        .where((e) {
          final d = parseDate(e.key);
          return d != null && d.year == now.year && d.month == now.month;
        })
        .fold(0, (sum, e) => sum + e.value);
  }

  int computeMonthBest(WorkoutLoaded state) {
    final now = DateTime.now();
    final values = state.dayTotals.entries
        .where((e) {
          final d = parseDate(e.key);
          return d != null && d.year == now.year && d.month == now.month;
        })
        .map((e) => e.value)
        .toList();
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a > b ? a : b);
  }

  int computeMonthAvg(WorkoutLoaded state) {
    final now = DateTime.now();
    final values = state.dayTotals.entries
        .where((e) {
          final d = parseDate(e.key);
          return d != null && d.year == now.year && d.month == now.month;
        })
        .map((e) => e.value)
        .toList();
    if (values.isEmpty) return 0;
    final total = values.fold(0, (sum, v) => sum + v);
    return (total / values.length).round();
  }

  int computeLiveSessions(WorkoutLoaded state) {
    final now = DateTime.now();
    return state.sessions
        .where(
          (s) =>
              s.source == WorkoutSource.live &&
              s.date.year == now.year &&
              s.date.month == now.month,
        )
        .length;
  }

  Widget buildHistoryBody(
    BuildContext context,
    AppTheme theme,
    WorkoutLoaded state,
  ) {
    if (state.historyEntries.isEmpty) {
      return buildEmptyState(theme);
    }
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: state.historyEntries.length,
      itemBuilder: (context, index) {
        final entry = state.historyEntries[index];
        return HistoryEntryRow(
          entry: entry,
          theme: theme,
          onTap: () => showDayDetailSheet(
            context,
            theme,
            entry,
          ),
        );
      },
    );
  }

  Future<void> showDayDetailSheet(
    BuildContext context,
    AppTheme theme,
    HistoryEntry entry,
  ) {
    // Matches the friend sheet: rounded top, drag handle, safe area. Two
    // sheets in one app should not disagree about what a sheet looks like.
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.background,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.top(AppRadius.xxl),
      ),
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => DayDetailSheet(entry: entry, theme: theme),
    );
  }

  Widget buildEmptyState(AppTheme theme) {
    return const EmptyState(
      icon: Icons.history_rounded,
      title: 'Your log starts today',
      message:
          'Every set you record shows up here — day by day, with your '
          'best days and live sessions called out. Log a set from the '
          'Today tab and this fills in.',
    );
  }

  Widget buildLoading(AppTheme theme) {
    return ColoredBox(
      color: theme.background,
      child: Center(
        child: CircularProgressIndicator(
          color: theme.accent,
        ),
      ),
    );
  }

  static DateTime? parseDate(String key) {
    try {
      return DateTime.parse(key);
    } on FormatException {
      return null;
    }
  }
}

class DayDetailSheet extends StatelessWidget {
  const DayDetailSheet({
    required this.entry,
    required this.theme,
    super.key,
  });

  final HistoryEntry entry;
  final AppTheme theme;

  String rowTitle(DateTime date) {
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
    if (isToday) return 'TODAY';

    const days = [
      'MON',
      'TUE',
      'WED',
      'THU',
      'FRI',
      'SAT',
      'SUN',
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
    final d = date.day.toString().padLeft(2, '0');
    return '$dow $d $mon';
  }

  @override
  Widget build(BuildContext context) {
    // `showModalBottomSheet` gives its child loose horizontal constraints.
    // Without an explicit width this compact content shrink-wraps into the
    // narrow pill seen on iPhone instead of using the sheet's available width.
    return SizedBox(
      width: double.infinity,
      child: DraggableScrollableSheet(
        minChildSize: 0.4,
        maxChildSize: 0.6,
        expand: false,
        builder: (_, scrollController) => ColoredBox(
          color: theme.background,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 28,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                Text(
                  rowTitle(entry.date),
                  style: AppTypography.overline(color: theme.tertiaryInk),
                ),
                const SizedBox(height: AppSpacing.xs),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${entry.count}',
                    style: AppTypography.metricXLarge(color: theme.ink),
                  ),
                ),
                Text(
                  'REPS',
                  style: AppTypography.overline(color: theme.tertiaryInk),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
