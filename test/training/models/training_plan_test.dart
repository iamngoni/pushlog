import 'package:flutter_test/flutter_test.dart';
import 'package:pushlog/training/models/training_plan.dart';
import 'package:pushlog/workout/models/data/workout_preferences.dart';

void main() {
  const profile = TrainingProfile(
    goal: TrainingGoal.increaseMaximum,
    experience: TrainingExperience.regular,
    baselineSource: BaselineSource.recentResult,
    baselineMaxReps: 10,
    targetMaxReps: 30,
    durationWeeks: 12,
    sessionsPerWeek: 3,
    preferredWeekdays: [DateTime.monday, DateTime.wednesday, DateTime.friday],
    consistencyPreference: ConsistencyPreference.weeklyPlan,
    coachingStyle: CoachingStyle.calm,
  );
  final startDate = DateTime(2026, 8, 3);
  final createdAt = DateTime(2026, 8, 3, 8, 30);

  test('training plan round-trips without changing calculation inputs', () {
    final plan = TrainingPlan(
      profile: profile,
      startDate: startDate,
      createdAt: createdAt,
    );

    expect(TrainingPlan.fromJson(plan.toJson()), plan);
    expect(plan.algorithmVersion, TrainingPlan.currentAlgorithmVersion);
  });

  test('working sets stay below the estimated maximum', () {
    final plan = TrainingPlan(
      profile: profile,
      startDate: startDate,
      createdAt: createdAt,
    );

    final firstSession = plan.sessionFor(startDate);
    final finalSession = plan.sessionFor(DateTime(2026, 10, 19));

    expect(firstSession.isTrainingDay, isTrue);
    expect(firstSession.repsPerSet, lessThan(firstSession.estimatedCapacity));
    expect(finalSession.repsPerSet, lessThan(finalSession.estimatedCapacity));
    expect(finalSession.totalReps, greaterThan(firstSession.totalReps));
  });

  test('rest days have no planned repetition target', () {
    final plan = TrainingPlan(
      profile: profile,
      startDate: startDate,
      createdAt: createdAt,
    );

    final restDay = plan.sessionFor(DateTime(2026, 8, 4));

    expect(restDay.isTrainingDay, isFalse);
    expect(restDay.totalReps, 0);
  });

  test('days outside the plan cannot become training days', () {
    final plan = TrainingPlan(
      profile: profile,
      startDate: startDate,
      createdAt: createdAt,
    );
    expect(
      plan.sessionFor(DateTime(2026, 7, 27)).isTrainingDay,
      isFalse,
    );
    expect(
      plan.sessionFor(plan.endDate.add(const Duration(days: 2))).isTrainingDay,
      isFalse,
    );
  });

  test('every fourth week is marked for reassessment', () {
    final plan = TrainingPlan(
      profile: profile,
      startDate: startDate,
      createdAt: createdAt,
    );

    expect(plan.sessionFor(DateTime(2026, 8, 24)).isAssessmentWeek, isTrue);
    expect(plan.sessionFor(DateTime(2026, 8, 17)).isAssessmentWeek, isFalse);
  });

  test('preferences preserve plans and migrate older snapshots', () {
    final plan = TrainingPlan(
      profile: profile,
      startDate: startDate,
      createdAt: createdAt,
    );
    final preferences = WorkoutPreferences(
      remindersEnabled: true,
      trainingPlan: plan,
    );

    expect(WorkoutPreferences.fromJson(preferences.toJson()), preferences);
    expect(
      WorkoutPreferences.fromJson(const {}).hasCompletedOnboarding,
      isFalse,
    );
  });

  test('invalid stored weekdays fall back to a balanced schedule', () {
    final decoded = TrainingProfile.fromJson({
      ...profile.toJson(),
      'sessionsPerWeek': 3,
      'preferredWeekdays': const [1, 1, 9],
    });

    expect(decoded.preferredWeekdays, [
      DateTime.monday,
      DateTime.wednesday,
      DateTime.friday,
    ]);
  });
}
