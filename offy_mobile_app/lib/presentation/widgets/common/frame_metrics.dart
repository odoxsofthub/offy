import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Scales 402x874pt Figma frames (splash, onboarding, login) to the window: by width,
/// limited by height on short screens, capped at [_maxScale] on tablets (centred column).
@immutable
class FrameMetrics {
  const FrameMetrics._({required this.scale, required this.contentWidth});

  factory FrameMetrics.of(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.viewPaddingOf(context);
    final usableHeight = size.height - padding.vertical;
    final scale = math
        .min(size.width / frameWidth, usableHeight / _minContentHeight)
        .clamp(_minScale, _maxScale)
        .toDouble();
    return FrameMetrics._(
      scale: scale,
      contentWidth: math.min(size.width, frameWidth * scale),
    );
  }

  /// Width of the Figma frames.
  static const double frameWidth = 402;

  /// Figma height needed for everything except the illustration, plus a
  /// ~200pt illustration.
  static const double _minContentHeight = 640;

  static const double _minScale = 0.75;
  static const double _maxScale = 1.3;

  /// Logical pixels per Figma pixel.
  final double scale;

  /// Width of the onboarding content column.
  final double contentWidth;

  /// Converts a Figma measurement to logical pixels.
  double call(double figmaPx) => figmaPx * scale;
}
