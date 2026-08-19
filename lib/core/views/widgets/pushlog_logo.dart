//
//  pushlog
//  pushlog_logo.dart
//
//  Copyright (c) 2026 Codecraft Solutions. All rights reserved.
//

import 'package:flutter/material.dart';

/// The Pushlog brand mark.
///
/// Shipped as a raster rather than the SVG beside it: rendering the vector
/// would mean adding an SVG package for a single image, and the source is
/// 614x567, which is already well past 3x for the sizes it is drawn at.
///
/// The mark is sized by [height] and keeps its own aspect ratio, so it can
/// sit inside a stretched column without being pulled out of shape.
class PushlogLogo extends StatelessWidget {
  const PushlogLogo({this.height = 76, super.key});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/brand/Pushlog-logo.png',
      height: height,
      fit: BoxFit.contain,
      // Decorative. The wordmark directly beneath already names the app, so
      // announcing the image would say "Pushlog" twice.
      excludeFromSemantics: true,
    );
  }
}
