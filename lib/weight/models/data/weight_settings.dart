import 'package:equatable/equatable.dart';

enum WeightUnit { kg, lb }

enum WeightGoal { lose, maintain, gain }

class WeightSettings extends Equatable {
  const WeightSettings({
    this.unit = WeightUnit.kg,
    this.goal = WeightGoal.maintain,
    this.shareProgress = false,
    this.shareLatestWeight = false,
    this.dirty = false,
  });

  factory WeightSettings.fromJson(Map<String, dynamic> json) {
    return WeightSettings(
      unit: WeightUnit.values.firstWhere(
        (value) => value.name == json['unit'],
        orElse: () => WeightUnit.kg,
      ),
      goal: WeightGoal.values.firstWhere(
        (value) => value.name == json['goal'],
        orElse: () => WeightGoal.maintain,
      ),
      shareProgress: json['shareProgress'] == true,
      shareLatestWeight: json['shareLatestWeight'] == true,
      dirty: json['dirty'] == true,
    );
  }

  final WeightUnit unit;
  final WeightGoal goal;
  final bool shareProgress;
  final bool shareLatestWeight;
  final bool dirty;

  WeightSettings copyWith({
    WeightUnit? unit,
    WeightGoal? goal,
    bool? shareProgress,
    bool? shareLatestWeight,
    bool? dirty,
  }) {
    final nextShare = shareProgress ?? this.shareProgress;
    return WeightSettings(
      unit: unit ?? this.unit,
      goal: goal ?? this.goal,
      shareProgress: nextShare,
      shareLatestWeight:
          nextShare && (shareLatestWeight ?? this.shareLatestWeight),
      dirty: dirty ?? this.dirty,
    );
  }

  Map<String, dynamic> toJson() => {
    'unit': unit.name,
    'goal': goal.name,
    'shareProgress': shareProgress,
    'shareLatestWeight': shareProgress && shareLatestWeight,
    'dirty': dirty,
  };

  @override
  List<Object?> get props => [
    unit,
    goal,
    shareProgress,
    shareLatestWeight,
    dirty,
  ];
}
