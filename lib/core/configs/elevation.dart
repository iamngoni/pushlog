//
//  pushlog
//  elevation.dart
//
//  Created by Ngonidzashe Mangudya on 2026/04/16.
//  Copyright (c) 2026 Codecraft Solutions. All rights reserved.
//

import 'package:flutter/widgets.dart';
import 'package:pushlog/core/configs/colors.dart';

/// Elevation.
///
/// Pushlog is flat at rest. Core content lives on one plane, and structure
/// comes from tone, spacing, and dividers — if a screen looks like a pile of
/// cards, the hierarchy is wrong, not the shadows.
///
/// Shadows are therefore reserved for surfaces that genuinely float above
/// moving content: toasts, sheets, and dialogs. Each is built from two
/// layers, because a real shadow is two things at once — a soft cast shadow
/// from the light above, and a tighter ambient shadow where the surface
/// blocks light from reaching directly underneath it. A single blurred
/// layer always reads as a smudge.
///
/// The ambient layer shrinks as elevation rises: something floating high
/// above the page has almost no contact shadow left.
class AppElevation {
  const AppElevation._();

  /// Nothing. The default for cards, rows, and every resting surface.
  static const List<BoxShadow> flat = <BoxShadow>[];

  /// A control that has just been lifted — a dragged item, a pressed cell.
  static List<BoxShadow> raised(AppTheme theme) => <BoxShadow>[
    BoxShadow(
      color: theme.shadow.withValues(alpha: theme.isDark ? 0.44 : 0.06),
      offset: const Offset(0, 1),
      blurRadius: 2,
    ),
    BoxShadow(
      color: theme.shadow.withValues(alpha: theme.isDark ? 0.32 : 0.05),
      offset: const Offset(0, 2),
      blurRadius: 6,
    ),
  ];

  /// Menus, popovers, and anything anchored to a control it overlaps.
  static List<BoxShadow> floating(AppTheme theme) => <BoxShadow>[
    BoxShadow(
      color: theme.shadow.withValues(alpha: theme.isDark ? 0.48 : 0.07),
      offset: const Offset(0, 2),
      blurRadius: 4,
    ),
    BoxShadow(
      color: theme.shadow.withValues(alpha: theme.isDark ? 0.38 : 0.06),
      offset: const Offset(0, 6),
      blurRadius: 16,
    ),
  ];

  /// Toasts and sticky bars that sit above scrolling content.
  static List<BoxShadow> lifted(AppTheme theme) => <BoxShadow>[
    BoxShadow(
      color: theme.shadow.withValues(alpha: theme.isDark ? 0.46 : 0.06),
      offset: const Offset(0, 4),
      blurRadius: 8,
    ),
    BoxShadow(
      color: theme.shadow.withValues(alpha: theme.isDark ? 0.40 : 0.10),
      offset: const Offset(0, 12),
      blurRadius: 32,
      spreadRadius: -4,
    ),
  ];

  /// Sheets and dialogs that take over the screen.
  static List<BoxShadow> modal(AppTheme theme) => <BoxShadow>[
    BoxShadow(
      color: theme.shadow.withValues(alpha: theme.isDark ? 0.40 : 0.05),
      offset: const Offset(0, 6),
      blurRadius: 12,
    ),
    BoxShadow(
      color: theme.shadow.withValues(alpha: theme.isDark ? 0.52 : 0.14),
      offset: const Offset(0, 20),
      blurRadius: 56,
      spreadRadius: -8,
    ),
  ];

  /// A hairline drawn *inside* the edge of a surface.
  ///
  /// Pass to `Container.foregroundDecoration` so the line paints over the
  /// child rather than around it. Use in place of a border when the content
  /// underneath is an image, an avatar, or any user-supplied colour: an
  /// inset line defines the edge without a hard stroke that clashes with
  /// whatever it is sitting on, and it stops an image whose edges happen to
  /// match the page from melting into the background.
  static BoxDecoration innerEdge(
    AppTheme theme, {
    BorderRadius? borderRadius,
    BoxShape shape = BoxShape.rectangle,
  }) => BoxDecoration(
    shape: shape,
    borderRadius: shape == BoxShape.circle ? null : borderRadius,
    border: Border.all(
      color: theme.isDark ? const Color(0x1FFFFFFF) : const Color(0x14000000),
    ),
  );

  /// The scrim behind a modal surface.
  static Color scrim(AppTheme theme) =>
      theme.isDark ? const Color(0xCC0F100C) : const Color(0x992A2C23);
}
