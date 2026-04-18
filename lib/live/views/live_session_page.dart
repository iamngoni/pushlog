import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pushlog/core/configs/colors.dart';
import 'package:pushlog/core/configs/typography.dart';
import 'package:pushlog/workout/models/data/workout_preferences.dart';
import 'package:pushlog/workout/state/workout/workout_bloc.dart';

class LiveSessionPage extends StatefulWidget {
  const LiveSessionPage({super.key});

  @override
  State<LiveSessionPage> createState() =>
      _LiveSessionPageState();
}

class _LiveSessionPageState extends State<LiveSessionPage> {
  _LiveStep _step = _LiveStep.setup;
  late WorkoutPreferences _preferences;
  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  DateTime? _startedAt;
  int _reps = 0;
  int _manualAdjustments = 0;
  bool _isPaused = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_step == _LiveStep.setup) {
      final workoutState = context.read<WorkoutBloc>().state;
      if (workoutState is WorkoutLoaded) {
        _preferences = workoutState.preferences;
      }
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
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
          _LiveStep.tracking =>
            _buildTracking(context, theme),
          _LiveStep.summary => _buildSummary(context, theme),
        },
      ),
    );
  }

  Widget _buildSetup(BuildContext context, AppTheme theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          _TopBar(theme: theme, trailing: 'GUIDED LIVE'),
          const SizedBox(height: 28),
          Text(
            'LIVE',
            style: AppTypography.displayLarge(
              color: theme.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'TIMED SESSION MODE. START HERE, COUNT CLEAN, SAVE ONCE.',
            style: AppTypography.labelMono(
              size: 11,
              color: theme.secondaryInk,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 24),
          Divider(height: 1, color: theme.divider),
          const SizedBox(height: 24),
          _SelectorCard(
            title: 'DEVICE',
            detail:
                _preferences.liveDevicePreference ==
                        LiveDevicePreference.iphoneOnly
                    ? 'IPHONE ONLY'
                    : 'IPHONE + APPLE WATCH',
            theme: theme,
            children: [
              _DeviceOption(
                title: 'IPHONE ONLY',
                isSelected:
                    _preferences.liveDevicePreference ==
                        LiveDevicePreference.iphoneOnly,
                theme: theme,
                onTap: () => setState(() {
                  _preferences = _preferences.copyWith(
                    liveDevicePreference:
                        LiveDevicePreference.iphoneOnly,
                  );
                }),
              ),
              const SizedBox(height: 8),
              _DeviceOption(
                title: 'IPHONE + APPLE WATCH',
                isSelected:
                    _preferences.liveDevicePreference ==
                        LiveDevicePreference
                            .iphoneAndWatch,
                theme: theme,
                onTap: () => setState(() {
                  _preferences = _preferences.copyWith(
                    liveDevicePreference:
                        LiveDevicePreference
                            .iphoneAndWatch,
                  );
                }),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _SelectorCard(
            title: 'FLOW',
            detail: 'SAVE SESSION TO HISTORY',
            theme: theme,
            children: [
              Text(
                'THIS FLUTTER BUILD RESTORES THE SESSION TIMER AND SAVE PATH FIRST. CAMERA-GUIDED REP TRACKING WILL SIT ON TOP OF THIS FLOW.',
                style: AppTypography.labelMono(
                  size: 10,
                  color: theme.secondaryInk,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const Spacer(),
          _BottomPair(
            theme: theme,
            leading: 'EXIT',
            onLeadingTap: () => Navigator.of(context).pop(),
            trailing: 'START',
            onTrailingTap: _startSession,
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
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          _TopBar(theme: theme, trailing: 'SESSION'),
          const SizedBox(height: 24),
          Text(
            _formatDuration(_elapsed),
            style: AppTypography.displayMedium(
              color: theme.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _isPaused ? 'PAUSED' : 'RUNNING',
            style: AppTypography.labelMono(
              size: 11,
              color: _isPaused
                  ? theme.accentInk
                  : theme.secondaryInk,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 26),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              border: Border.all(color: theme.divider),
              color: theme.surface,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'TOTAL REPS',
                  style: AppTypography.labelMono(
                    color: theme.secondaryInk,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '$_reps',
                  style: AppTypography.displayLarge(
                    color: theme.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'MANUAL ADJUSTMENTS $_manualAdjustments',
                  style: AppTypography.labelMono(
                    size: 10,
                    color: theme.secondaryInk,
                    letterSpacing: 1.1,
                  ),
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
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          _TopBar(theme: theme, trailing: 'SUMMARY'),
          const SizedBox(height: 28),
          Text(
            '$_reps',
            style: AppTypography.displayLarge(
              color: theme.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'LIVE SESSION SAVES ONCE, AT THE END.',
            style: AppTypography.labelMono(
              size: 11,
              color: theme.secondaryInk,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 24),
          _SummaryCard(
            theme: theme,
            rows: [
              ('DURATION', _formatDuration(_elapsed)),
              ('SOURCE', 'LIVE SESSION'),
              (
                'DEVICE',
                _preferences.liveDevicePreference ==
                        LiveDevicePreference.iphoneOnly
                    ? 'IPHONE'
                    : 'IPHONE + WATCH',
              ),
              (
                'ADJUSTMENTS',
                '$_manualAdjustments',
              ),
            ],
          ),
          const Spacer(),
          _BottomPair(
            theme: theme,
            leading: 'DISCARD',
            onLeadingTap: () => Navigator.of(context).pop(),
            trailing: 'SAVE',
            onTrailingTap: () {
              context.read<WorkoutBloc>().add(
                    SaveLiveSessionEvent(
                      reps: _reps,
                      duration: _elapsed,
                      manualAdjustments:
                          _manualAdjustments,
                    ),
                  );
              Navigator.of(context).pop();
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _startSession() {
    context.read<WorkoutBloc>().add(
          UpdatePreferencesEvent(_preferences),
        );
    setState(() {
      _step = _LiveStep.tracking;
      _elapsed = Duration.zero;
      _reps = 0;
      _manualAdjustments = 0;
      _isPaused = false;
      _startedAt = DateTime.now();
    });
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
      },
    );
  }

  void _addReps(int value) {
    setState(() {
      _reps += value;
      _manualAdjustments += 1;
    });
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
    });
  }

  void _finishSession() {
    _ticker?.cancel();
    setState(() {
      _step = _LiveStep.summary;
    });
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    final seconds = duration.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    final hours = duration.inHours
        .toString()
        .padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }
}

enum _LiveStep { setup, tracking, summary }

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
          style: AppTypography.labelMono(
            color: theme.secondaryInk,
            letterSpacing: 3,
          ),
        ),
        Text(
          trailing,
          style: AppTypography.labelMono(
            color: theme.secondaryInk,
            letterSpacing: 1.5,
          ),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        border: Border.all(color: theme.divider),
        color: theme.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.labelMono(
              color: theme.secondaryInk,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            style: AppTypography.labelMono(
              size: 10,
              color: theme.ink,
              letterSpacing: 1.1,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
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
    return Material(
      color: isSelected ? theme.accent : theme.background,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected
                  ? theme.accent
                  : theme.divider,
            ),
          ),
          child: Text(
            title,
            style: AppTypography.labelMono(
              size: 11,
              color: isSelected
                  ? AppColors.fixedDark
                  : theme.ink,
              weight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
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
    return Row(
      children: [
        Expanded(
          child: _LiveFooterButton(
            title: leading,
            theme: theme,
            onTap: onLeadingTap,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _LiveFooterButton(
            title: trailing,
            theme: theme,
            emphasized: true,
            onTap: onTrailingTap,
          ),
        ),
      ],
    );
  }
}

class _LiveFooterButton extends StatelessWidget {
  const _LiveFooterButton({
    required this.title,
    required this.theme,
    required this.onTap,
    this.emphasized = false,
  });

  final String title;
  final AppTheme theme;
  final VoidCallback onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: emphasized ? theme.accent : theme.surface,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: 18,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: theme.divider),
          ),
          child: Center(
            child: Text(
              title,
              style: AppTypography.displayAction(
                color: emphasized
                    ? AppColors.fixedDark
                    : theme.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
    return Column(
      children: [
        Row(
          children: [
            for (final value in const [1, 10, 25]) ...[
              Expanded(
                child: _LiveFooterButton(
                  title: '+$value',
                  theme: theme,
                  emphasized: value == 1,
                  onTap: () => onAdd(value),
                ),
              ),
              if (value != 25) const SizedBox(width: 10),
            ],
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _LiveFooterButton(
                title: isPaused ? 'RESUME' : 'PAUSE',
                theme: theme,
                onTap: onPause,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _LiveFooterButton(
                title: 'END',
                theme: theme,
                emphasized: true,
                onTap: onEnd,
              ),
            ),
          ],
        ),
      ],
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
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: theme.divider),
        color: theme.surface,
      ),
      child: Column(
        children: [
          for (final indexedRow in rows.indexed)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 18,
              ),
              decoration: BoxDecoration(
                border: indexedRow.$1 == rows.length - 1
                    ? null
                    : Border(
                        bottom: BorderSide(
                          color: theme.divider,
                        ),
                      ),
              ),
              child: Row(
                children: [
                  Text(
                    indexedRow.$2.$1,
                    style: AppTypography.labelMono(
                      color: theme.ink,
                      letterSpacing: 1.6,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    indexedRow.$2.$2,
                    style: AppTypography.labelMono(
                      size: 10,
                      color: theme.secondaryInk,
                      letterSpacing: 1.1,
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
