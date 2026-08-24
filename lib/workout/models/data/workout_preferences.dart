//
//  pushlog
//  workout_preferences.dart
//
//  Created by Ngonidzashe Mangudya on 2026/04/16.
//  Copyright (c) 2026 Codecraft Solutions. All rights reserved.
//

import 'package:equatable/equatable.dart';
import 'package:pushlog/training/models/training_plan.dart';

enum LiveDevicePreference { iphoneOnly, iphoneAndWatch }

class WorkoutPreferences extends Equatable {
  const WorkoutPreferences({
    this.remindersEnabled = false,
    this.reminderHour = 19,
    this.reminderMinute = 0,
    this.smartReminderCopyEnabled = true,
    this.streakRemindersEnabled = false,
    this.comebackRemindersEnabled = false,
    this.competitionNotificationsEnabled = true,
    this.healthSyncEnabled = false,
    this.liveDevicePreference = LiveDevicePreference.iphoneOnly,
    this.trainingPlan,
  });

  factory WorkoutPreferences.fromJson(Map<String, dynamic> json) =>
      WorkoutPreferences(
        remindersEnabled: (json['remindersEnabled'] as bool?) ?? false,
        reminderHour: (json['reminderHour'] as int?) ?? 19,
        reminderMinute: (json['reminderMinute'] as int?) ?? 0,
        smartReminderCopyEnabled:
            (json['smartReminderCopyEnabled'] as bool?) ?? true,
        streakRemindersEnabled:
            (json['streakRemindersEnabled'] as bool?) ?? false,
        comebackRemindersEnabled:
            (json['comebackRemindersEnabled'] as bool?) ?? false,
        competitionNotificationsEnabled:
            (json['competitionNotificationsEnabled'] as bool?) ?? true,
        healthSyncEnabled: (json['healthSyncEnabled'] as bool?) ?? false,
        liveDevicePreference: LiveDevicePreference.values.firstWhere(
          (value) => value.name == json['liveDevicePreference'],
          orElse: () => LiveDevicePreference.iphoneOnly,
        ),
        trainingPlan: json['trainingPlan'] == null
            ? null
            : TrainingPlan.fromJson(
                Map<String, dynamic>.from(json['trainingPlan'] as Map),
              ),
      );

  final bool remindersEnabled;
  final int reminderHour;
  final int reminderMinute;
  final bool smartReminderCopyEnabled;
  final bool streakRemindersEnabled;
  final bool comebackRemindersEnabled;
  final bool competitionNotificationsEnabled;
  final bool healthSyncEnabled;
  final LiveDevicePreference liveDevicePreference;
  final TrainingPlan? trainingPlan;

  bool get hasCompletedOnboarding => trainingPlan != null;
  bool get remoteNotificationsEnabled =>
      remindersEnabled ||
      competitionNotificationsEnabled ||
      streakRemindersEnabled ||
      comebackRemindersEnabled;

  Map<String, dynamic> toJson() => {
    'remindersEnabled': remindersEnabled,
    'reminderHour': reminderHour,
    'reminderMinute': reminderMinute,
    'smartReminderCopyEnabled': smartReminderCopyEnabled,
    'streakRemindersEnabled': streakRemindersEnabled,
    'comebackRemindersEnabled': comebackRemindersEnabled,
    'competitionNotificationsEnabled': competitionNotificationsEnabled,
    'healthSyncEnabled': healthSyncEnabled,
    'liveDevicePreference': liveDevicePreference.name,
    'trainingPlan': trainingPlan?.toJson(),
  };

  WorkoutPreferences copyWith({
    bool? remindersEnabled,
    int? reminderHour,
    int? reminderMinute,
    bool? smartReminderCopyEnabled,
    bool? streakRemindersEnabled,
    bool? comebackRemindersEnabled,
    bool? competitionNotificationsEnabled,
    bool? healthSyncEnabled,
    LiveDevicePreference? liveDevicePreference,
    TrainingPlan? Function()? trainingPlan,
  }) => WorkoutPreferences(
    remindersEnabled: remindersEnabled ?? this.remindersEnabled,
    reminderHour: reminderHour ?? this.reminderHour,
    reminderMinute: reminderMinute ?? this.reminderMinute,
    smartReminderCopyEnabled:
        smartReminderCopyEnabled ?? this.smartReminderCopyEnabled,
    streakRemindersEnabled:
        streakRemindersEnabled ?? this.streakRemindersEnabled,
    comebackRemindersEnabled:
        comebackRemindersEnabled ?? this.comebackRemindersEnabled,
    competitionNotificationsEnabled:
        competitionNotificationsEnabled ?? this.competitionNotificationsEnabled,
    healthSyncEnabled: healthSyncEnabled ?? this.healthSyncEnabled,
    liveDevicePreference: liveDevicePreference ?? this.liveDevicePreference,
    trainingPlan: trainingPlan == null ? this.trainingPlan : trainingPlan(),
  );

  @override
  List<Object?> get props => [
    remindersEnabled,
    reminderHour,
    reminderMinute,
    smartReminderCopyEnabled,
    streakRemindersEnabled,
    comebackRemindersEnabled,
    competitionNotificationsEnabled,
    healthSyncEnabled,
    liveDevicePreference,
    trainingPlan,
  ];
}
