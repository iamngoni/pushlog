//
//  pushlog
//  settings_page.dart
//
//  Created by Ngonidzashe Mangudya on 2026/04/16.
//  Copyright (c) 2026 Codecraft Solutions. All rights reserved.
//

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pushlog/auth/state/auth_cubit.dart';
import 'package:pushlog/core/configs/colors.dart';
import 'package:pushlog/core/configs/typography.dart';
import 'package:pushlog/core/services/reminder_service.dart';
import 'package:pushlog/core/views/widgets/app_scaffold.dart';
import 'package:pushlog/core/views/widgets/tap_surface.dart';
import 'package:pushlog/injection.dart';
import 'package:pushlog/platform/health/health_service.dart';
import 'package:pushlog/workout/models/data/workout_preferences.dart';
import 'package:pushlog/workout/models/repos/abs/workout_repository.dart';
import 'package:pushlog/workout/state/workout/workout_bloc.dart';
import 'package:share_plus/share_plus.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    required this.selectedTab,
    required this.onTabChanged,
    super.key,
  });

  final PushlogTab selectedTab;
  final void Function(PushlogTab) onTabChanged;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  HealthAuthorizationStatus _healthStatus =
      HealthAuthorizationStatus.unavailable;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshHealthStatus());
  }

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
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            buildAccountSection(
                              context,
                              theme,
                            ),
                            const SizedBox(height: 32),
                            buildSyncSection(
                              context,
                              theme,
                              state,
                            ),
                            const SizedBox(height: 32),
                            buildRemindersSection(
                              context,
                              theme,
                              state.preferences,
                            ),
                            const SizedBox(height: 32),
                            buildHealthSection(
                              context,
                              theme,
                              state.preferences,
                            ),
                            const SizedBox(height: 32),
                            buildDataSection(
                              context,
                              theme,
                            ),
                            const SizedBox(height: 48),
                          ],
                        ),
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
          'SETTINGS',
          style: AppTypography.labelMono(
            color: theme.secondaryInk,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  Widget buildSectionLabel(
    String title,
    AppTheme theme,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: AppTypography.labelMono(
          color: theme.secondaryInk,
          letterSpacing: 2,
        ),
      ),
    );
  }

  Widget buildAccountSection(
    BuildContext context,
    AppTheme theme,
  ) {
    final authState = context.watch<AuthCubit>().state;
    final profile = authState is AuthAuthenticated ? authState.profile : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildSectionLabel('ACCOUNT', theme),
        buildSettingsCard(
          theme,
          children: [
            buildInfoRow(
              title: 'USERNAME',
              detail: profile?.username?.toUpperCase() ?? 'UNSET',
              theme: theme,
            ),
            buildDivider(theme),
            buildInfoRow(
              title: 'SIGNED IN',
              detail: profile?.email?.toUpperCase() ?? 'UNKNOWN',
              theme: theme,
            ),
            buildDivider(theme),
            buildActionRow(
              title: 'SIGN OUT',
              detail: 'DISCONNECT THIS DEVICE',
              theme: theme,
              onTap: () => context.read<AuthCubit>().signOut(),
            ),
            buildDivider(theme),
            buildActionRow(
              title: 'DELETE ACCOUNT',
              detail: 'REMOVE PROFILE + SIGN-IN',
              accent: true,
              theme: theme,
              onTap: () => showDialog<void>(
                context: context,
                builder: (_) => buildDeleteAccountDialog(
                  context,
                  theme,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget buildSyncSection(
    BuildContext context,
    AppTheme theme,
    WorkoutLoaded state,
  ) {
    final syncedAt = state.lastSyncedAt;
    final syncLabel = syncedAt == null
        ? 'WAITING'
        : formatSettingsDate(syncedAt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildSectionLabel('SYNC', theme),
        buildSettingsCard(
          theme,
          children: [
            buildInfoRow(
              title: 'CLOUD BACKUP',
              detail: 'AUTOMATIC',
              theme: theme,
            ),
            buildDivider(theme),
            buildInfoRow(
              title: 'LAST SYNC',
              detail: syncLabel,
              theme: theme,
            ),
            if (state.syncError != null && state.syncError!.isNotEmpty) ...[
              buildDivider(theme),
              buildInfoRow(
                title: 'SYNC ISSUE',
                detail: state.syncError!.toUpperCase(),
                theme: theme,
                accent: true,
              ),
            ],
            buildDivider(theme),
            buildActionRow(
              title: state.isSyncing ? 'SYNCING...' : 'SYNC NOW',
              detail: 'SAVE LATEST CLOUD COPY',
              theme: theme,
              onTap: state.isSyncing
                  ? () {}
                  : () => context.read<WorkoutBloc>().add(
                      const SyncWorkoutDataEvent(),
                    ),
            ),
          ],
        ),
      ],
    );
  }

  Widget buildRemindersSection(
    BuildContext context,
    AppTheme theme,
    WorkoutPreferences prefs,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildSectionLabel('REMINDERS', theme),
        buildSettingsCard(
          theme,
          children: [
            buildToggleRow(
              title: 'DAILY REMINDER',
              detail: prefs.remindersEnabled ? 'ENABLED' : 'DISABLED',
              isOn: prefs.remindersEnabled,
              theme: theme,
              onChanged: (value) async {
                if (value) {
                  final granted = await getIt<ReminderService>()
                      .requestPermissions();
                  if (!granted && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: theme.surface,
                        content: Text(
                          'ALLOW NOTIFICATIONS TO ENABLE DAILY REMINDERS.',
                          style: AppTypography.labelMono(
                            color: theme.ink,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                    );
                    return;
                  }
                }
                if (!context.mounted) return;
                final updated = prefs.copyWith(
                  remindersEnabled: value,
                );
                context.read<WorkoutBloc>().add(
                  UpdatePreferencesEvent(updated),
                );
              },
            ),
            if (prefs.remindersEnabled) ...[
              buildDivider(theme),
              buildTimePickerRow(
                context,
                theme,
                prefs,
              ),
              buildDivider(theme),
              buildToggleRow(
                title: 'SMART COPY',
                detail: prefs.smartReminderCopyEnabled
                    ? 'ROTATES CREATIVE MESSAGES'
                    : 'USES A STANDARD REMINDER',
                isOn: prefs.smartReminderCopyEnabled,
                theme: theme,
                onChanged: (value) {
                  final updated = prefs.copyWith(
                    smartReminderCopyEnabled: value,
                  );
                  context.read<WorkoutBloc>().add(
                    UpdatePreferencesEvent(updated),
                  );
                },
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget buildHealthSection(
    BuildContext context,
    AppTheme theme,
    WorkoutPreferences prefs,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildSectionLabel('HEALTH', theme),
        buildSettingsCard(
          theme,
          children: [
            buildToggleRow(
              title: 'HEALTHKIT SYNC',
              detail: healthDetail(prefs),
              isOn: prefs.healthSyncEnabled,
              theme: theme,
              onChanged: (value) async {
                if (value) {
                  final granted = await getIt<HealthService>()
                      .requestAuthorization();
                  await _refreshHealthStatus();
                  if (!granted) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: theme.surface,
                        content: Text(
                          'HEALTHKIT IS NOT AVAILABLE OR NOT AUTHORIZED.',
                          style: AppTypography.labelMono(
                            color: theme.ink,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                    );
                    return;
                  }
                }
                if (!context.mounted) return;
                final updated = prefs.copyWith(
                  healthSyncEnabled: value,
                );
                context.read<WorkoutBloc>().add(
                  UpdatePreferencesEvent(updated),
                );
              },
            ),
            buildDivider(theme),
            buildInfoRow(
              title: 'LIVE SESSION EXPORT',
              detail: 'SAVES AS FUNCTIONAL STRENGTH',
              theme: theme,
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _refreshHealthStatus() async {
    final status = await getIt<HealthService>().authorizationStatus();
    if (!mounted) return;
    setState(() => _healthStatus = status);
  }

  String healthDetail(WorkoutPreferences prefs) {
    return switch (_healthStatus) {
      HealthAuthorizationStatus.authorized =>
        prefs.healthSyncEnabled ? 'AUTHORIZED' : 'AVAILABLE',
      HealthAuthorizationStatus.notDetermined => 'NOT ASKED',
      HealthAuthorizationStatus.denied => 'DENIED',
      HealthAuthorizationStatus.unavailable => 'UNAVAILABLE',
    };
  }

  Widget buildDataSection(
    BuildContext context,
    AppTheme theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildSectionLabel('DATA', theme),
        buildSettingsCard(
          theme,
          children: [
            buildActionRow(
              title: 'EXPORT JSON',
              detail: 'SHARE YOUR PUSHLOG DATA',
              theme: theme,
              onTap: exportData,
            ),
            buildDivider(theme),
            buildActionRow(
              title: 'RESET APP DATA',
              detail: 'CLEAR LOCAL HISTORY + PREFS',
              accent: true,
              theme: theme,
              onTap: () => showDialog<void>(
                context: context,
                builder: (_) => buildResetDialog(
                  context,
                  theme,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget buildDeleteAccountDialog(
    BuildContext context,
    AppTheme theme,
  ) {
    return AlertDialog(
      backgroundColor: theme.background,
      title: Text(
        'DELETE ACCOUNT?',
        style: AppTypography.labelMono(
          size: 13,
          color: theme.ink,
          weight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
      content: Text(
        'THIS REMOVES YOUR PROFILE, USERNAME, FRIENDS, REQUESTS, '
        'AND CLOUD BACKUP.',
        style: AppTypography.labelMono(
          color: theme.secondaryInk,
          letterSpacing: 0.8,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'CANCEL',
            style: AppTypography.labelMono(
              color: theme.secondaryInk,
            ),
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            unawaited(deleteAccount(context, theme));
          },
          child: Text(
            'DELETE',
            style: AppTypography.labelMono(
              color: theme.accentInk,
              weight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget buildResetDialog(
    BuildContext context,
    AppTheme theme,
  ) {
    return AlertDialog(
      backgroundColor: theme.background,
      title: Text(
        'RESET PUSHLOG?',
        style: AppTypography.labelMono(
          size: 13,
          color: theme.ink,
          weight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      ),
      content: Text(
        'THIS CLEARS HISTORY, LIVE LOGS, AND PREFERENCES.',
        style: AppTypography.labelMono(
          color: theme.secondaryInk,
          letterSpacing: 0.8,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'CANCEL',
            style: AppTypography.labelMono(
              color: theme.secondaryInk,
            ),
          ),
        ),
        TextButton(
          onPressed: () {
            context.read<WorkoutBloc>().add(
              const ResetWorkoutDataEvent(),
            );
            Navigator.of(context).pop();
          },
          child: Text(
            'RESET',
            style: AppTypography.labelMono(
              color: theme.accentInk,
            ),
          ),
        ),
      ],
    );
  }

  Widget buildTimePickerRow(
    BuildContext context,
    AppTheme theme,
    WorkoutPreferences prefs,
  ) {
    final time = TimeOfDay(
      hour: prefs.reminderHour,
      minute: prefs.reminderMinute,
    );
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return TapSurface(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: time,
        );
        if (picked != null && context.mounted) {
          final updated = prefs.copyWith(
            reminderHour: picked.hour,
            reminderMinute: picked.minute,
          );
          context.read<WorkoutBloc>().add(
            UpdatePreferencesEvent(updated),
          );
        }
      },
      child: buildInfoRow(
        title: 'REMINDER TIME',
        detail: '$h:$m',
        theme: theme,
      ),
    );
  }

  Widget buildSettingsCard(
    AppTheme theme, {
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: theme.surface,
        border: Border.all(color: theme.divider),
      ),
      child: Column(children: children),
    );
  }

  Widget buildInfoRow({
    required String title,
    required String detail,
    required AppTheme theme,
    bool accent = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 18,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.labelMono(
              color: accent ? theme.accentInk : theme.ink,
              letterSpacing: 1.8,
            ),
          ),
          const Spacer(),
          Text(
            detail,
            style: AppTypography.labelMono(
              color: accent ? theme.accentInk : theme.secondaryInk,
              letterSpacing: 1.2,
            ),
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }

  Widget buildActionRow({
    required String title,
    required String detail,
    required AppTheme theme,
    required VoidCallback onTap,
    bool accent = false,
  }) {
    return TapSurface(
      onTap: onTap,
      child: buildInfoRow(
        title: title,
        detail: detail,
        theme: theme,
        accent: accent,
      ),
    );
  }

  Widget buildToggleRow({
    required String title,
    required String detail,
    required bool isOn,
    required AppTheme theme,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 18,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.labelMono(
                    color: theme.ink,
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  detail,
                  style: AppTypography.labelMono(
                    color: theme.secondaryInk,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: isOn,
            onChanged: onChanged,
            activeThumbColor: theme.accent,
            activeTrackColor: theme.accent.withAlpha(80),
          ),
        ],
      ),
    );
  }

  Widget buildDivider(AppTheme theme) {
    return Divider(height: 1, color: theme.divider);
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
      child: TapSurface(
        onTap: () => widget.onTabChanged(tab),
        selected: isSelected,
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

  Future<void> exportData() async {
    final repo = getIt<WorkoutRepository>();
    final exportResult = await repo.exportJson();
    final json = exportResult.getOrElse(() => '');
    if (json.isEmpty || !mounted) return;

    await SharePlus.instance.share(
      ShareParams(
        text: json,
        subject: 'pushlog-export.json',
      ),
    );
  }

  Future<void> deleteAccount(
    BuildContext context,
    AppTheme theme,
  ) async {
    final authCubit = context.read<AuthCubit>();
    final workoutBloc = context.read<WorkoutBloc>();
    try {
      await authCubit.deleteAccount();
      if (!context.mounted) return;
      workoutBloc.add(const ResetWorkoutDataEvent());
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: theme.surface,
          content: Text(
            accountDeletionMessage(error).toUpperCase(),
            style: AppTypography.labelMono(
              color: theme.ink,
              letterSpacing: 0.8,
            ),
          ),
        ),
      );
    }
  }

  String accountDeletionMessage(Object error) {
    if (error is FirebaseAuthException &&
        error.code == 'requires-recent-login') {
      return 'Sign in again before deleting this account.';
    }
    if (error is FirebaseException && error.code == 'permission-denied') {
      return 'Could not delete the account yet. Try again shortly.';
    }
    return 'Could not delete the account right now.';
  }

  String formatSettingsDate(DateTime date) {
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
    final day = days[date.weekday - 1];
    final month = months[date.month - 1];
    final dd = date.day.toString().padLeft(2, '0');
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    return '$day $dd $month · $hh:$mm';
  }
}
