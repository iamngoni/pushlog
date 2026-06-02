//
//  pushlog
//  history_page.dart
//
//  Created by Ngonidzashe Mangudya on 2026/04/16.
//  Copyright (c) 2026 Codecraft Solutions. All rights reserved.
//

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pushlog/core/configs/colors.dart';
import 'package:pushlog/core/configs/typography.dart';
import 'package:pushlog/core/views/widgets/app_scaffold.dart';
import 'package:pushlog/history/views/widgets/history_entry_row.dart';
import 'package:pushlog/today/views/widgets/stats_block.dart';
import 'package:pushlog/workout/models/data/history_entry.dart';
import 'package:pushlog/workout/models/data/workout_session.dart';
import 'package:pushlog/workout/state/workout/workout_bloc.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({
    required this.selectedTab,
    required this.onTabChanged,
    super.key,
  });

  final PushlogTab selectedTab;
  final void Function(PushlogTab) onTabChanged;

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
    return ColoredBox(
      color: theme.background,
      child: Column(
        children: [
          Expanded(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    buildHeader(theme),
                    const SizedBox(height: 18),
                    buildMonthBlock(theme, state),
                    const SizedBox(height: 18),
                    Divider(
                      height: 1,
                      color: theme.divider,
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: buildHistoryBody(
                        context,
                        theme,
                        state,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          buildBottomTabBar(theme),
        ],
      ),
    );
  }

  Widget buildHeader(AppTheme theme) {
    const months = [
      'JANUARY',
      'FEBRUARY',
      'MARCH',
      'APRIL',
      'MAY',
      'JUNE',
      'JULY',
      'AUGUST',
      'SEPTEMBER',
      'OCTOBER',
      'NOVEMBER',
      'DECEMBER',
    ];
    final now = DateTime.now();
    final label = '${months[now.month - 1]} ${now.year}';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'PUSHLOG',
          style: AppTypography.labelMono(
            color: theme.secondaryInk,
            letterSpacing: 3,
          ),
        ),
        Text(
          label,
          style: AppTypography.labelMono(
            color: theme.secondaryInk,
            letterSpacing: 1.5,
          ),
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
            style: AppTypography.displayMedium(
              color: theme.ink,
            ),
          ),
        ),
        const SizedBox(height: 10),
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
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.background,
      shape: const RoundedRectangleBorder(),
      isScrollControlled: true,
      builder: (_) => DayDetailSheet(entry: entry, theme: theme),
    );
  }

  Widget buildEmptyState(AppTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'NO LOGS YET',
          style: AppTypography.displayCompact(
            color: theme.ink,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'ADD REPS FROM TODAY OR START A LIVE SESSION.',
          style: AppTypography.labelMono(
            color: theme.secondaryInk,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  Widget buildBottomTabBar(AppTheme theme) {
    return SafeArea(
      top: false,
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: theme.background,
          border: Border(
            top: BorderSide(color: theme.divider),
          ),
        ),
        child: Row(
          children: [
            buildTabButton(
              'TODAY',
              PushlogTab.today,
              theme,
            ),
            buildTabButton(
              'HISTORY',
              PushlogTab.history,
              theme,
            ),
            buildTabButton(
              'SETTINGS',
              PushlogTab.settings,
              theme,
            ),
          ],
        ),
      ),
    );
  }

  Widget buildTabButton(
    String title,
    PushlogTab tab,
    AppTheme theme,
  ) {
    final isSelected = widget.selectedTab == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () => widget.onTabChanged(tab),
        child: ColoredBox(
          color: Colors.transparent,
          child: Center(
            child: Text(
              title,
              style: AppTypography.labelMono(
                color: isSelected ? theme.ink : theme.secondaryInk,
                letterSpacing: 2,
              ),
            ),
          ),
        ),
      ),
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
    return DraggableScrollableSheet(
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
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Spacer(),
              Text(
                rowTitle(entry.date),
                style: AppTypography.labelMono(
                  color: theme.secondaryInk,
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${entry.count}',
                  style: AppTypography.displayMedium(
                    color: theme.ink,
                  ),
                ),
              ),
              Text(
                'REPS',
                style: AppTypography.labelMono(
                  color: theme.secondaryInk,
                  letterSpacing: 1.6,
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
