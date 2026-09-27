import 'package:equatable/equatable.dart';

class WeightEntry extends Equatable {
  const WeightEntry({
    required this.recordedOn,
    required this.weightGrams,
    required this.updatedAt,
    this.dirty = false,
  });

  factory WeightEntry.fromJson(Map<String, dynamic> json) {
    return WeightEntry(
      recordedOn: json['recordedOn'] as String,
      weightGrams: (json['weightGrams'] as num).toInt(),
      updatedAt: json['updatedAt'] as String? ?? '',
      dirty: json['dirty'] == true,
    );
  }

  final String recordedOn;
  final int weightGrams;
  final String updatedAt;
  final bool dirty;

  WeightEntry copyWith({int? weightGrams, String? updatedAt, bool? dirty}) {
    return WeightEntry(
      recordedOn: recordedOn,
      weightGrams: weightGrams ?? this.weightGrams,
      updatedAt: updatedAt ?? this.updatedAt,
      dirty: dirty ?? this.dirty,
    );
  }

  Map<String, dynamic> toJson() => {
    'recordedOn': recordedOn,
    'weightGrams': weightGrams,
    'updatedAt': updatedAt,
    'dirty': dirty,
  };

  @override
  List<Object?> get props => [recordedOn, weightGrams, updatedAt, dirty];
}

class FriendWeighIn extends Equatable {
  const FriendWeighIn({
    required this.uid,
    required this.goal,
    required this.signedChangeGrams,
    required this.weighInCount,
    this.displayName,
    this.username,
    this.latestWeightGrams,
  });

  factory FriendWeighIn.fromJson(Map<String, dynamic> json) {
    return FriendWeighIn(
      uid: json['uid'] as String,
      displayName: json['displayName'] as String?,
      username: json['username'] as String?,
      goal: json['goal'] as String? ?? 'maintain',
      signedChangeGrams: (json['signedChangeGrams'] as num?)?.toInt() ?? 0,
      weighInCount: (json['weighInCount'] as num?)?.toInt() ?? 0,
      latestWeightGrams: (json['latestWeightGrams'] as num?)?.toInt(),
    );
  }

  final String uid;
  final String? displayName;
  final String? username;
  final String goal;
  final int signedChangeGrams;
  final int weighInCount;
  final int? latestWeightGrams;

  @override
  List<Object?> get props => [
    uid,
    displayName,
    username,
    goal,
    signedChangeGrams,
    weighInCount,
    latestWeightGrams,
  ];
}
