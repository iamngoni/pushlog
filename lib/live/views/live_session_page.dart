import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pushlog/core/configs/colors.dart';
import 'package:pushlog/core/configs/motion.dart';
import 'package:pushlog/core/configs/spacing.dart';
import 'package:pushlog/core/configs/typography.dart';
import 'package:pushlog/core/views/widgets/pushlog_button.dart';
import 'package:pushlog/core/views/widgets/pushlog_surface.dart';
import 'package:pushlog/injection.dart';
import 'package:pushlog/platform/health/health_service.dart';
import 'package:pushlog/platform/live_tracking/live_tracking_service.dart';
import 'package:pushlog/platform/live_tracking/live_tracking_state.dart';
import 'package:pushlog/platform/watch/watch_service.dart';
import 'package:pushlog/platform/watch/watch_state.dart';
import 'package:pushlog/workout/models/data/workout_preferences.dart';
import 'package:pushlog/workout/state/workout/workout_bloc.dart';

class LiveSessionPage extends StatefulWidget {
  const LiveSessionPage({super.key});

  @override
  State<LiveSessionPage> createState() => _LiveSessionPageState();
}

class _LiveSessionPageState extends State<LiveSessionPage> {
  _LiveStep _step = _LiveStep.setup;
  late WorkoutPreferences _preferences;
  Timer? _ticker;
  StreamSubscription<LiveTrackingSnapshot>? _trackingSubscription;
  StreamSubscription<WatchStatus>? _watchSubscription;
  LiveTrackingSnapshot _trackingSnapshot =
      const LiveTrackingSnapshot.unsupported();
  WatchStatus _watchStatus = const WatchStatus.unsupported();
  HealthKitWriteOwner _healthKitWriteOwner = HealthKitWriteOwner.phone;
  Duration _elapsed = Duration.zero;
  DateTime? _startedAt;
  String? _sessionId;
  int _reps = 0;
  int _manualAdjustments = 0;
  bool _isPaused = false;
  bool _usesAutoTracking = false;
  bool _didLoadTrackingStatus = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_step == _LiveStep.setup) {
      final workoutState = context.read<WorkoutBloc>().state;
      if (workoutState is WorkoutLoaded) {
        _preferences = workoutState.preferences;
      }
      if (!_didLoadTrackingStatus) {
        _didLoadTrackingStatus = true;
        unawaited(_refreshTrackingStatus());
        unawaited(_refreshWatchStatus());
      }
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    unawaited(_trackingSubscription?.cancel());
    unawaited(_watchSubscription?.cancel());
    unawaited(getIt<LiveTrackingService>().cancel());
    if (_sessionId != null && _step != _LiveStep.summary) {
      unawaited(
        getIt<WatchService>().cancelLiveWorkout(sessionId: _sessionId!),
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Scaffold(
      backgroundColor: theme.background,
      body: SafeArea(
        child: switch (_step) {
          _LiveStep.setup => _buildSetup(context, theme),
          _LiveStep.preflight => _buildPreflight(context, theme),
          _LiveStep.tracking => _buildTracking(context, theme),
          _LiveStep.summary => _buildSummary(context, theme),
        },
      ),
    );
  }

  Widget _buildSetup(BuildContext context, AppTheme theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          _TopBar(theme: theme, trailing: 'GUIDED LIVE'),
          const SizedBox(height: 28),
          Text(
            'Live',
            style: AppTypography.headingXLarge(color: theme.ink),
          ),
          const SizedBox(height: 8),
          Text(
            'Timed session mode. Start here, count clean, save once.',
            style: AppTypography.bodyLarge(color: theme.secondaryInk),
          ),
          const SizedBox(height: 24),
          Divider(height: 1, color: theme.divider),
          const SizedBox(height: 24),
          _SelectorCard(
            title: 'DEVICE',
            detail:
                _preferences.liveDevicePreference ==
                    LiveDevicePreference.iphoneOnly
                ? 'iPhone only'
                : _watchStatus.statusLabel,
            theme: theme,
            children: [
              _DeviceOption(
                title: 'iPhone only',
                isSelected:
                    _preferences.liveDevicePreference ==
                    LiveDevicePreference.iphoneOnly,
                theme: theme,
                onTap: () => setState(() {
                  _preferences = _preferences.copyWith(
                    liveDevicePreference: LiveDevicePreference.iphoneOnly,
                  );
                }),
              ),
              const SizedBox(height: 8),
              _DeviceOption(
                title: _watchStatus.canUseForWorkout
                    ? 'iPhone + Apple Watch'
                    : 'iPhone + Watch fallback',
                isSelected:
                    _preferences.liveDevicePreference ==
                    LiveDevicePreference.iphoneAndWatch,
                theme: theme,
                onTap: () => setState(() {
                  _preferences = _preferences.copyWith(
                    liveDevicePreference: LiveDevicePreference.iphoneAndWatch,
                  );
                }),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _SelectorCard(
            title: 'FLOW',
            detail: _trackingSnapshot.canUseAutoTracking
                ? _trackingSnapshot.statusLabel
                : 'Manual fallback',
            theme: theme,
            children: [
              Text(
                _trackingSnapshot.canUseAutoTracking
                    ? _trackingSnapshot.metricsLine
                    : 'Android and non-TrueDepth devices count manually. '
                          'TrueDepth iPhones open camera pre-flight.',
                style: AppTypography.body(color: theme.secondaryInk),
              ),
            ],
          ),
          const Spacer(),
          _BottomPair(
            theme: theme,
            leading: 'Exit',
            onLeadingTap: () => Navigator.of(context).pop(),
            trailing: 'Start',
            onTrailingTap: () {
              unawaited(_startPreflightOrManual());
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildPreflight(BuildContext context, AppTheme theme) {
    final countdown = _trackingSnapshot.countdownValue;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          _TopBar(theme: theme, trailing: 'PRE-FLIGHT'),
          const SizedBox(height: 28),
          Text(
            countdown?.toString() ?? _trackingSnapshot.statusLabel,
            style: AppTypography.metricXLarge(color: theme.ink),
          ),
          const SizedBox(height: 8),
          Text(
            _trackingSnapshot.movementLabel,
            style: AppTypography.bodyLarge(color: theme.secondaryInk),
          ),
          const SizedBox(height: 26),
          _SelectorCard(
            title: 'CAMERA LOCK',
            detail: _trackingSnapshot.phase.name,
            theme: theme,
            children: [
              Text(
                _trackingSnapshot.metricsLine,
                style: AppTypography.body(color: theme.secondaryInk),
              ),
            ],
          ),
          const Spacer(),
          _BottomPair(
            theme: theme,
            leading: 'Manual',
            onLeadingTap: () => _startSession(usesAutoTracking: false),
            trailing: _trackingSnapshot.canBeginCountdown ? 'Begin' : 'Hold',
            onTrailingTap: _trackingSnapshot.canBeginCountdown
                ? () {
                    unawaited(_beginCountdown());
                  }
                : () {},
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildTracking(
    BuildContext context,
    AppTheme theme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          _TopBar(theme: theme, trailing: 'SESSION'),
          const SizedBox(height: 24),
          Text(
            _formatDuration(_elapsed),
            style: AppTypography.metricXLarge(color: theme.ink),
          ),
          const SizedBox(height: 6),
          Text(
            _usesAutoTracking
                ? _trackingSnapshot.movementLabel
                : _isPaused
                ? 'Paused'
                : 'Running',
            style: AppTypography.bodyLarge(
              color: _isPaused ? theme.accentInk : theme.secondaryInk,
            ),
          ),
          const SizedBox(height: 26),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              border: Border.all(color: theme.divider),
              color: theme.surface,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TOTAL REPS',
                  style: AppTypography.overline(color: theme.tertiaryInk),
                ),
                const SizedBox(height: 14),
                Text(
                  '$_reps',
                  style: AppTypography.metricHero(color: theme.ink),
                ),
                const SizedBox(height: 8),
                Text(
                  _usesAutoTracking
                      ? _trackingSnapshot.metricsLine
                      : 'Manual adjustments: $_manualAdjustments',
                  style: AppTypography.body(color: theme.secondaryInk),
                ),
              ],
            ),
          ),
          const Spacer(),
          _LiveAdjustStrip(
            theme: theme,
            onAdd: _addReps,
            onPause: _togglePause,
            onEnd: _finishSession,
            isPaused: _isPaused,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSummary(BuildContext context, AppTheme theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          _TopBar(theme: theme, trailing: 'SUMMARY'),
          const SizedBox(height: 28),
          Text(
            '$_reps',
            style: AppTypography.metricHero(color: theme.ink),
          ),
          const SizedBox(height: 8),
          Text(
            'Live sessions save once, at the end.',
            style: AppTypography.bodyLarge(color: theme.secondaryInk),
          ),
          const SizedBox(height: 24),
          _SummaryCard(
            theme: theme,
            rows: [
              ('Duration', _formatDuration(_elapsed)),
              ('Source', 'Live session'),
              (
                'Device',
                _preferences.liveDevicePreference ==
                        LiveDevicePreference.iphoneOnly
                    ? 'iPhone'
                    : _watchStatus.statusLabel,
              ),
              ('Health owner', _healthKitWriteOwner.name),
              ('Adjustments', '$_manualAdjustments'),
            ],
          ),
          const Spacer(),
          _BottomPair(
            theme: theme,
            leading: 'Discard',
            onLeadingTap: () {
              unawaited(_discardSession(context));
            },
            trailing: 'Save',
            onTrailingTap: () {
              unawaited(_saveSession(context));
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _refreshTrackingStatus() async {
    final status = await getIt<LiveTrackingService>().status();
    if (!mounted) return;
    setState(() {
      _trackingSnapshot = status;
    });
  }

  Future<void> _refreshWatchStatus() async {
    final service = getIt<WatchService>();
    final status = await service.status();
    if (!mounted) return;
    setState(() {
      _watchStatus = status;
    });

    await _watchSubscription?.cancel();
    if (!status.isSupported) return;
    _watchSubscription = service.statuses().listen(
      (status) {
        if (!mounted) return;
        setState(() {
          _watchStatus = status;
        });
      },
      onError: (_) {},
    );
  }

  Future<void> _startPreflightOrManual() async {
    final service = getIt<LiveTrackingService>();
    final status = await service.status();
    if (!mounted) return;

    if (!status.canUseAutoTracking) {
      setState(() {
        _trackingSnapshot = status;
      });
      _startSession(usesAutoTracking: false);
      return;
    }

    await _trackingSubscription?.cancel();
    _trackingSubscription = service.snapshots().listen(_handleTrackingSnapshot);
    final preflight = await service.startPreflight();
    if (!mounted) return;
    setState(() {
      _trackingSnapshot = preflight;
      _step = _LiveStep.preflight;
      _usesAutoTracking = true;
    });
  }

  Future<void> _beginCountdown() async {
    final snapshot = await getIt<LiveTrackingService>().beginCountdown();
    if (!mounted) return;
    setState(() {
      _trackingSnapshot = snapshot;
    });
  }

  void _handleTrackingSnapshot(LiveTrackingSnapshot snapshot) {
    if (!mounted) return;
    setState(() {
      _trackingSnapshot = snapshot;
      _reps = snapshot.repCount;
      _manualAdjustments = snapshot.manualAdjustments;
      _isPaused = snapshot.isPaused;
    });

    if (snapshot.isActive && _step == _LiveStep.preflight) {
      _startSession(usesAutoTracking: true);
    }
  }

  void _startSession({required bool usesAutoTracking}) {
    context.read<WorkoutBloc>().add(
      UpdatePreferencesEvent(_preferences),
    );
    setState(() {
      _step = _LiveStep.tracking;
      _elapsed = Duration.zero;
      _reps = 0;
      _manualAdjustments = 0;
      _isPaused = false;
      _usesAutoTracking = usesAutoTracking;
      _startedAt = DateTime.now();
      _sessionId = WorkoutBloc.generateId();
      _healthKitWriteOwner = HealthKitWriteOwner.phone;
    });
    _beginWatchWorkoutIfNeeded();
    _ticker?.cancel();
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (!mounted || _isPaused || _startedAt == null) {
          return;
        }
        setState(() {
          _elapsed = DateTime.now().difference(
            _startedAt!,
          );
        });
        _sendWatchLiveUpdate();
      },
    );
  }

  void _beginWatchWorkoutIfNeeded() {
    final sessionId = _sessionId;
    final startedAt = _startedAt;
    if (sessionId == null || startedAt == null) return;

    unawaited(
      getIt<WatchService>()
          .beginLiveWorkout(
            sessionId: sessionId,
            startedAt: startedAt,
            preferWatch:
                _preferences.liveDevicePreference ==
                LiveDevicePreference.iphoneAndWatch,
          )
          .then((status) {
            if (!mounted) return;
            setState(() {
              _watchStatus = status;
            });
          }),
    );
  }

  void _sendWatchLiveUpdate() {
    final sessionId = _sessionId;
    if (sessionId == null) return;

    unawaited(
      getIt<WatchService>().sendLiveUpdate(
        sessionId: sessionId,
        reps: _reps,
        elapsed: _elapsed,
        phase: _step.name.toUpperCase(),
        trackingState: _usesAutoTracking
            ? _trackingSnapshot.phase.name.toUpperCase()
            : 'MANUAL',
        isPaused: _isPaused,
      ),
    );
  }

  void _addReps(int value) {
    if (_usesAutoTracking) {
      unawaited(getIt<LiveTrackingService>().addManualRep());
      return;
    }

    setState(() {
      _reps += value;
      _manualAdjustments += 1;
    });
  }

  void _togglePause() {
    if (_usesAutoTracking) {
      unawaited(getIt<LiveTrackingService>().togglePause());
      return;
    }

    setState(() {
      _isPaused = !_isPaused;
    });
  }

  void _finishSession() {
    _ticker?.cancel();
    unawaited(_finishSessionAsync());
  }

  Future<void> _finishSessionAsync() async {
    final sessionId = _sessionId;
    final endedAt = DateTime.now();

    if (_usesAutoTracking) {
      final finished = await getIt<LiveTrackingService>().finish();
      if (!mounted) return;
      setState(() {
        _trackingSnapshot = finished;
        _reps = finished.repCount;
        _manualAdjustments = finished.manualAdjustments;
        _isPaused = false;
      });
    }

    if (sessionId != null) {
      _healthKitWriteOwner = await getIt<WatchService>().stopLiveWorkout(
        sessionId: sessionId,
        reps: _reps,
        duration: _elapsed,
        endedAt: endedAt,
      );
      if (!mounted) return;
    }

    setState(() {
      _step = _LiveStep.summary;
      _isPaused = false;
    });
  }

  Future<void> _saveSession(BuildContext context) async {
    final sessionId = _sessionId ?? WorkoutBloc.generateId();
    final avgRepDuration =
        _trackingSnapshot.averageRepDuration ??
        (_reps <= 0
            ? null
            : Duration(
                microseconds: _elapsed.inMicroseconds ~/ _reps,
              ));

    context.read<WorkoutBloc>().add(
      SaveLiveSessionEvent(
        sessionId: sessionId,
        reps: _reps,
        duration: _elapsed,
        avgRepDuration: avgRepDuration,
        manualAdjustments: _manualAdjustments,
      ),
    );

    if (_healthKitWriteOwner == HealthKitWriteOwner.watch) {
      _healthKitWriteOwner = await getIt<WatchService>().commitStoppedWorkout(
        sessionId: sessionId,
      );
    }

    if (_preferences.healthSyncEnabled &&
        _healthKitWriteOwner == HealthKitWriteOwner.phone &&
        _reps > 0) {
      await getIt<HealthService>().saveLiveSession(
        reps: _reps,
        duration: _elapsed,
        manualAdjustments: _manualAdjustments,
        endedAt: DateTime.now(),
        externalId: sessionId,
      );
    }

    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _discardSession(BuildContext context) async {
    final sessionId = _sessionId;
    if (sessionId != null) {
      await getIt<WatchService>().discardStoppedWorkout(sessionId: sessionId);
    }
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = duration.inHours.toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }
}

enum _LiveStep { setup, preflight, tracking, summary }

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.theme,
    required this.trailing,
  });

  final AppTheme theme;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'PUSHLOG',
          style: AppTypography.overline(color: theme.tertiaryInk),
        ),
        Text(
          trailing,
          style: AppTypography.overline(color: theme.tertiaryInk),
        ),
      ],
    );
  }
}

class _SelectorCard extends StatelessWidget {
  const _SelectorCard({
    required this.title,
    required this.detail,
    required this.theme,
    required this.children,
  });

  final String title;
  final String detail;
  final AppTheme theme;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return PushlogCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OverlineLabel(title),
          const SizedBox(height: AppSpacing.md),
          Text(detail, style: AppTypography.title(color: theme.ink)),
          const SizedBox(height: AppSpacing.xl),
          ...children,
        ],
      ),
    );
  }
}

class _DeviceOption extends StatelessWidget {
  const _DeviceOption({
    required this.title,
    required this.isSelected,
    required this.theme,
    required this.onTap,
  });

  final String title;
  final bool isSelected;
  final AppTheme theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      inMutuallyExclusiveGroup: true,
      selected: isSelected,
      child: PressFeedback(
        onTap: onTap,
        semanticLabel: title,
        child: AnimatedContainer(
          duration: AppMotion.duration(context, AppMotion.fast),
          width: double.infinity,
          constraints: const BoxConstraints(
            minHeight: AppSpacing.minTapTarget,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.lg,
          ),
          decoration: BoxDecoration(
            color: isSelected ? theme.accentSoft : theme.surfaceSunken,
            borderRadius: AppRadius.all(AppRadius.sm),
            border: Border.all(
              color: isSelected ? theme.accent : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.body(
                    color: theme.ink,
                    weight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              if (isSelected)
                Icon(Icons.check_rounded, size: 18, color: theme.accentInk),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomPair extends StatelessWidget {
  const _BottomPair({
    required this.theme,
    required this.leading,
    required this.onLeadingTap,
    required this.trailing,
    required this.onTrailingTap,
  });

  final AppTheme theme;
  final String leading;
  final VoidCallback onLeadingTap;
  final String trailing;
  final VoidCallback onTrailingTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Row(
        children: [
          Expanded(
            child: PushlogButton(
              label: leading,
              variant: PushlogButtonVariant.ghost,
              onPressed: onLeadingTap,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            flex: 2,
            child: PushlogButton(
              label: trailing,
              onPressed: onTrailingTap,
            ),
          ),
        ],
      ),
    );
  }
}

/// Rep controls for a session in progress.
///
/// The three add buttons are peers — nothing about "+1" makes it more
/// likely than "+10" mid-set — so none of them takes the accent. Signal
/// Lime goes to End, which is the one action that closes the session out.
class _LiveAdjustStrip extends StatelessWidget {
  const _LiveAdjustStrip({
    required this.theme,
    required this.onAdd,
    required this.onPause,
    required this.onEnd,
    required this.isPaused,
  });

  final AppTheme theme;
  final void Function(int value) onAdd;
  final VoidCallback onPause;
  final VoidCallback onEnd;
  final bool isPaused;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        children: [
          Row(
            children: [
              for (final value in const [1, 10, 25]) ...[
                Expanded(
                  child: PressFeedback(
                    onTap: () => onAdd(value),
                    haptic: AppHaptics.tick,
                    semanticLabel: 'Add $value reps',
                    child: Container(
                      height: AppSpacing.controlHeight,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: theme.surface,
                        borderRadius: AppRadius.all(AppRadius.md),
                      ),
                      child: Text(
                        '+$value',
                        style: AppTypography.metricCompact(color: theme.ink),
                      ),
                    ),
                  ),
                ),
                if (value != 25) const SizedBox(width: AppSpacing.lg),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: PushlogButton(
                  label: isPaused ? 'Resume' : 'Pause',
                  icon: isPaused
                      ? Icons.play_arrow_rounded
                      : Icons.pause_rounded,
                  variant: PushlogButtonVariant.ghost,
                  onPressed: onPause,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: PushlogButton(
                  label: 'End',
                  icon: Icons.flag_rounded,
                  onPressed: onEnd,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.theme,
    required this.rows,
  });

  final AppTheme theme;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return PushlogCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final indexedRow in rows.indexed)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.xl,
              ),
              decoration: BoxDecoration(
                border: indexedRow.$1 == rows.length - 1
                    ? null
                    : Border(
                        bottom: BorderSide(color: theme.dividerSoft),
                      ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    indexedRow.$2.$1,
                    style: AppTypography.body(color: theme.secondaryInk),
                  ),
                  const Spacer(),
                  Text(
                    indexedRow.$2.$2,
                    style: AppTypography.metricInline(
                      color: theme.ink,
                      weight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
