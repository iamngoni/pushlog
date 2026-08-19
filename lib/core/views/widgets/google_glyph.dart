//
//  pushlog
//  google_glyph.dart
//
//  Copyright (c) 2026 Codecraft Solutions. All rights reserved.
//

import 'package:flutter/widgets.dart';

/// Google's four-colour "G".
///
/// Every other glyph in the app inherits its button's foreground, but a
/// provider mark is not ours to restyle — Google's branding terms require
/// the four brand colours, so this one keeps them.
///
/// It is drawn rather than shipped: an SVG would mean a new dependency for a
/// single icon, and a raster asset would mean one file per density bucket
/// that then has to stay in step with the button size.
class GoogleGlyph extends StatelessWidget {
  const GoogleGlyph({this.size = 18, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      // The label beside the mark already says "Continue with Google", so
      // the glyph stays out of the accessibility tree instead of announcing
      // the provider twice.
      child: ExcludeSemantics(
        child: CustomPaint(painter: _GoogleGlyphPainter()),
      ),
    );
  }
}

/// Paints Google's published sign-in mark, authored on an 18x18 viewBox.
///
/// The four paths are the official ones, transcribed to [Path] calls. They
/// are laid down in the published order — blue, green, yellow, red — because
/// the arms are drawn as separate closed shapes that meet at shared edges.
class _GoogleGlyphPainter extends CustomPainter {
  static const double _viewBoxSize = 18;

  static const Color _blue = Color(0xFF4285F4);
  static const Color _green = Color(0xFF34A853);
  static const Color _yellow = Color(0xFFFBBC05);
  static const Color _red = Color(0xFFEA4335);

  @override
  void paint(Canvas canvas, Size size) {
    // Authored at 18pt; scale to whatever the button asked for.
    final scale = size.width / _viewBoxSize;

    canvas
      ..save()
      ..scale(scale);

    _fill(canvas, _blue, _bluePath());
    _fill(canvas, _green, _greenPath());
    _fill(canvas, _yellow, _yellowPath());
    _fill(canvas, _red, _redPath());

    canvas.restore();
  }

  void _fill(Canvas canvas, Color color, Path path) {
    canvas.drawPath(path, Paint()..color = color);
  }

  /// The right-hand bar and the top of the crossbar.
  Path _bluePath() => Path()
    ..moveTo(17.64, 9.2045)
    ..relativeCubicTo(0, -0.6381, -0.0573, -1.2518, -0.1636, -1.8409)
    ..lineTo(9, 7.3636)
    ..relativeLineTo(0, 3.4814)
    ..relativeLineTo(4.8436, 0)
    ..relativeCubicTo(-0.2086, 1.125, -0.8427, 2.0782, -1.7959, 2.7164)
    ..relativeLineTo(0, 2.2581)
    ..relativeLineTo(2.9087, 0)
    ..relativeCubicTo(1.7018, -1.5668, 2.6836, -3.874, 2.6836, -6.615)
    ..close();

  /// The lower-right sweep.
  Path _greenPath() => Path()
    ..moveTo(9, 18)
    ..relativeCubicTo(2.43, 0, 4.4673, -0.806, 5.9564, -2.1805)
    ..relativeLineTo(-2.9087, -2.2581)
    ..relativeCubicTo(-0.8055, 0.54, -1.8368, 0.859, -3.0477, 0.859)
    ..relativeCubicTo(-2.344, 0, -4.3282, -1.5831, -5.036, -3.7104)
    ..lineTo(0.9574, 10.71)
    ..relativeLineTo(0, 2.3318)
    ..cubicTo(2.4382, 15.9832, 5.4818, 18, 9, 18)
    ..close();

  /// The left edge.
  Path _yellowPath() => Path()
    ..moveTo(3.964, 10.71)
    ..relativeCubicTo(-0.18, -0.54, -0.2822, -1.1168, -0.2822, -1.71)
    // The published data uses a smooth cubic here; its first control point
    // is the reflection of the previous one, resolved to (0, -0.5932).
    ..relativeCubicTo(0, -0.5932, 0.1023, -1.17, 0.2823, -1.71)
    ..lineTo(3.9641, 4.9582)
    ..lineTo(0.9573, 4.9582)
    ..arcToPoint(
      const Offset(0, 9),
      radius: const Radius.circular(8.9965),
      clockwise: false,
    )
    ..relativeCubicTo(0, 1.4523, 0.3477, 2.8268, 0.9573, 4.0418)
    ..lineTo(3.964, 10.71)
    ..close();

  /// The upper sweep.
  Path _redPath() => Path()
    ..moveTo(9, 3.5795)
    ..relativeCubicTo(1.3214, 0, 2.5077, 0.4541, 3.4405, 1.346)
    ..relativeLineTo(2.5813, -2.5814)
    ..cubicTo(13.4636, 0.8918, 11.4264, 0, 9, 0)
    ..cubicTo(5.4818, 0, 2.4382, 2.0168, 0.9573, 4.9582)
    ..lineTo(3.964, 7.29)
    ..cubicTo(4.6718, 5.1627, 6.6559, 3.5795, 9, 3.5795)
    ..close();

  @override
  bool shouldRepaint(_GoogleGlyphPainter oldDelegate) => false;
}
