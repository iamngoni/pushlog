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
import 'package:pushlog/core/views/widgets/tap_surface.dart';

class ActionStrip extends StatelessWidget {
  const ActionStrip({
    required this.theme,
    required this.onAddReps,
    required this.onLive,
    super.key,
  });

  final AppTheme theme;
  final void Function(int reps) onAddReps;
  final VoidCallback onLive;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 88,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.divider),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: ActionCell(
              title: '+1',
              subtitle: 'REP',
              semanticLabel: 'Add 1 rep',
              emphasized: true,
              theme: theme,
              onTap: () => onAddReps(1),
            ),
          ),
          VerticalDivider(
            width: 1,
            color: theme.divider,
          ),
          Expanded(
            child: ActionCell(
              title: '+10',
              subtitle: 'SET',
              semanticLabel: 'Add 10 reps',
              emphasized: false,
              theme: theme,
              onTap: () => onAddReps(10),
            ),
          ),
          VerticalDivider(
            width: 1,
            color: theme.divider,
          ),
          Expanded(
            child: ActionCell(
              title: '+25',
              subtitle: 'BIG',
              semanticLabel: 'Add 25 reps',
              emphasized: false,
              theme: theme,
              onTap: () => onAddReps(25),
            ),
          ),
          VerticalDivider(
            width: 1,
            color: theme.divider,
          ),
          Expanded(
            child: ActionCell(
              title: 'LIVE',
              subtitle: 'AUTO',
              semanticLabel: 'Start live session',
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
    this.semanticLabel,
    this.isEnabled = true,
    super.key,
  });

  final String title;
  final String? subtitle;
  final String? semanticLabel;
  final bool emphasized;
  final bool isEnabled;
  final AppTheme theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isEnabled ? 1.0 : 0.36,
      child: TapSurface(
        onTap: isEnabled ? onTap : null,
        semanticLabel: semanticLabel,
        color: emphasized ? theme.accent : Colors.transparent,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: AppTypography.displayAction(
                  color: emphasized ? AppColors.fixedDark : theme.ink,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: AppTypography.labelMono(
                    size: 8,
                    color: emphasized
                        ? AppColors.fixedDark
                        : theme.secondaryInk,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
