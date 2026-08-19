//
//  pushlog
//  gym_backdrop.dart
//
//  Copyright (c) 2026 Codecraft Solutions. All rights reserved.
//

import 'package:flutter/material.dart';
import 'package:pushlog/core/configs/colors.dart';

/// A gym-wall texture for the sign-in screen: scattered training glyphs and
/// tally clusters, scrawled at slight angles.
///
/// Tally marks are how reps get counted by hand, so the scrawl means
/// something here rather than being ornament for its own sake.
///
/// Two rules keep it on the right side of the product's "no decorative,
/// poster-like layouts" line:
///
/// 1. It is drawn at low alpha, so it reads as marks on a wall rather than
///    artwork, and never competes with the brand block or the sign-in
///    button. Raising it much past this starts pulling the eye off them.
/// 2. The marks avoid the vertical band the content occupies, so nothing is
///    ever printed behind running text.
class GymBackdrop extends StatelessWidget {
  const GymBackdrop({super.key});

  /// Hand-placed rather than random: a seeded scatter would move on every
  /// rebuild and cannot be eyeballed for collisions with the content.
  ///
  /// `x`/`y` are fractions of the box, so the field adapts to any screen.
  /// `angle` is radians — small values only; this is a scrawl, not confetti.
  static const List<_Mark> _marks = [
    // Upper field, above the brand block.
    _Mark(x: 0.06, y: 0.04, icon: Icons.fitness_center_rounded, size: 44),
    _Mark(
      x: 0.73,
      y: 0.08,
      icon: Icons.local_fire_department_rounded,
      size: 34,
    ),
    _Mark(x: 0.32, y: 0.12, tally: 5, angle: 0.10),
    _Mark(x: 0.53, y: 0.03, icon: Icons.emoji_events_rounded, size: 26),
    _Mark(x: 0.05, y: 0.19, icon: Icons.bolt_rounded, size: 30, angle: 0.22),
    _Mark(x: 0.84, y: 0.23, icon: Icons.directions_run_rounded, size: 36),
    _Mark(x: 0.45, y: 0.23, icon: Icons.timer_rounded, size: 24, angle: 0.14),
    _Mark(x: 0.19, y: 0.27, icon: Icons.sports_score_rounded, size: 26),

    // Lower field, below the sign-in button.
    _Mark(x: 0.08, y: 0.77, icon: Icons.trending_up_rounded, size: 34),
    _Mark(x: 0.71, y: 0.75, tally: 4, angle: -0.12),
    _Mark(x: 0.39, y: 0.83, icon: Icons.fitness_center_rounded, size: 30),
    _Mark(x: 0.85, y: 0.85, icon: Icons.local_fire_department_rounded),
    _Mark(x: 0.14, y: 0.88, icon: Icons.bolt_rounded, size: 24, angle: -0.18),
    _Mark(x: 0.58, y: 0.90, tally: 3, angle: 0.08),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    // Dark surfaces swallow a mark that light paper would still show, so the
    // ink is lifted slightly there to keep the texture at the same weight.
    final ink = theme.ink.withValues(alpha: theme.isDark ? 0.13 : 0.10);

    return IgnorePointer(
      // Texture, not content: it must never take a tap or be announced.
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;

            return Stack(
              children: [
                for (final mark in _marks)
                  Positioned(
                    left: mark.x * width,
                    top: mark.y * height,
                    child: Transform.rotate(
                      angle: mark.angle,
                      child: mark.icon != null
                          ? Icon(mark.icon, size: mark.size, color: ink)
                          : CustomPaint(
                              size: Size(mark.tally! * 7.0 + 6, 32),
                              painter: _TallyPainter(
                                count: mark.tally!,
                                color: ink,
                              ),
                            ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// One mark in the field: either a training glyph or a tally cluster.
class _Mark {
  const _Mark({
    required this.x,
    required this.y,
    this.icon,
    this.size = 28,
    this.tally,
    this.angle = 0,
  }) : assert(
         icon != null || tally != null,
         'A mark is either an icon or a tally cluster.',
       );

  final double x;
  final double y;
  final IconData? icon;
  final double size;
  final int? tally;
  final double angle;
}

/// A hand-counted tally: upright strokes, struck through on the fifth.
class _TallyPainter extends CustomPainter {
  const _TallyPainter({required this.count, required this.color});

  final int count;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    // A five is four uprights plus the diagonal that closes the group.
    final uprights = count == 5 ? 4 : count;

    for (var i = 0; i < uprights; i++) {
      final x = 4 + i * 7.0;
      // Alternating lean, so the group looks struck by hand rather than
      // set by a layout engine.
      final lean = i.isEven ? 1.5 : -1.0;
      canvas.drawLine(
        Offset(x + lean, 2),
        Offset(x, size.height - 2),
        paint,
      );
    }

    if (count == 5) {
      canvas.drawLine(
        Offset(1, size.height - 6),
        const Offset(4 + 3 * 7.0 + 4, 6),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_TallyPainter oldDelegate) =>
      oldDelegate.count != count || oldDelegate.color != color;
}
