//
//  pushlog
//  pushlog_toast.dart
//
//  Created by Ngonidzashe Mangudya on 2026/04/16.
//  Copyright (c) 2026 Codecraft Solutions. All rights reserved.
//

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pushlog/core/configs/colors.dart';
import 'package:pushlog/core/configs/elevation.dart';
import 'package:pushlog/core/configs/motion.dart';
import 'package:pushlog/core/configs/spacing.dart';
import 'package:pushlog/core/configs/typography.dart';

/// What a toast is telling the user.
///
/// Each tone carries an icon and a shape as well as a colour, so the
/// message still lands for anyone who cannot separate lime from amber.
enum PushlogToastTone {
  /// Work was recorded, a plan was saved, a request went through.
  success,

  /// Neutral acknowledgement. Deliberately uncoloured — an ordinary
  /// confirmation has no business competing with the day's target.
  info,

  /// The action did not happen, and the user has to change something.
  warning,

  /// Something failed. Always paired with what to do next.
  danger,
}

/// An in-app message.
///
/// Toasts appear at the top of the screen. The bottom belongs to the action
/// strip and the tab bar — the exact region a thumb occupies mid-set — and
/// a bar that slides in under a finger that is tapping "+10" either gets
/// dismissed by accident or swallows the tap.
@immutable
class PushlogToastData {
  const PushlogToastData({
    required this.message,
    this.detail,
    this.tone = PushlogToastTone.info,
    this.actionLabel,
    this.onAction,
    this.duration,
  });

  /// One line, sentence case, no trailing period.
  final String message;

  /// Optional second line explaining the consequence or the way forward.
  final String? detail;

  final PushlogToastTone tone;

  /// Label for the inline action. Requires [onAction].
  final String? actionLabel;

  final VoidCallback? onAction;

  /// Defaults to [AppMotion.toastShort], or [AppMotion.toastLong] when
  /// there is an action worth reading before it disappears.
  final Duration? duration;

  Duration get resolvedDuration =>
      duration ??
      (actionLabel != null ? AppMotion.toastLong : AppMotion.toastShort);
}

/// Shows in-app messages.
///
/// Replaces `ScaffoldMessenger.showSnackBar`. A `SnackBar` docks to the
/// bottom of the nearest `Scaffold`, inherits Material's shape and motion,
/// and cannot be told to avoid the action strip. This routes through the
/// root overlay instead, so one message renders identically on every screen
/// and always floats clear of the controls underneath it.
class PushlogToast {
  const PushlogToast._();

  static final ValueNotifier<_ToastRequest?> _request =
      ValueNotifier<_ToastRequest?>(null);

  static OverlayEntry? _entry;
  static int _sequence = 0;

  /// Work landed.
  static void success(
    BuildContext context,
    String message, {
    String? detail,
    String? actionLabel,
    VoidCallback? onAction,
    Duration? duration,
  }) => show(
    context,
    PushlogToastData(
      message: message,
      detail: detail,
      tone: PushlogToastTone.success,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    ),
  );

  /// Neutral acknowledgement.
  static void info(
    BuildContext context,
    String message, {
    String? detail,
    String? actionLabel,
    VoidCallback? onAction,
    Duration? duration,
  }) => show(
    context,
    PushlogToastData(
      message: message,
      detail: detail,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    ),
  );

  /// The action was refused and the user has to change something.
  static void warning(
    BuildContext context,
    String message, {
    String? detail,
    String? actionLabel,
    VoidCallback? onAction,
    Duration? duration,
  }) => show(
    context,
    PushlogToastData(
      message: message,
      detail: detail,
      tone: PushlogToastTone.warning,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    ),
  );

  /// Something failed.
  static void danger(
    BuildContext context,
    String message, {
    String? detail,
    String? actionLabel,
    VoidCallback? onAction,
    Duration? duration,
  }) => show(
    context,
    PushlogToastData(
      message: message,
      detail: detail,
      tone: PushlogToastTone.danger,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    ),
  );

  static void show(BuildContext context, PushlogToastData data) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    switch (data.tone) {
      case PushlogToastTone.success:
        AppHaptics.commit();
      case PushlogToastTone.info:
        AppHaptics.tap();
      case PushlogToastTone.warning:
      case PushlogToastTone.danger:
        AppHaptics.warn();
    }

    _request.value = _ToastRequest(id: ++_sequence, data: data);

    if (_entry == null) {
      _entry = OverlayEntry(builder: (_) => const _ToastHost());
      overlay.insert(_entry!);
    }
  }

  /// Removes the visible toast, if any.
  static void dismiss() => _request.value = null;

  static void _teardown() {
    _entry?.remove();
    _entry = null;
  }

  /// Drops the reference to a host that is going away on its own.
  ///
  /// The overlay a toast lives in can be torn down underneath it — a route
  /// change, a rebuild of the root. Without this the static entry would
  /// still point at a dead overlay, `show` would decide a toast was already
  /// on screen, and no message would ever appear again.
  static void _forget() {
    _entry = null;
    _request.value = null;
  }
}

@immutable
class _ToastRequest {
  const _ToastRequest({required this.id, required this.data});

  final int id;
  final PushlogToastData data;
}

class _ToastHost extends StatefulWidget {
  const _ToastHost();

  @override
  State<_ToastHost> createState() => _ToastHostState();
}

class _ToastHostState extends State<_ToastHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _fade;
  late final CurvedAnimation _slide;
  Timer? _timer;
  int? _visibleId;
  PushlogToastData? _data;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.slow,
      reverseDuration: AppMotion.fast,
    );
    // Built once and disposed with the host. Creating a CurvedAnimation in
    // build would attach a fresh listener to the controller on every frame
    // and never release it.
    _fade = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
      reverseCurve: AppMotion.exit,
    );
    _slide = CurvedAnimation(
      parent: _controller,
      curve: AppMotion.enter,
      reverseCurve: AppMotion.exit,
    );
    PushlogToast._request.addListener(_onRequest);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The pending request is picked up here rather than in initState:
    // resolving the animation duration reads the reduced-motion setting off
    // MediaQuery, and inherited widgets cannot be looked up until
    // dependencies are available. _onRequest is idempotent for an id it has
    // already shown, so running it again on a dependency change is safe.
    _onRequest();
  }

  @override
  void dispose() {
    PushlogToast._request.removeListener(_onRequest);
    _timer?.cancel();
    _fade.dispose();
    _slide.dispose();
    _controller.dispose();
    PushlogToast._forget();
    super.dispose();
  }

  void _onRequest() {
    final request = PushlogToast._request.value;
    if (request == null) {
      unawaited(_hide());
      return;
    }
    if (request.id == _visibleId) return;

    setState(() {
      _visibleId = request.id;
      _data = request.data;
    });

    _controller
      ..duration = AppMotion.duration(context, AppMotion.slow)
      ..reverseDuration = AppMotion.duration(context, AppMotion.fast);
    unawaited(_controller.forward(from: 0));

    _timer?.cancel();
    _timer = Timer(request.data.resolvedDuration, () {
      if (PushlogToast._request.value?.id == request.id) {
        PushlogToast.dismiss();
      }
    });
  }

  Future<void> _hide() async {
    _timer?.cancel();
    if (!mounted || _data == null) {
      PushlogToast._teardown();
      return;
    }
    await _controller.reverse();
    if (!mounted) return;
    _visibleId = null;
    _data = null;
    PushlogToast._teardown();
  }

  void _handleAction(PushlogToastData data) {
    PushlogToast.dismiss();
    data.onAction?.call();
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    if (data == null) return const SizedBox.shrink();

    final theme = AppTheme.of(context);
    final reduced = AppMotion.isReduced(context);
    final media = MediaQuery.of(context);

    return Positioned(
      top: media.padding.top + AppSpacing.md,
      left: AppSpacing.lg,
      right: AppSpacing.lg,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppSpacing.proseMaxWidth,
          ),
          child: FadeTransition(
            opacity: _fade,
            child: AnimatedBuilder(
              animation: _slide,
              builder: (context, child) {
                if (reduced) return child!;
                return Transform.translate(
                  offset: Offset(0, -28 * (1 - _slide.value)),
                  child: Transform.scale(
                    scale: 0.97 + 0.03 * _slide.value,
                    alignment: Alignment.topCenter,
                    child: child,
                  ),
                );
              },
              child: Dismissible(
                key: ValueKey<int>(_visibleId ?? 0),
                direction: DismissDirection.up,
                onDismissed: (_) => PushlogToast.dismiss(),
                child: _ToastCard(
                  data: data,
                  theme: theme,
                  onAction: () => _handleAction(data),
                  onClose: PushlogToast.dismiss,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToastCard extends StatelessWidget {
  const _ToastCard({
    required this.data,
    required this.theme,
    required this.onAction,
    required this.onClose,
  });

  final PushlogToastData data;
  final AppTheme theme;
  final VoidCallback onAction;
  final VoidCallback onClose;

  ({Color ink, Color wash, IconData icon}) get _tone => switch (data.tone) {
    PushlogToastTone.success => (
      ink: theme.accentInk,
      wash: theme.accentSoft,
      icon: Icons.check_rounded,
    ),
    PushlogToastTone.info => (
      ink: theme.ink,
      wash: theme.surfaceSunken,
      icon: Icons.info_rounded,
    ),
    PushlogToastTone.warning => (
      ink: theme.warning,
      wash: theme.warningSoft,
      icon: Icons.priority_high_rounded,
    ),
    PushlogToastTone.danger => (
      ink: theme.danger,
      wash: theme.dangerSoft,
      icon: Icons.close_rounded,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final tone = _tone;
    final hasAction = data.actionLabel != null && data.onAction != null;

    return Semantics(
      liveRegion: true,
      container: true,
      label: data.detail == null
          ? data.message
          : '${data.message}. ${data.detail}',
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          // Tapping anywhere that is not the action dismisses. Together
          // with swipe-up that covers getting rid of the thing, so the card
          // does not need a close button competing with Undo for the same
          // trailing corner.
          onTap: onClose,
          child: Container(
            decoration: BoxDecoration(
              color: theme.surfaceRaised,
              borderRadius: AppRadius.all(AppRadius.lg),
              boxShadow: AppElevation.lifted(theme),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // A stripe rather than a full border: it names the
                      // tone without boxing the message in a second
                      // outline.
                      Container(width: 4, color: tone.ink),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xl,
                            vertical: AppSpacing.lg,
                          ),
                          child: Row(
                            children: [
                              _ToneBadge(tone: tone),
                              const SizedBox(width: AppSpacing.lg),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      data.message,
                                      style: AppTypography.title(
                                        color: theme.ink,
                                      ),
                                    ),
                                    if (data.detail != null) ...[
                                      const SizedBox(height: AppSpacing.xxs),
                                      Text(
                                        data.detail!,
                                        style: AppTypography.bodySmall(
                                          color: theme.secondaryInk,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              // Inline and right-aligned, which is what
                              // every undo toast worth copying does.
                              // Stacking it under the message turns a
                              // one-line confirmation into a three-row
                              // block for no gain.
                              if (hasAction) ...[
                                const SizedBox(width: AppSpacing.lg),
                                _ToastAction(
                                  label: data.actionLabel!,
                                  ink: tone.ink,
                                  onTap: onAction,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _TimeRemaining(
                  total: data.resolvedDuration,
                  color: tone.ink,
                  track: theme.dividerSoft,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ToneBadge extends StatelessWidget {
  const _ToneBadge({required this.tone});

  final ({Color ink, Color wash, IconData icon}) tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tone.wash,
        borderRadius: AppRadius.all(AppRadius.xs),
      ),
      // The icon is a solid shape and reads heavier than the text beside
      // it, so it sits at 18pt rather than matching the title's cap height.
      child: Icon(tone.icon, size: 18, color: tone.ink),
    );
  }
}

class _ToastAction extends StatelessWidget {
  const _ToastAction({
    required this.label,
    required this.ink,
    required this.onTap,
  });

  final String label;
  final Color ink;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(
            minWidth: AppSpacing.minTapTarget,
            minHeight: AppSpacing.minTapTarget,
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(label, style: AppTypography.title(color: ink)),
        ),
      ),
    );
  }
}

/// The hairline that drains while the toast is on screen.
///
/// It answers "is this about to vanish?" without the user having to guess,
/// which matters when the message carries an Undo.
class _TimeRemaining extends StatefulWidget {
  const _TimeRemaining({
    required this.total,
    required this.color,
    required this.track,
  });

  final Duration total;
  final Color color;
  final Color track;

  @override
  State<_TimeRemaining> createState() => _TimeRemainingState();
}

class _TimeRemainingState extends State<_TimeRemaining>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drain;

  @override
  void initState() {
    super.initState();
    _drain = AnimationController(vsync: this, duration: widget.total);
    unawaited(_drain.forward());
  }

  @override
  void dispose() {
    _drain.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AppMotion.isReduced(context)) {
      // A ticking bar is itself motion. Without it the toast still
      // dismisses on the same timer; only the countdown is hidden.
      return const SizedBox.shrink();
    }
    return AnimatedBuilder(
      animation: _drain,
      builder: (context, _) {
        return LinearProgressIndicator(
          minHeight: 2,
          value: 1 - _drain.value,
          color: widget.color,
          backgroundColor: widget.track,
        );
      },
    );
  }
}
