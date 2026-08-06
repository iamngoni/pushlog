//
//  pushlog
//  pushlog_button.dart
//
//  Created by Ngonidzashe Mangudya on 2026/04/16.
//  Copyright (c) 2026 Codecraft Solutions. All rights reserved.
//

import 'package:flutter/material.dart';
import 'package:pushlog/core/configs/colors.dart';
import 'package:pushlog/core/configs/motion.dart';
import 'package:pushlog/core/configs/spacing.dart';
import 'package:pushlog/core/configs/typography.dart';

/// Where a control sits in the page's action pyramid.
///
/// A screen gets one [primary]. If two things on a page are both filled
/// with Signal Lime, neither of them is the next action any more.
enum PushlogButtonVariant {
  /// Signal Lime. The one thing the screen wants the user to do.
  primary,

  /// Solid neutral. A real action, but not *the* action.
  secondary,

  /// Outline only. Available, unemphasised.
  ghost,

  /// Destructive. Only ever primary inside its own confirmation dialog —
  /// on the page that offers it, it stays quiet.
  danger,
}

enum PushlogButtonSize { small, medium, large }

/// Adds press feedback to any child.
///
/// Flutter's ink ripple washes out on the large flat cells this app uses,
/// so touches register as a slight settle instead: the control dips toward
/// the page under a finger and springs back on release.
class PressFeedback extends StatefulWidget {
  const PressFeedback({
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.enabled = true,
    this.scale = 0.97,
    this.semanticLabel,
    this.behavior = HitTestBehavior.opaque,
    this.haptic,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool enabled;
  final double scale;
  final String? semanticLabel;
  final HitTestBehavior behavior;

  /// Feedback fired on a completed tap. Defaults to [AppHaptics.tap]; pass
  /// [AppHaptics.tick] for rep logging or a no-op to stay silent.
  final VoidCallback? haptic;

  @override
  State<PressFeedback> createState() => _PressFeedbackState();
}

class _PressFeedbackState extends State<PressFeedback> {
  bool _pressed = false;

  bool get _active => widget.enabled && widget.onTap != null;

  void _set(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final child = AnimatedScale(
      scale: _pressed && _active ? widget.scale : 1,
      duration: AppMotion.duration(context, AppMotion.instant),
      curve: AppMotion.settle,
      child: AnimatedOpacity(
        opacity: widget.enabled ? 1 : 0.4,
        duration: AppMotion.duration(context, AppMotion.fast),
        child: widget.child,
      ),
    );

    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: widget.behavior,
        onTapDown: _active ? (_) => _set(true) : null,
        onTapUp: _active ? (_) => _set(false) : null,
        onTapCancel: _active ? () => _set(false) : null,
        onTap: _active
            ? () {
                (widget.haptic ?? AppHaptics.tap)();
                widget.onTap!.call();
              }
            : null,
        onLongPress: widget.enabled ? widget.onLongPress : null,
        child: child,
      ),
    );
  }
}

/// The app's button.
class PushlogButton extends StatelessWidget {
  const PushlogButton({
    required this.label,
    required this.onPressed,
    this.variant = PushlogButtonVariant.primary,
    this.size = PushlogButtonSize.large,
    this.icon,
    this.trailing,
    this.isLoading = false,
    this.expand = true,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final PushlogButtonVariant variant;
  final PushlogButtonSize size;
  final IconData? icon;

  /// Rendered at the far end of the button — a count, a chevron.
  final Widget? trailing;

  /// Swaps the label for a spinner and blocks input.
  final bool isLoading;

  /// False lets the button size to its content.
  final bool expand;

  double get _height => switch (size) {
    PushlogButtonSize.small => AppSpacing.minTapTarget,
    PushlogButtonSize.medium => 48,
    PushlogButtonSize.large => AppSpacing.controlHeight,
  };

  double get _radius => switch (size) {
    PushlogButtonSize.small => AppRadius.sm,
    PushlogButtonSize.medium => AppRadius.md,
    PushlogButtonSize.large => AppRadius.lg,
  };

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final enabled = onPressed != null && !isLoading;

    final (Color background, Color foreground, Color? border) =
        switch (variant) {
          PushlogButtonVariant.primary => (
            theme.accent,
            theme.onAccent,
            null,
          ),
          PushlogButtonVariant.secondary => (
            theme.ink,
            theme.background,
            null,
          ),
          PushlogButtonVariant.ghost => (
            Colors.transparent,
            theme.ink,
            theme.divider,
          ),
          PushlogButtonVariant.danger => (
            theme.dangerSoft,
            theme.danger,
            theme.danger,
          ),
        };

    final textStyle = size == PushlogButtonSize.small
        ? AppTypography.label(color: foreground, weight: FontWeight.w700)
        : AppTypography.title(color: foreground);

    return PressFeedback(
      onTap: onPressed,
      enabled: enabled,
      semanticLabel: label,
      child: AnimatedContainer(
        duration: AppMotion.duration(context, AppMotion.fast),
        height: _height,
        width: expand ? double.infinity : null,
        padding: EdgeInsets.symmetric(
          horizontal: size == PushlogButtonSize.small
              ? AppSpacing.xl
              : AppSpacing.block,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: AppRadius.all(_radius),
          border: border == null ? null : Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading) ...[
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: foreground,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
            ] else if (icon != null) ...[
              // Solid glyphs carry more visual weight than the text beside
              // them, so the icon runs a step smaller than the label.
              Icon(icon, size: 18, color: foreground),
              const SizedBox(width: AppSpacing.md),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textStyle,
              ),
            ),
            if (trailing != null) ...[
              const Spacer(),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
