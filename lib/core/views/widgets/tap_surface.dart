//
//  pushlog
//  tap_surface.dart
//
//  Created by Ngonidzashe Mangudya on 2026/07/17.
//  Copyright (c) 2026 Codecraft Solutions. All rights reserved.
//

import 'package:flutter/material.dart';

/// An accessible tap target for the app's text-styled controls.
///
/// Wraps its child in button [Semantics] and an [InkWell] so custom
/// text controls stay screen-reader visible, focusable, and give tap
/// feedback without changing their visual design.
class TapSurface extends StatelessWidget {
  const TapSurface({
    required this.child,
    this.onTap,
    this.semanticLabel,
    this.selected,
    this.color = Colors.transparent,
    this.padding,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;

  /// Spoken description overriding the child's text when the visible
  /// copy is too terse to make sense on its own (for example "X").
  final String? semanticLabel;

  /// Set for controls with an active state, such as tab buttons.
  final bool? selected;

  /// Background of the tappable surface, drawn under the ink response.
  final Color color;

  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final content = padding == null
        ? child
        : Padding(padding: padding!, child: child);
    return Semantics(
      button: true,
      enabled: onTap != null,
      selected: selected,
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      child: Material(
        color: color,
        child: InkWell(
          onTap: onTap,
          child: content,
        ),
      ),
    );
  }
}
