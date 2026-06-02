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
    );
  }

  final bool isSupported;
  final bool isPaired;
  final bool isAppInstalled;
  final bool isReachable;
  final String statusLabel;
  final double currentHeartRate;

  bool get canUseForWorkout => isSupported && isPaired && isAppInstalled;

  @override
  List<Object?> get props => [
    isSupported,
    isPaired,
    isAppInstalled,
    isReachable,
    statusLabel,
    currentHeartRate,
  ];
}
