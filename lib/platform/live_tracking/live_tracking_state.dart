import 'package:equatable/equatable.dart';

enum LiveTrackingPhase {
  unavailable,
  setup,
  calibrating,
  locked,
  countdown,
  active,
  lost,
  paused,
}

enum LiveTrackingCameraAccess {
  unknown,
  ready,
  denied,
}

class LiveTrackingSnapshot extends Equatable {
  const LiveTrackingSnapshot({
    required this.isSupported,
    required this.cameraAccess,
    required this.phase,
    required this.repCount,
    required this.manualAdjustments,
    required this.statusLabel,
    required this.movementLabel,
    required this.metricsLine,
    this.countdownValue,
    this.averageRepDuration,
  });

  const LiveTrackingSnapshot.unsupported()
    : this(
        isSupported: false,
        cameraAccess: LiveTrackingCameraAccess.denied,
        phase: LiveTrackingPhase.unavailable,
        repCount: 0,
        manualAdjustments: 0,
        statusLabel: 'UNAVAILABLE',
        movementLabel: 'MANUAL',
        metricsLine: 'AUTO TRACKING IS NOT AVAILABLE ON THIS DEVICE',
      );

  factory LiveTrackingSnapshot.fromMap(Map<Object?, Object?> map) {
    return LiveTrackingSnapshot(
      isSupported: map['isSupported'] as bool? ?? false,
      cameraAccess: _cameraAccess(map['cameraAccess'] as String?),
      phase: _phase(map['phase'] as String?),
      repCount: (map['repCount'] as num?)?.toInt() ?? 0,
      manualAdjustments: (map['manualAdjustments'] as num?)?.toInt() ?? 0,
      statusLabel: map['statusLabel'] as String? ?? 'READY',
      movementLabel: map['movementLabel'] as String? ?? 'READY',
      metricsLine: map['metricsLine'] as String? ?? 'ALIGN FACE WITH FRAME',
      countdownValue: (map['countdownValue'] as num?)?.toInt(),
      averageRepDuration: _durationFromSeconds(map['averageRepDuration']),
    );
  }

  final bool isSupported;
  final LiveTrackingCameraAccess cameraAccess;
  final LiveTrackingPhase phase;
  final int repCount;
  final int manualAdjustments;
  final String statusLabel;
  final String movementLabel;
  final String metricsLine;
  final int? countdownValue;
  final Duration? averageRepDuration;

  bool get canUseAutoTracking =>
      isSupported && cameraAccess != LiveTrackingCameraAccess.denied;

  bool get canBeginCountdown =>
      phase == LiveTrackingPhase.locked && countdownValue == null;

  bool get isActive => phase == LiveTrackingPhase.active;

  bool get isPaused => phase == LiveTrackingPhase.paused;

  static LiveTrackingPhase _phase(String? raw) {
    return LiveTrackingPhase.values.firstWhere(
      (phase) => phase.name == raw,
      orElse: () => LiveTrackingPhase.unavailable,
    );
  }

  static LiveTrackingCameraAccess _cameraAccess(String? raw) {
    return LiveTrackingCameraAccess.values.firstWhere(
      (access) => access.name == raw,
      orElse: () => LiveTrackingCameraAccess.unknown,
    );
  }

  static Duration? _durationFromSeconds(Object? raw) {
    final seconds = (raw as num?)?.toDouble();
    if (seconds == null) return null;
    return Duration(
      microseconds: (seconds * Duration.microsecondsPerSecond).round(),
    );
  }

  @override
  List<Object?> get props => [
    isSupported,
    cameraAccess,
    phase,
    repCount,
    manualAdjustments,
    statusLabel,
    movementLabel,
    metricsLine,
    countdownValue,
    averageRepDuration,
  ];
}
