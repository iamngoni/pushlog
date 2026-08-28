import 'package:equatable/equatable.dart';

enum HealthKitWriteOwner {
  phone,
  watch,
}

class WatchStatus extends Equatable {
  const WatchStatus({
    required this.isSupported,
    required this.isPaired,
    required this.isAppInstalled,
    required this.isReachable,
    required this.statusLabel,
    this.currentHeartRate = 0,
    this.activeCalories = 0,
    this.controlAction = '',
    this.controlValue = 0,
    this.controlSequence = 0,
  });

  const WatchStatus.unsupported()
    : this(
        isSupported: false,
        isPaired: false,
        isAppInstalled: false,
        isReachable: false,
        statusLabel: 'IPHONE ONLY',
      );

  factory WatchStatus.fromMap(Map<Object?, Object?> map) {
    return WatchStatus(
      isSupported: map['isSupported'] as bool? ?? false,
      isPaired: map['isPaired'] as bool? ?? false,
      isAppInstalled: map['isAppInstalled'] as bool? ?? false,
      isReachable: map['isReachable'] as bool? ?? false,
      statusLabel: map['statusLabel'] as String? ?? 'IPHONE ONLY',
      currentHeartRate: (map['currentHeartRate'] as num?)?.toDouble() ?? 0,
      activeCalories: (map['activeCalories'] as num?)?.toDouble() ?? 0,
      controlAction: map['controlAction'] as String? ?? '',
      controlValue: (map['controlValue'] as num?)?.toInt() ?? 0,
      controlSequence: (map['controlSequence'] as num?)?.toInt() ?? 0,
    );
  }

  final bool isSupported;
  final bool isPaired;
  final bool isAppInstalled;
  final bool isReachable;
  final String statusLabel;
  final double currentHeartRate;
  final double activeCalories;
  final String controlAction;
  final int controlValue;
  final int controlSequence;

  bool get canUseForWorkout => isSupported && isPaired && isAppInstalled;

  @override
  List<Object?> get props => [
    isSupported,
    isPaired,
    isAppInstalled,
    isReachable,
    statusLabel,
    currentHeartRate,
    activeCalories,
    controlAction,
    controlValue,
    controlSequence,
  ];
}
