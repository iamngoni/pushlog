//
//  pushlog
//  workout_preferences.dart
//
//  Created by Ngonidzashe Mangudya on 2026/04/16.
//  Copyright (c) 2026 Codecraft Solutions. All rights reserved.
//

import 'package:equatable/equatable.dart';

enum LiveDevicePreference {
  iphoneOnly,
  iphoneAndWatch,
}

class WorkoutPreferences extends Equatable {
  const WorkoutPreferences({
    this.remindersEnabled = false,
    this.reminderHour = 19,
    this.reminderMinute = 0,
    this.smartReminderCopyEnabled = true,
    this.healthSyncEnabled = false,
    this.liveDevicePreference = LiveDevicePreference.iphoneOnly,
  });

  factory WorkoutPreferences.fromJson(Map<String, dynamic> json) =>
      WorkoutPreferences(
        remindersEnabled: (json['remindersEnabled'] as bool?) ?? false,
        reminderHour: (json['reminderHour'] as int?) ?? 19,
        reminderMinute: (json['reminderMinute'] as int?) ?? 0,
        smartReminderCopyEnabled:
            (json['smartReminderCopyEnabled'] as bool?) ?? true,
        healthSyncEnabled: (json['healthSyncEnabled'] as bool?) ?? false,
        liveDevicePreference: LiveDevicePreference.values.firstWhere(
          (value) => value.name == json['liveDevicePreference'],
          orElse: () => LiveDevicePreference.iphoneOnly,
        ),
      );

  final bool remindersEnabled;
  final int reminderHour;
  final int reminderMinute;
  final bool smartReminderCopyEnabled;
  final bool healthSyncEnabled;
  final LiveDevicePreference liveDevicePreference;

  Map<String, dynamic> toJson() => {
    'remindersEnabled': remindersEnabled,
    'reminderHour': reminderHour,
    'reminderMinute': reminderMinute,
    'smartReminderCopyEnabled': smartReminderCopyEnabled,
    'healthSyncEnabled': healthSyncEnabled,
    'liveDevicePreference': liveDevicePreference.name,
  };

  WorkoutPreferences copyWith({
    bool? remindersEnabled,
    int? reminderHour,
    int? reminderMinute,
    bool? smartReminderCopyEnabled,
    bool? healthSyncEnabled,
    LiveDevicePreference? liveDevicePreference,
  }) => WorkoutPreferences(
    remindersEnabled: remindersEnabled ?? this.remindersEnabled,
    reminderHour: reminderHour ?? this.reminderHour,
    reminderMinute: reminderMinute ?? this.reminderMinute,
    smartReminderCopyEnabled:
        smartReminderCopyEnabled ?? this.smartReminderCopyEnabled,
    healthSyncEnabled: healthSyncEnabled ?? this.healthSyncEnabled,
    liveDevicePreference: liveDevicePreference ?? this.liveDevicePreference,
  );

  @override
  List<Object?> get props => [
    remindersEnabled,
    reminderHour,
    reminderMinute,
    smartReminderCopyEnabled,
    healthSyncEnabled,
    liveDevicePreference,
  ];
}
