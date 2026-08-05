import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pushlog/auth/state/auth_cubit.dart';
import 'package:pushlog/core/configs/colors.dart';
import 'package:pushlog/core/services/competition_notification_service.dart';
import 'package:pushlog/friends/views/pages/friends_page.dart';
import 'package:pushlog/history/views/pages/history_page.dart';
import 'package:pushlog/injection.dart';
import 'package:pushlog/settings/views/pages/settings_page.dart';
import 'package:pushlog/today/views/pages/today_page.dart';
import 'package:pushlog/workout/state/workout/workout_bloc.dart';

enum PushlogTab { today, history, friends, settings }

class AppScaffold extends StatefulWidget {
  const AppScaffold({super.key});

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  PushlogTab selectedTab = PushlogTab.today;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_syncCompetitionNotifications());
    });
  }

  void onTabChanged(PushlogTab tab) {
    setState(() => selectedTab = tab);
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return BlocListener<WorkoutBloc, WorkoutState>(
      listenWhen: (previous, current) {
        if (previous is! WorkoutLoaded || current is! WorkoutLoaded) {
          return current is WorkoutLoaded;
        }
        return previous.preferences.competitionNotificationsEnabled !=
            current.preferences.competitionNotificationsEnabled;
      },
      listener: (_, _) => unawaited(_syncCompetitionNotifications()),
      child: Scaffold(
        backgroundColor: theme.background,
        body: AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOutQuart,
          switchOutCurve: Curves.easeOutQuart,
          child: KeyedSubtree(
            key: ValueKey(selectedTab),
            child: _buildBody(),
          ),
        ),
        bottomNavigationBar: PushlogNavigationBar(
          selectedTab: selectedTab,
          onTabChanged: onTabChanged,
        ),
      ),
    );
  }

  Widget _buildBody() {
    return switch (selectedTab) {
      PushlogTab.today => TodayPage(
        selectedTab: selectedTab,
        onTabChanged: onTabChanged,
      ),
      PushlogTab.history => HistoryPage(
        selectedTab: selectedTab,
        onTabChanged: onTabChanged,
      ),
      PushlogTab.friends => FriendsPage(
        onTabChanged: onTabChanged,
      ),
      PushlogTab.settings => SettingsPage(
        selectedTab: selectedTab,
        onTabChanged: onTabChanged,
      ),
    };
  }

  Future<void> _syncCompetitionNotifications() async {
    final authState = context.read<AuthCubit>().state;
    final workoutState = context.read<WorkoutBloc>().state;
    if (authState is! AuthAuthenticated || workoutState is! WorkoutLoaded) {
      return;
    }
    await getIt<CompetitionNotificationService>().syncForUser(
      uid: authState.profile.uid,
      enabled: workoutState.preferences.competitionNotificationsEnabled,
      requestPermission: true,
    );
  }
}

class PushlogNavigationBar extends StatelessWidget {
  const PushlogNavigationBar({
    required this.selectedTab,
    required this.onTabChanged,
    super.key,
  });

  final PushlogTab selectedTab;
  final ValueChanged<PushlogTab> onTabChanged;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.background,
        border: Border(top: BorderSide(color: theme.divider)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            children: [
              _item(theme, PushlogTab.today, Icons.today_outlined, 'Today'),
              _item(
                theme,
                PushlogTab.history,
                Icons.bar_chart_rounded,
                'History',
              ),
              _item(
                theme,
                PushlogTab.friends,
                Icons.people_outline_rounded,
                'Friends',
              ),
              _item(
                theme,
                PushlogTab.settings,
                Icons.person_outline_rounded,
                'You',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(
    AppTheme theme,
    PushlogTab tab,
    IconData icon,
    String label,
  ) {
    final selected = selectedTab == tab;
    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        label: label,
        child: InkWell(
          onTap: () => onTabChanged(tab),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 24,
                color: selected ? theme.ink : theme.secondaryInk,
              ),
              const SizedBox(height: 5),
              Text(
                label,
                style: TextStyle(
                  color: selected ? theme.ink : theme.secondaryInk,
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  height: 1,
                ),
              ),
              const SizedBox(height: 5),
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: selected ? 18 : 0,
                height: 3,
                decoration: BoxDecoration(
                  color: theme.accent,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
