//
//  pushlog
//  pushlog_confirm_dialog.dart
//
//  Created by Ngonidzashe Mangudya on 2026/04/16.
//  Copyright (c) 2026 Codecraft Solutions. All rights reserved.
//

import 'package:flutter/material.dart';
import 'package:pushlog/core/configs/colors.dart';
import 'package:pushlog/core/configs/spacing.dart';
import 'package:pushlog/core/configs/typography.dart';
import 'package:pushlog/core/views/widgets/pushlog_button.dart';

/// A confirmation for something the user cannot simply tap again to undo.
///
/// The consequential action is quiet on the row that offers it and loud
/// here, where the user has been told exactly what it does. Reversing that
/// — a big red button on the list itself — pressures the decision at the
/// point where the least context is available.
///
/// Dismissing the dialog counts as declining: [ask] resolves to `false`
/// for a barrier tap or a back gesture, never to a silent yes.
class PushlogConfirmDialog extends StatelessWidget {
  const PushlogConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.cancelLabel = 'Cancel',
    this.isDestructive = true,
    super.key,
  });

  /// Asks the user, and resolves to true only if they confirmed.
  ///
  /// Set [isDestructive] false for actions that end something without
  /// losing it — signing out of a device, leaving a screen mid-way. Red is
  /// reserved for data that will not come back, so it keeps meaning what
  /// it says.
  static Future<bool> ask(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    String cancelLabel = 'Cancel',
    bool isDestructive = true,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => PushlogConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        isDestructive: isDestructive,
      ),
    );
    return confirmed ?? false;
  }

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;

  /// Whether confirming loses something that cannot be recovered.
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    return AlertDialog(
      backgroundColor: theme.surfaceRaised,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.all(AppRadius.xl),
      ),
      titlePadding: const EdgeInsets.fromLTRB(
        AppSpacing.block,
        AppSpacing.block,
        AppSpacing.block,
        AppSpacing.lg,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.block,
      ),
      actionsPadding: const EdgeInsets.all(AppSpacing.block),
      title: Text(
        title,
        style: AppTypography.headingSmall(color: theme.ink),
      ),
      content: Text(
        message,
        style: AppTypography.body(color: theme.secondaryInk),
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: PushlogButton(
                label: cancelLabel,
                variant: PushlogButtonVariant.ghost,
                size: PushlogButtonSize.medium,
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: PushlogButton(
                label: confirmLabel,
                variant: isDestructive
                    ? PushlogButtonVariant.danger
                    : PushlogButtonVariant.primary,
                size: PushlogButtonSize.medium,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
