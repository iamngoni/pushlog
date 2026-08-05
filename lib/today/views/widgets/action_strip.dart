//
//  pushlog
//  action_strip.dart
//
//  Created by Ngonidzashe Mangudya on 2026/04/16.
//  Copyright (c) 2026 Codecraft Solutions. All rights reserved.
//

import 'package:flutter/material.dart';
import 'package:pushlog/core/configs/colors.dart';
import 'package:pushlog/core/configs/typography.dart';

class ActionStrip extends StatelessWidget {
  const ActionStrip({
    required this.theme,
    required this.onAddReps,
    required this.onLive,
    this.suggestedSet,
    super.key,
  });

  final AppTheme theme;
  final void Function(int reps) onAddReps;
  final VoidCallback onLive;
  final int? suggestedSet;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.background,
        border: Border(
          top: BorderSide(color: theme.divider),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: ActionCell(
              title: '+1',
              emphasized: false,
              theme: theme,
              onTap: () => onAddReps(1),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ActionCell(
              title: '+${suggestedSet ?? 10}',
              subtitle: suggestedSet == null ? null : 'plan',
              emphasized: true,
              theme: theme,
              onTap: () => onAddReps(suggestedSet ?? 10),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ActionCell(
              title: '+25',
              emphasized: false,
              theme: theme,
              onTap: () => onAddReps(25),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ActionCell(
              title: 'Live',
              emphasized: false,
              theme: theme,
              onTap: onLive,
            ),
          ),
        ],
      ),
    );
  }
}

class ActionCell extends StatelessWidget {
  const ActionCell({
    required this.title,
    required this.emphasized,
    required this.theme,
    required this.onTap,
    this.subtitle,
    this.isEnabled = true,
    super.key,
  });

  final String title;
  final String? subtitle;
  final bool emphasized;
  final bool isEnabled;
  final AppTheme theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isEnabled ? 1.0 : 0.36,
      child: GestureDetector(
        onTap: isEnabled ? onTap : null,
        child: Container(
          decoration: BoxDecoration(
            color: emphasized ? theme.accent : theme.surface,
            borderRadius: BorderRadius.circular(14),
            border: emphasized ? null : Border.all(color: theme.divider),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: emphasized ? AppColors.fixedDark : theme.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: AppTypography.labelMono(
                      size: 9,
                      color: emphasized
                          ? AppColors.fixedDark
                          : theme.secondaryInk,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
