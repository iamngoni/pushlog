//
//  pushlog
//  stats_block.dart
//
//  Created by Ngonidzashe Mangudya on 2026/04/16.
//  Copyright (c) 2026 Codecraft Solutions. All rights reserved.
//

import 'package:flutter/material.dart';
import 'package:pushlog/core/configs/colors.dart';
import 'package:pushlog/core/configs/spacing.dart';
import 'package:pushlog/core/configs/typography.dart';

class StatColumn extends StatelessWidget {
  const StatColumn({
    required this.value,
    required this.label,
    required this.theme,
    super.key,
  });

  final String value;
  final String label;
  final AppTheme theme;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The figure leads on weight and size; the caption explains it
          // without competing. An 8pt caption was below the point where
          // it can be read at arm's length, so it now sits on the scale.
          Text(value, style: AppTypography.metricCompact(color: theme.ink)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label.toUpperCase(),
            style: AppTypography.overline(color: theme.tertiaryInk),
          ),
        ],
      ),
    );
  }
}
