import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pushlog/core/configs/colors.dart';
import 'package:pushlog/core/configs/motion.dart';
import 'package:pushlog/core/configs/spacing.dart';
import 'package:pushlog/core/configs/typography.dart';
import 'package:pushlog/core/views/widgets/pushlog_button.dart';
import 'package:pushlog/core/views/widgets/pushlog_confirm_dialog.dart';
import 'package:pushlog/core/views/widgets/pushlog_surface.dart';
import 'package:pushlog/injection.dart';
import 'package:pushlog/live/services/face_tracking_service.dart';
import 'package:pushlog/platform/health/health_service.dart';
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
  Timer? _countdownTimer;
  StreamSubscription<FaceTrackingSnapshot>? _faceSubscription;
  StreamSubscription<WatchStatus>? _watchSubscription;
  FaceTrackingSnapshot _faceSnapshot = const FaceTrackingSnapshot();
  WatchStatus _watchStatus = const WatchStatus.unsupported();
  HealthKitWriteOwner _healthKitWriteOwner = HealthKitWriteOwner.phone;
  Duration _elapsed = Duration.zero;
  DateTime? _startedAt;
  String? _sessionId;
  int _reps = 0;
  int _manualAdjustments = 0;
  bool _isPaused = false;
  bool _usesAutoTracking = false;
  int? _countdownValue;
  bool _didLoadWatchStatus = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_step == _LiveStep.setup) {
      final workoutState = context.read<WorkoutBloc>().state;
      if (workoutState is WorkoutLoaded) {
        _preferences = workoutState.preferences;
      }
      if (!_didLoadWatchStatus) {
        _didLoadWatchStatus = true;
        unawaited(_refreshWatchStatus());
      }
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _countdownTimer?.cancel();
    unawaited(_faceSubscription?.cancel());
    unawaited(_watchSubscription?.cancel());
    if (_usesAutoTracking) {
      unawaited(getIt<FaceTrackingService>().stop());
    }
    if (_sessionId != null && _step != _LiveStep.summary) {
      unawaited(
        getIt<WatchService>().cancelLiveWorkout(sessionId: _sessionId!),
      );
    }
    super.dispose();
  }

  /// Whether leaving now would throw away counted reps.
  ///
  /// Past setup, [dispose] cancels the session outright, and the summary
  /// step holds reps that only Save commits — so in both cases walking out
  /// is a discard, whether or not the user meant it as one.
  bool get _hasUnsavedReps => _reps > 0 && _step != _LiveStep.setup;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    // A back gesture mid-session used to destroy it silently. The reps are
    // the one thing here that cannot be recreated, so the gesture has to
    // pass the same question the Discard button does.
    return PopScope(
      canPop: !_hasUnsavedReps,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        unawaited(_confirmLeave(context));
      },
      child: Scaffold(
        backgroundColor: theme.background,
        body: SafeArea(
          child: switch (_step) {
            _LiveStep.setup => _buildSetup(context, theme),
            _LiveStep.preflight => _buildPreflight(context, theme),
            _LiveStep.tracking => _buildTracking(context, theme),
            _LiveStep.summary => _buildSummary(context, theme),
          },
        ),
      ),
    );
  }

  Widget _buildSetup(BuildContext context, AppTheme theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.block),
          _TopBar(theme: theme, trailing: 'GUIDED LIVE'),
          const SizedBox(height: AppSpacing.section),
          Text(
            'Live',
            style: AppTypography.headingXLarge(color: theme.ink),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Timed session mode. Start here, count clean, save once.',
            style: AppTypography.bodyLarge(color: theme.secondaryInk),
          ),
          const SizedBox(height: AppSpacing.block),
          Divider(height: 1, color: theme.divider),
          const SizedBox(height: AppSpacing.block),
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
              const SizedBox(height: AppSpacing.md),
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
          const SizedBox(height: AppSpacing.xxl),
          _SelectorCard(
            title: 'FLOW',
            detail: 'Camera auto-count',
            theme: theme,
            children: [
              Text(
                'Lay your phone on the floor, screen up, under your chest. '
                'The front camera watches your face and counts as you go. '
                'If it is unavailable, add reps manually instead.',
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
          const SizedBox(height: AppSpacing.block),
        ],
      ),
    );
  }

  Widget _buildPreflight(BuildContext context, AppTheme theme) {
    final countdown = _countdownValue;
    final camera = getIt<FaceTrackingService>().cameraController;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.block),
          _TopBar(theme: theme, trailing: 'PRE-FLIGHT'),
          const SizedBox(height: AppSpacing.section),
          if (camera != null && camera.value.isInitialized) ...[
            _CameraPreviewFrame(controller: camera, theme: theme),
            const SizedBox(height: AppSpacing.block),
          ],
          Text(
            countdown?.toString() ?? _preflightHeadline(_faceSnapshot),
            style: AppTypography.metricXLarge(color: theme.ink),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            _faceSnapshot.guidance,
            style: AppTypography.bodyLarge(color: theme.secondaryInk),
          ),
          const SizedBox(height: AppSpacing.block),
          _SelectorCard(
            title: 'RANGE',
            detail: _faceSnapshot.isReadyToCount ? 'Set' : 'Measuring',
            theme: theme,
            children: [
              Text(
                _rangeDetail(_faceSnapshot),
                style: AppTypography.body(color: theme.secondaryInk),
              ),
              // Calibration reads whatever position was held, so it can lock
              // onto the wrong one. Without this the only way out is
              // abandoning the session.
              if (_faceSnapshot.isReadyToCount && countdown == null) ...[
                const SizedBox(height: AppSpacing.lg),
                PushlogButton(
                  label: 'Measure again',
                  variant: PushlogButtonVariant.ghost,
                  onPressed: () {
                    setState(() {
                      _faceSnapshot = getIt<FaceTrackingService>()
                          .recalibrate();
                    });
                  },
                ),
              ],
            ],
          ),
          const Spacer(),
          _BottomPair(
            theme: theme,
            leading: 'Manual',
            onLeadingTap: _fallbackToManual,
            // Begin stays inert until the range is set. Starting without a
            // baseline would run a session that silently counts nothing.
            trailing: countdown != null
                ? 'Starting…'
                : _faceSnapshot.isReadyToCount
                ? 'Begin'
                : 'Hold',
            onTrailingTap: countdown == null && _faceSnapshot.isReadyToCount
                ? _beginCountdown
                : () {},
          ),
          const SizedBox(height: AppSpacing.block),
        ],
      ),
    );
  }

  String _preflightHeadline(FaceTrackingSnapshot snapshot) =>
      switch (snapshot.phase) {
        FaceTrackingPhase.ready => 'Ready',
        FaceTrackingPhase.calibrating => 'Hold still',
        FaceTrackingPhase.searching => 'Get in position',
        _ => 'Starting…',
      };

  String _rangeDetail(FaceTrackingSnapshot snapshot) {
    if (!snapshot.isReadyToCount) {
      return 'Get into the top of a push-up over the phone and hold, so '
          'the camera can learn how far away that is.';
    }
    final ratio = snapshot.sizeRatio;
    if (ratio == null) return 'Top of the rep measured.';
    return 'Top of the rep measured. You are at '
        '${(ratio * 100).round()}% of that now.';
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
          const SizedBox(height: AppSpacing.block),
          _TopBar(theme: theme, trailing: 'SESSION'),
          const SizedBox(height: AppSpacing.block),
          Text(
            _formatDuration(_elapsed),
            style: AppTypography.metricXLarge(color: theme.ink),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _usesAutoTracking
                ? _faceSnapshot.guidance
                : _isPaused
                ? 'Paused'
                : 'Running',
            style: AppTypography.bodyLarge(
              color: _isPaused ? theme.accentInk : theme.secondaryInk,
            ),
          ),
          const SizedBox(height: AppSpacing.block),
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
                const SizedBox(height: AppSpacing.xl),
                Text(
                  '$_reps',
                  style: AppTypography.metricHero(color: theme.ink),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Manual adjustments: $_manualAdjustments',
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
          const SizedBox(height: AppSpacing.block),
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
          const SizedBox(height: AppSpacing.block),
          _TopBar(theme: theme, trailing: 'SUMMARY'),
          const SizedBox(height: AppSpacing.section),
          Text(
            '$_reps',
            style: AppTypography.metricHero(color: theme.ink),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Live sessions save once, at the end.',
            style: AppTypography.bodyLarge(color: theme.secondaryInk),
          ),
          const SizedBox(height: AppSpacing.block),
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
              unawaited(_confirmDiscard(context));
            },
            trailing: 'Save',
            onTrailingTap: () {
              unawaited(_saveSession(context));
            },
          ),
          const SizedBox(height: AppSpacing.block),
        ],
      ),
    );
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
    final service = getIt<FaceTrackingService>();
    await _faceSubscription?.cancel();
    _faceSubscription = service.snapshots.listen(_handleFaceSnapshot);
    final snapshot = await service.start();
    if (!mounted) return;
    setState(() {
      _faceSnapshot = snapshot;
    });

    if (!snapshot.isUsable) {
      await _faceSubscription?.cancel();
      _faceSubscription = null;
      _startSession(usesAutoTracking: false);
      return;
    }

    setState(() {
      _step = _LiveStep.preflight;
      _usesAutoTracking = true;
    });
  }

  /// Bails from pre-flight to manual entry, releasing the camera first so it
  /// is not left running in the background.
  void _fallbackToManual() {
    unawaited(_faceSubscription?.cancel());
    _faceSubscription = null;
    unawaited(getIt<FaceTrackingService>().stop());
    _startSession(usesAutoTracking: false);
  }

  /// A local 3-2-1 between the range being set and reps counting, so the user
  /// can settle at the top rather than being caught mid-movement. The camera
  /// keeps running throughout; arming happens at zero, and it discards
  /// anything counted during setup.
  void _beginCountdown() {
    if (_countdownValue != null) return;
    setState(() => _countdownValue = 3);
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final next = (_countdownValue ?? 1) - 1;
      if (next <= 0) {
        timer.cancel();
        setState(() => _countdownValue = null);
        getIt<FaceTrackingService>().beginCounting();
        _startSession(usesAutoTracking: true);
        return;
      }
      setState(() => _countdownValue = next);
    });
  }

  void _handleFaceSnapshot(FaceTrackingSnapshot snapshot) {
    if (!mounted) return;
    setState(() {
      _faceSnapshot = snapshot;
      // Reps are only mirrored once the session is live. A rep thrown while
      // the user is still settling into position is discarded by
      // beginCounting, and surfacing it before then would make backing out
      // of pre-flight ask about discarding work that was never counted.
      if (_step == _LiveStep.tracking) {
        _reps = snapshot.reps;
        _manualAdjustments = snapshot.manualAdjustments;
        _isPaused = snapshot.isPaused;
      }
    });
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
            ? _faceSnapshot.phase.name.toUpperCase()
            : 'MANUAL',
        isPaused: _isPaused,
      ),
    );
  }

  void _addReps(int value) {
    if (_usesAutoTracking) {
      getIt<FaceTrackingService>().addManualReps(value);
      return;
    }

    setState(() {
      _reps += value;
      _manualAdjustments += 1;
    });
  }

  void _togglePause() {
    if (_usesAutoTracking) {
      final service = getIt<FaceTrackingService>();
      if (service.snapshot.isPaused) {
        service.resume();
      } else {
        service.pause();
      }
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
      final finished = await getIt<FaceTrackingService>().stop();
      if (!mounted) return;
      setState(() {
        _faceSnapshot = finished;
        _reps = finished.reps;
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
    final avgRepDuration = _reps <= 0
        ? null
        : Duration(
            microseconds: _elapsed.inMicroseconds ~/ _reps,
          );

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

  /// Asks before throwing the session away, naming what is being lost.
  ///
  /// A bare count is the honest measure here: the user just did the work,
  /// and 'your session' does not carry the same weight as the number.
  Future<bool> _askToDiscard(BuildContext context) {
    return PushlogConfirmDialog.ask(
      context,
      title: 'Discard $_reps ${_reps == 1 ? 'rep' : 'reps'}?',
      message:
          'This session will not be saved to your history, and the reps '
          'cannot be recovered.',
      confirmLabel: 'Discard',
    );
  }

  Future<void> _confirmDiscard(BuildContext context) async {
    if (_reps > 0) {
      final confirmed = await _askToDiscard(context);
      if (!confirmed || !context.mounted) return;
    }
    await _discardSession(context);
  }

  /// The back-gesture path.
  ///
  /// Only the summary step needs the stopped workout cleared explicitly —
  /// before that, [dispose] cancels the live one on the way out.
  Future<void> _confirmLeave(BuildContext context) async {
    final confirmed = await _askToDiscard(context);
    if (!confirmed || !context.mounted) return;
    if (_step == _LiveStep.summary) {
      await _discardSession(context);
      return;
    }
    Navigator.of(context).pop();
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

/// Lets the user confirm framing before a session starts.
///
/// Camera preview sizes are reported in landscape terms even in a portrait
/// layout, so the aspect ratio is inverted rather than used as-is —
/// otherwise the feed renders stretched.
class _CameraPreviewFrame extends StatelessWidget {
  const _CameraPreviewFrame({required this.controller, required this.theme});

  final CameraController controller;
  final AppTheme theme;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadius.all(AppRadius.sm),
      child: DecoratedBox(
        decoration: BoxDecoration(border: Border.all(color: theme.divider)),
        child: AspectRatio(
          aspectRatio: 1 / controller.value.aspectRatio,
          child: CameraPreview(controller),
        ),
      ),
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
