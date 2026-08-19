//
//  pushlog
//  action_strip.dart
//
//  Created by Ngonidzashe Mangudya on 2026/04/16.
//  Copyright (c) 2026 Codecraft Solutions. All rights reserved.
//

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pushlog/core/configs/colors.dart';
import 'package:pushlog/core/configs/motion.dart';
import 'package:pushlog/core/configs/spacing.dart';
import 'package:pushlog/core/configs/typography.dart';

/// The persistent logging bar.
///
/// Three cells, not four. The fourth used to open a live session, which is
/// the same destination as the labelled button at the top of the screen —
/// two entry points to one place, with the duplicate reduced to a four-
/// character label in the smallest control on the page. Dropping it gives
/// the remaining cells room to be comfortably tappable, and leaves the strip
/// doing one job: recording reps that were already done.
class ActionStrip extends StatelessWidget {
  const ActionStrip({
    required this.theme,
    required this.onAddReps,
    this.suggestedSet,
    super.key,
  });

  final AppTheme theme;
  final void Function(int reps) onAddReps;

  /// Reps in one set of today's plan. Null on a recovery day.
  final int? suggestedSet;

  @override
  Widget build(BuildContext context) {
    final planned = suggestedSet ?? 10;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.lg,
        AppSpacing.gutter,
        AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: theme.background,
        border: Border(top: BorderSide(color: theme.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: ActionCell(
              reps: 1,
              theme: theme,
              onTap: () => onAddReps(1),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          // The only Signal Lime on the screen while the target is
          // outstanding. This is the next action.
          Expanded(
            flex: 2,
            child: ActionCell(
              reps: planned,
              caption: suggestedSet == null ? null : 'One set',
              emphasized: true,
              theme: theme,
              onTap: () => onAddReps(planned),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: ActionCell(
              reps: 25,
              theme: theme,
              onTap: () => onAddReps(25),
            ),
          ),
        ],
      ),
    );
  }
}

/// One hold-to-log cell.
///
/// This strip sits permanently under the thumb, directly above the system
/// navigation bar, so a brush while scrolling or pocketing the phone used to
/// be enough to write reps the user never did — and a log that cannot be
/// trusted makes every number downstream of it worthless.
///
/// A press therefore has to be sustained for [holdDuration], and the cell
/// fills as it goes so the wait is visible rather than mysterious. Haptics
/// mark the whole arc: a light tap on contact, ticks as the fill crosses,
/// and a commit thump when it lands.
class ActionCell extends StatefulWidget {
  const ActionCell({
    required this.reps,
    required this.theme,
    required this.onTap,
    this.caption,
    this.emphasized = false,
    this.isEnabled = true,
    super.key,
  });

  /// How long the cell must be held before it logs.
  static const Duration holdDuration = Duration(seconds: 3);

  /// Haptic ticks spread across the hold, not counting the commit.
  static const int _tickCount = 3;

  final int reps;
  final String? caption;
  final bool emphasized;
  final bool isEnabled;
  final AppTheme theme;
  final VoidCallback onTap;

  @override
  State<ActionCell> createState() => _ActionCellState();
}

class _ActionCellState extends State<ActionCell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  int _ticksFired = 0;
  bool _isHolding = false;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
            vsync: this,
            // Not routed through AppMotion: this is a safety delay, not
            // decoration, so reduced-motion must not shorten it to zero and
            // hand back the accidental taps it exists to prevent.
            duration: ActionCell.holdDuration,
          )
          ..addListener(_onProgress)
          ..addStatusListener(_onStatus);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onProgress() {
    // Ticks at even fractions, so the hold has a felt rhythm instead of
    // three silent seconds where nothing seems to be happening.
    final fired = (_controller.value * ActionCell._tickCount).floor();
    if (fired > _ticksFired && fired < ActionCell._tickCount) {
      _ticksFired = fired;
      AppHaptics.tick();
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    AppHaptics.commit();
    widget.onTap();
    // Snap empty rather than draining: the reps are already logged, and a
    // fill unwinding afterwards would read as the action coming undone.
    _controller.value = 0;
    _ticksFired = 0;
    if (mounted) setState(() => _isHolding = false);
  }

  void _startHold() {
    if (!widget.isEnabled) return;
    _ticksFired = 0;
    AppHaptics.tap();
    setState(() => _isHolding = true);
    unawaited(_controller.forward(from: 0));
  }

  void _cancelHold() {
    if (_isHolding) setState(() => _isHolding = false);
    if (_controller.value == 0) return;
    _ticksFired = 0;
    // Drain rather than snap, so letting go early reads as releasing a
    // control instead of the fill being yanked away.
    unawaited(_controller.reverse());
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final ink = widget.emphasized ? theme.onAccent : theme.ink;
    final subInk = widget.emphasized ? theme.onAccentMuted : theme.secondaryInk;

    final base = widget.emphasized ? theme.accent : theme.surface;
    // The lime cell is already the accent, so it darkens as it charges;
    // the quiet cells fill *with* the accent instead.
    final fill = widget.emphasized
        ? theme.onAccent.withValues(alpha: 0.18)
        : theme.accent;

    return Semantics(
      button: true,
      enabled: widget.isEnabled,
      label: 'Log ${widget.reps} reps',
      hint: 'Hold to log',
      // Assistive tech activates with a double tap, not a sustained press,
      // and a pocket brush is not the failure mode for someone driving the
      // screen with TalkBack — so the semantic action logs immediately
      // rather than leaving the control unreachable.
      onTap: widget.isEnabled ? widget.onTap : null,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _startHold(),
        onTapUp: (_) => _cancelHold(),
        onTapCancel: _cancelHold,
        child: AnimatedOpacity(
          opacity: widget.isEnabled ? 1 : 0.4,
          duration: AppMotion.duration(context, AppMotion.fast),
          child: AnimatedScale(
            scale: _isHolding ? 0.97 : 1,
            duration: AppMotion.duration(context, AppMotion.instant),
            curve: AppMotion.settle,
            child: SizedBox(
              height: AppSpacing.controlHeight,
              child: ClipRRect(
                borderRadius: AppRadius.all(AppRadius.md),
                child: Stack(
                  children: [
                    Positioned.fill(child: ColoredBox(color: base)),
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: _controller,
                        builder: (context, _) => Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: _controller.value,
                            heightFactor: 1,
                            child: ColoredBox(color: fill),
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '+${widget.reps}',
                              style: AppTypography.metricCompact(color: ink),
                            ),
                            if (widget.caption != null) ...[
                              const SizedBox(height: AppSpacing.xxs),
                              Text(
                                widget.caption!,
                                style: AppTypography.labelSmall(color: subInk),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
