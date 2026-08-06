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
import 'package:pushlog/core/configs/spacing.dart';
import 'package:pushlog/core/configs/typography.dart';
import 'package:pushlog/core/services/competition_notification_service.dart';
import 'package:pushlog/core/services/reminder_service.dart';
import 'package:pushlog/core/views/widgets/pushlog_button.dart';
import 'package:pushlog/core/views/widgets/pushlog_toast.dart';
import 'package:pushlog/injection.dart';
import 'package:pushlog/platform/health/health_service.dart';
import 'package:pushlog/training/models/training_plan.dart';
import 'package:pushlog/training/views/training_onboarding_page.dart';
import 'package:pushlog/workout/models/data/workout_preferences.dart';
import 'package:pushlog/workout/models/repos/abs/workout_repository.dart';
import 'package:pushlog/workout/state/workout/workout_bloc.dart';
import 'package:share_plus/share_plus.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

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
                  horizontal: AppSpacing.gutter,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.xxl),
                    buildHeader(theme),
                    const SizedBox(height: AppSpacing.block),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            buildAccountSection(
                              context,
                              theme,
                            ),
                            const SizedBox(height: AppSpacing.sectionLarge),
                            buildSyncSection(
                              context,
                              theme,
                              state,
                            ),
                            const SizedBox(height: AppSpacing.sectionLarge),
                            buildTrainingPlanSection(
                              context,
                              theme,
                              state.preferences,
                            ),
                            const SizedBox(height: AppSpacing.sectionLarge),
                            buildRemindersSection(
                              context,
                              theme,
                              state.preferences,
                            ),
                            const SizedBox(height: AppSpacing.sectionLarge),
                            buildHealthSection(
                              context,
                              theme,
                              state.preferences,
                            ),
                            const SizedBox(height: AppSpacing.sectionLarge),
                            buildDataSection(
                              context,
                              theme,
                            ),
                            const SizedBox(height: AppSpacing.hero),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
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
          'You',
          style: AppTypography.headingLarge(color: theme.ink),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Your plan, account, devices, and alerts.',
          style: AppTypography.bodyLarge(color: theme.secondaryInk),
        ),
      ],
    );
  }

  Widget buildSectionLabel(
    String title,
    AppTheme theme,
  ) {
    // A group header, not a page heading. Sized as the label it actually
    // is so it orders the list without competing with the rows inside it.
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.xs,
        bottom: AppSpacing.lg,
      ),
      child: Text(
        title.toUpperCase(),
        style: AppTypography.overline(color: theme.tertiaryInk),
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
        buildSectionLabel('Account', theme),
        buildSettingsCard(
          theme,
          children: [
            buildInfoRow(
              title: 'Username',
              detail: profile?.username == null
                  ? 'Not set'
                  : '@${profile!.username}',
              theme: theme,
            ),
            buildDivider(theme),
            buildInfoRow(
              title: 'Signed in',
              detail: profile?.email ?? 'Unknown',
              theme: theme,
            ),
            buildDivider(theme),
            buildActionRow(
              title: 'Sign out',
              detail: 'Disconnect this device',
              theme: theme,
              onTap: () => unawaited(_signOut(context)),
            ),
            buildDivider(theme),
            buildActionRow(
              title: 'Delete account',
              detail: 'Removes your profile and sign-in',
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
        ? 'Waiting'
        : formatSettingsDate(syncedAt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildSectionLabel('Sync', theme),
        buildSettingsCard(
          theme,
          children: [
            buildInfoRow(
              title: 'Cloud backup',
              detail: 'Automatic',
              theme: theme,
            ),
            buildDivider(theme),
            buildInfoRow(
              title: 'Last sync',
              detail: syncLabel,
              theme: theme,
            ),
            if (state.syncError != null && state.syncError!.isNotEmpty) ...[
              buildDivider(theme),
              buildInfoRow(
                title: 'Sync issue',
                detail: state.syncError!.toUpperCase(),
                theme: theme,
                accent: true,
              ),
            ],
            buildDivider(theme),
            buildActionRow(
              title: state.isSyncing ? 'Syncing…' : 'Sync now',
              detail: 'Save the latest copy to the cloud',
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
        buildSectionLabel('Reminders', theme),
        buildSettingsCard(
          theme,
          children: [
            buildToggleRow(
              title: 'Training reminders',
              detail: prefs.remindersEnabled
                  ? prefs.trainingPlan == null
                        ? 'On'
                        : 'Scheduled days only'
                  : 'Off',
              isOn: prefs.remindersEnabled,
              theme: theme,
              onChanged: (value) async {
                if (value) {
                  final granted = await getIt<ReminderService>()
                      .requestPermissions();
                  if (!granted && context.mounted) {
                    PushlogToast.warning(
                      context,
                      'Reminders need notification access',
                      detail:
                          'Allow notifications for Pushlog in your '
                          'device settings, then switch this back on.',
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
                title: 'Smart copy',
                detail: prefs.smartReminderCopyEnabled
                    ? 'Rotates through varied messages'
                    : 'Uses one standard reminder',
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
            buildDivider(theme),
            buildToggleRow(
              title: 'Friend lead changes',
              detail: prefs.competitionNotificationsEnabled
                  ? 'Alerts both friends when the lead changes'
                  : 'Competition alerts are off',
              isOn: prefs.competitionNotificationsEnabled,
              theme: theme,
              onChanged: (value) async {
                final uid = getIt<FirebaseAuth>().currentUser?.uid;
                if (uid == null) return;
                final granted = await getIt<CompetitionNotificationService>()
                    .syncForUser(
                      uid: uid,
                      enabled: value,
                      requestPermission: value,
                    );
                if (value && !granted) {
                  if (!context.mounted) return;
                  PushlogToast.warning(
                    context,
                    'Friend alerts need notification access',
                    detail:
                        'Allow notifications for Pushlog in your device '
                        'settings to hear when a friend passes you.',
                  );
                  return;
                }
                if (!context.mounted) return;
                context.read<WorkoutBloc>().add(
                  UpdatePreferencesEvent(
                    prefs.copyWith(competitionNotificationsEnabled: value),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget buildTrainingPlanSection(
    BuildContext context,
    AppTheme theme,
    WorkoutPreferences prefs,
  ) {
    final plan = prefs.trainingPlan;
    if (plan == null) return const SizedBox.shrink();
    final profile = plan.profile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildSectionLabel('Training plan', theme),
        buildSettingsCard(
          theme,
          children: [
            buildInfoRow(
              title: 'Goal',
              detail: _goalLabel(profile.goal),
              theme: theme,
            ),
            buildDivider(theme),
            buildInfoRow(
              title: 'Target',
              detail: '${profile.targetMaxReps} CLEAN REPS',
              theme: theme,
            ),
            buildDivider(theme),
            buildInfoRow(
              title: 'Schedule',
              detail: '${profile.sessionsPerWeek} DAYS / WEEK',
              theme: theme,
            ),
            buildDivider(theme),
            buildActionRow(
              title: 'Edit plan',
              detail: 'Goals, schedule, and coaching',
              theme: theme,
              onTap: () {
                final workoutBloc = context.read<WorkoutBloc>();
                unawaited(
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => BlocProvider.value(
                        value: workoutBloc,
                        child: TrainingOnboardingPage(
                          preferences: prefs,
                          isEditing: true,
                        ),
                      ),
                      fullscreenDialog: true,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  String _goalLabel(TrainingGoal goal) {
    return switch (goal) {
      TrainingGoal.buildHabit => 'Build a habit',
      TrainingGoal.increaseMaximum => 'Increase max',
      TrainingGoal.improveEndurance => 'Endurance',
      TrainingGoal.maintainAbility => 'Maintain',
      TrainingGoal.custom => 'Custom target',
    };
  }

  Widget buildHealthSection(
    BuildContext context,
    AppTheme theme,
    WorkoutPreferences prefs,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildSectionLabel('Health', theme),
        buildSettingsCard(
          theme,
          children: [
            buildToggleRow(
              title: 'HealthKit sync',
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
                    PushlogToast.warning(
                      context,
                      'Health sync is unavailable',
                      detail:
                          'Grant Pushlog access to Health, or keep '
                          'logging sets by hand — nothing is lost either way.',
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
              title: 'Live session export',
              detail: 'Saves as functional strength training',
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
        prefs.healthSyncEnabled ? 'Authorized' : 'Available',
      HealthAuthorizationStatus.notDetermined => 'Not asked',
      HealthAuthorizationStatus.denied => 'Denied',
      HealthAuthorizationStatus.unavailable => 'Unavailable',
    };
  }

  Widget buildDataSection(
    BuildContext context,
    AppTheme theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildSectionLabel('Data', theme),
        buildSettingsCard(
          theme,
          children: [
            buildActionRow(
              title: 'Export JSON',
              detail: 'Share a copy of your Pushlog data',
              theme: theme,
              onTap: exportData,
            ),
            buildDivider(theme),
            buildActionRow(
              title: 'Reset app data',
              detail: 'Clears local history and preferences',
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
    return _ConfirmDialog(
      theme: theme,
      title: 'Delete your account?',
      message:
          'This removes your profile, username, friends, requests, '
          'and cloud backup. It cannot be undone.',
      confirmLabel: 'Delete account',
      onConfirm: () {
        Navigator.of(context).pop();
        unawaited(deleteAccount(context, theme));
      },
    );
  }

  Widget buildResetDialog(
    BuildContext context,
    AppTheme theme,
  ) {
    return _ConfirmDialog(
      theme: theme,
      title: 'Reset Pushlog?',
      message:
          'This clears your history, live logs, and preferences on '
          'this device.',
      confirmLabel: 'Reset data',
      onConfirm: () {
        context.read<WorkoutBloc>().add(const ResetWorkoutDataEvent());
        Navigator.of(context).pop();
      },
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
    return GestureDetector(
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
        title: 'Reminder time',
        detail: '$h:$m',
        theme: theme,
      ),
    );
  }

  Widget buildSettingsCard(
    AppTheme theme, {
    required List<Widget> children,
  }) {
    // No border. The card already sits a tonal step off the page, and
    // saying the same thing twice is what makes settings look like a stack
    // of boxes rather than grouped content.
    return Container(
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: AppRadius.all(AppRadius.xl),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  /// A label and its value.
  ///
  /// Values are baseline-aligned with their labels rather than centred,
  /// and the label is the quieter of the two — in a settings list the user
  /// is scanning for the current setting, not re-reading its name.
  Widget buildInfoRow({
    required String title,
    required String detail,
    required AppTheme theme,
    bool accent = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xl,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            title,
            style: AppTypography.body(color: theme.secondaryInk),
          ),
          const SizedBox(width: AppSpacing.xl),
          Expanded(
            child: Text(
              detail,
              textAlign: TextAlign.right,
              style: AppTypography.body(
                color: accent ? theme.accentInk : theme.ink,
                weight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// A row that goes somewhere or does something.
  ///
  /// Destructive rows are not styled as big red buttons here — deleting an
  /// account is not the primary action on this screen. The emphasis moves
  /// to the confirmation dialog, where it *is* the primary action.
  Widget buildActionRow({
    required String title,
    required String detail,
    required AppTheme theme,
    required VoidCallback onTap,
    bool accent = false,
  }) {
    return PressFeedback(
      onTap: onTap,
      scale: 0.99,
      semanticLabel: '$title. $detail',
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.xl,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.body(
                      color: accent ? theme.danger : theme.ink,
                      weight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    detail,
                    style: AppTypography.bodySmall(
                      color: theme.secondaryInk,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: theme.tertiaryInk,
            ),
          ],
        ),
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
    return Semantics(
      toggled: isOn,
      label: title,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.body(
                      color: theme.ink,
                      weight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    detail,
                    style: AppTypography.bodySmall(
                      color: theme.secondaryInk,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Switch(
              value: isOn,
              onChanged: onChanged,
              activeThumbColor: theme.onAccent,
              activeTrackColor: theme.accent,
              inactiveTrackColor: theme.surfaceSunken,
              inactiveThumbColor: theme.tertiaryInk,
              trackOutlineColor: WidgetStatePropertyAll(theme.divider),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildDivider(AppTheme theme) {
    return Divider(height: 1, indent: AppSpacing.xl, color: theme.dividerSoft);
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

  Future<void> _signOut(BuildContext context) async {
    final authCubit = context.read<AuthCubit>();
    final uid = getIt<FirebaseAuth>().currentUser?.uid;
    if (uid != null) {
      await getIt<CompetitionNotificationService>().syncForUser(
        uid: uid,
        enabled: false,
      );
    }
    await authCubit.signOut();
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
      PushlogToast.danger(
        context,
        'Could not delete your account',
        detail: accountDeletionMessage(error),
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

/// A confirmation for something that cannot be undone.
///
/// The destructive action is quiet on the settings row that offers it and
/// loud here, where the user has been told exactly what it does. Reversing
/// that — a big red button on the list itself — pressures the decision at
/// the point where the least context is available.
class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({
    required this.theme,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.onConfirm,
  });

  final AppTheme theme;
  final String title;
  final String message;
  final String confirmLabel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: theme.surfaceRaised,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.all(AppRadius.xl),
      ),
      titlePadding: const EdgeInsets.fromLTRB(
        AppSpacing.block,
        AppSpacing.block,
        AppSpacing.block,
        AppSpacing.lg,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.block,
      ),
      actionsPadding: const EdgeInsets.all(AppSpacing.block),
      title: Text(
        title,
        style: AppTypography.headingSmall(color: theme.ink),
      ),
      content: Text(
        message,
        style: AppTypography.body(color: theme.secondaryInk),
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: PushlogButton(
                label: 'Cancel',
                variant: PushlogButtonVariant.ghost,
                size: PushlogButtonSize.medium,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: PushlogButton(
                label: confirmLabel,
                variant: PushlogButtonVariant.danger,
                size: PushlogButtonSize.medium,
                onPressed: onConfirm,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
