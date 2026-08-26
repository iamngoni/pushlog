import 'package:flutter_test/flutter_test.dart';
import 'package:pushlog/core/services/reminder_service.dart';
import 'package:pushlog/training/models/training_plan.dart';
import 'package:pushlog/workout/models/data/workout_preferences.dart';

void main() {
  const profile = TrainingProfile(
    goal: TrainingGoal.buildHabit,
    experience: TrainingExperience.newToTraining,
    baselineSource: BaselineSource.recentResult,
    baselineMaxReps: 10,
    targetMaxReps: 20,
    durationWeeks: 12,
    sessionsPerWeek: 3,
    preferredWeekdays: [
      DateTime.monday,
      DateTime.wednesday,
      DateTime.friday,
    ],
    consistencyPreference: ConsistencyPreference.weeklyPlan,
    coachingStyle: CoachingStyle.minimal,
  );
  final plan = TrainingPlan(
    profile: profile,
    startDate: DateTime(2026, 8, 3),
    createdAt: DateTime(2026, 8, 3),
  );
  final preferences = WorkoutPreferences(
    remindersEnabled: true,
    trainingPlan: plan,
  );

  test('schedules reminders only on future training days', () {
    final dates = ReminderService().scheduledDatesFor(
      preferences,
      now: DateTime(2026, 8, 4, 10),
      windowDays: 7,
    );

    expect(dates.map((date) => date.weekday), [
      DateTime.wednesday,
      DateTime.friday,
      DateTime.monday,
    ]);
    expect(dates.map((date) => date.hour), everyElement(19));
  });

  test('does not duplicate today after the reminder time has passed', () {
    final dates = ReminderService().scheduledDatesFor(
      preferences.copyWith(
        trainingPlan: () => plan.copyWith(
          profile: profile.copyWith(
            sessionsPerWeek: 2,
            preferredWeekdays: const [
              DateTime.tuesday,
              DateTime.wednesday,
            ],
          ),
        ),
      ),
      now: DateTime(2026, 8, 4, 20),
      windowDays: 2,
    );

    expect(dates, [DateTime(2026, 8, 5, 19)]);
  });

  test('does not remind for a training day that is already complete', () {
    final dates = ReminderService().scheduledDatesFor(
      preferences,
      now: DateTime(2026, 8, 4, 10),
      windowDays: 4,
      completedDayKeys: const {'2026-08-05'},
    );

    expect(dates, [DateTime(2026, 8, 7, 19)]);
  });

  test('uses the selected coaching style and planned prescription', () {
    final copy = ReminderService().copyFor(
      preferences,
      DateTime(2026, 8, 5, 19),
    );

    expect(copy.title, 'Pushlog');
    expect(copy.body, contains('2 × 4 clean reps'));
  });
}
