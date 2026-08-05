//
//  pushlog
//  count_block.dart
//
//  Created by Ngonidzashe Mangudya on 2026/04/16.
//  Copyright (c) 2026 Codecraft Solutions. All rights reserved.
//

import 'package:flutter/material.dart';
import 'package:pushlog/core/configs/colors.dart';
import 'package:pushlog/core/configs/typography.dart';

class CountBlock extends StatelessWidget {
  const CountBlock({
    required this.count,
    required this.theme,
    this.target,
    super.key,
  });

  final int count;
  final AppTheme theme;
  final int? target;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            target == null ? '$count' : '$count / $target',
            style: AppTypography.displayLarge(
              color: theme.ink,
            ),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -8),
          child: Text(
            target == null ? 'TODAY' : 'TODAY / TARGET',
            style: AppTypography.labelMono(
              color: theme.secondaryInk,
              letterSpacing: 1.6,
            ),
          ),
        ),
      ],
    );
  }
}
