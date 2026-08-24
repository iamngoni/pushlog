import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pushlog/auth/state/auth_cubit.dart';
import 'package:pushlog/core/configs/colors.dart';
import 'package:pushlog/core/configs/motion.dart';
import 'package:pushlog/core/configs/spacing.dart';
import 'package:pushlog/core/configs/typography.dart';
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

class _AppScaffoldState extends State<AppScaffold> with WidgetsBindingObserver {
  PushlogTab selectedTab = PushlogTab.today;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_syncRemoteNotifications());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_syncRemoteNotifications());
    }
  }

  void onTabChanged(PushlogTab tab) {
    if (tab == selectedTab) return;
    AppHaptics.tap();
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
        return previous.preferences.remoteNotificationsEnabled !=
            current.preferences.remoteNotificationsEnabled;
      },
      listener: (_, _) => unawaited(_syncRemoteNotifications()),
      child: Scaffold(
        backgroundColor: theme.background,
        body: AnimatedSwitcher(
          duration: AppMotion.duration(context, AppMotion.fast),
          switchInCurve: AppMotion.enter,
          switchOutCurve: AppMotion.exit,
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
      PushlogTab.today => TodayPage(onTabChanged: onTabChanged),
      PushlogTab.history => const HistoryPage(),
      PushlogTab.friends => FriendsPage(onTabChanged: onTabChanged),
      PushlogTab.settings => const SettingsPage(),
    };
  }

  Future<void> _syncRemoteNotifications() async {
    final authState = context.read<AuthCubit>().state;
    final workoutState = context.read<WorkoutBloc>().state;
    if (authState is! AuthAuthenticated || workoutState is! WorkoutLoaded) {
      return;
    }
    await getIt<CompetitionNotificationService>().syncForUser(
      uid: authState.profile.uid,
      enabled: workoutState.preferences.remoteNotificationsEnabled,
      requestPermission: true,
    );
  }
}

/// The four destinations.
///
/// Every glyph comes from the rounded family. The bar used to mix rounded
/// and outlined icons, which is invisible in isolation and obvious in a row
/// of four: the stroke weights and corner treatments do not match.
///
/// Selection is carried three ways — ink level, text weight, and the accent
/// rule underneath — so it survives both colour blindness and a greyscale
/// screenshot.
class PushlogNavigationBar extends StatelessWidget {
  const PushlogNavigationBar({
    required this.selectedTab,
    required this.onTabChanged,
    super.key,
  });

  final PushlogTab selectedTab;
  final ValueChanged<PushlogTab> onTabChanged;

  static const List<({PushlogTab tab, IconData icon, String label})>
  _destinations = [
    (tab: PushlogTab.today, icon: Icons.today_rounded, label: 'Today'),
    (tab: PushlogTab.history, icon: Icons.bar_chart_rounded, label: 'History'),
    (tab: PushlogTab.friends, icon: Icons.groups_rounded, label: 'Friends'),
    (tab: PushlogTab.settings, icon: Icons.person_rounded, label: 'You'),
  ];

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
          height: 64,
          child: Row(
            children: [
              for (final destination in _destinations)
                _NavItem(
                  theme: theme,
                  icon: destination.icon,
                  label: destination.label,
                  selected: selectedTab == destination.tab,
                  onTap: () => onTabChanged(destination.tab),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.theme,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final AppTheme theme;
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Solid glyphs cover more pixels than the caption beneath them, so an
    // unselected icon is softened a step past the unselected text rather
    // than matching it — otherwise the icons alone read as a second row of
    // emphasis competing with the selected destination.
    final iconColor = selected ? theme.ink : theme.tertiaryInk;
    final textColor = selected ? theme.ink : theme.secondaryInk;

    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        label: label,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: selected ? 1 : 0.94,
                duration: AppMotion.duration(context, AppMotion.fast),
                curve: AppMotion.settle,
                child: Icon(icon, size: 23, color: iconColor),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                label,
                style: AppTypography.labelSmall(
                  color: textColor,
                  weight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              AnimatedContainer(
                duration: AppMotion.duration(context, AppMotion.fast),
                curve: AppMotion.settle,
                width: selected ? 16 : 0,
                height: 3,
                decoration: BoxDecoration(
                  color: theme.accent,
                  borderRadius: AppRadius.all(AppRadius.indicator),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
