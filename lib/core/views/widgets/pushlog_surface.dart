//
//  pushlog
//  pushlog_surface.dart
//
//  Created by Ngonidzashe Mangudya on 2026/04/16.
//  Copyright (c) 2026 Codecraft Solutions. All rights reserved.
//

import 'package:flutter/material.dart';
import 'package:pushlog/core/configs/colors.dart';
import 'package:pushlog/core/configs/spacing.dart';
import 'package:pushlog/core/configs/typography.dart';
import 'package:pushlog/core/views/widgets/pushlog_button.dart';

/// A grouped block of content.
///
/// The surface sits one tonal step off the page background, which is enough
/// on its own to read as a distinct group. It therefore carries no border by
/// default: a tone change *and* an outline is the same statement made twice,
/// and stacking both is what makes an interface look boxy.
class PushlogCard extends StatelessWidget {
  const PushlogCard({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.xxl),
    this.onTap,
    this.radius = AppRadius.lg,
    this.color,
    this.bordered = false,
    this.semanticLabel,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;
  final Color? color;

  /// Set only when the card sits directly on a surface of the same tone and
  /// spacing cannot establish the boundary.
  final bool bordered;

  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final body = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? theme.surface,
        borderRadius: AppRadius.all(radius),
        border: bordered ? Border.all(color: theme.divider) : null,
      ),
      child: child,
    );

    if (onTap == null) return body;
    return PressFeedback(
      onTap: onTap,
      scale: 0.985,
      semanticLabel: semanticLabel,
      child: body,
    );
  }
}

/// A section heading with an optional trailing value or action.
///
/// The label and the value are baseline-aligned rather than centred: two
/// different sizes centred on a row sit on two different baselines, and the
/// eye reads that as a misalignment even when it cannot name the cause.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    this.trailing,
    this.onTrailingTap,
    this.trailingLabel,
    this.accent = false,
    super.key,
  });

  final String title;

  /// A value or short status shown at the end of the row.
  final String? trailing;

  final VoidCallback? onTrailingTap;

  /// Overrides [trailing] with a tappable action label.
  final String? trailingLabel;

  /// Draws a short Signal Lime rule under the title.
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: AppTypography.headingSmall(color: theme.ink),
              ),
              if (accent) ...[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  width: 28,
                  height: 3,
                  decoration: BoxDecoration(
                    color: theme.accent,
                    borderRadius: AppRadius.all(AppRadius.indicator),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        if (trailingLabel != null)
          PressFeedback(
            onTap: onTrailingTap,
            semanticLabel: trailingLabel,
            child: Text(
              trailingLabel!,
              // Not styled like a link. On a screen where most things are
              // tappable, underlined blue everywhere is noise — weight and
              // ink level carry the affordance instead.
              style: AppTypography.label(
                color: theme.accentInk,
                weight: FontWeight.w700,
              ),
            ),
          )
        else if (trailing != null)
          Text(
            trailing!,
            style: AppTypography.metricInline(color: theme.secondaryInk),
          ),
      ],
    );
  }
}

/// A small all-caps label that opens a group of settings or metadata.
class OverlineLabel extends StatelessWidget {
  const OverlineLabel(this.text, {this.color, super.key});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Text(
      text.toUpperCase(),
      style: AppTypography.overline(color: color ?? theme.tertiaryInk),
    );
  }
}

/// A value with its caption underneath.
///
/// The number leads and the caption explains it, so the caption is set
/// smaller *and* lighter — matching them in size would make the row read as
/// two competing pieces of information rather than one labelled figure.
class StatBlock extends StatelessWidget {
  const StatBlock({
    required this.value,
    required this.label,
    this.emphasis = false,
    this.align = CrossAxisAlignment.start,
    super.key,
  });

  final String value;
  final String label;
  final bool emphasis;
  final CrossAxisAlignment align;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: align,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: AppTypography.metricCompact(
              color: emphasis ? theme.accentInk : theme.ink,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: AppTypography.bodySmall(color: theme.secondaryInk),
          ),
        ],
      ),
    );
  }
}
