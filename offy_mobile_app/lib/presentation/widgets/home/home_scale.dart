import 'dart:math' as math;

import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Compact scale for the Home screen.
///
/// Vertical sizes are scaled by [factor] so the whole Home content fits above
/// the bottom navigation bar. Fonts shrink more gently and never below
/// [minFontFactor] to stay readable.
class HomeScale {
  const HomeScale(this.factor);

  /// Home content at its design size.
  static const full = HomeScale(1);

  /// Smallest layout scale; below this the Home page scrolls instead.
  static const double minFactor = 0.75;

  /// Smallest font scale.
  static const double minFontFactor = 0.85;

  /// Scale needed to fit [naturalHeight] (design pixels, before `.h`) into
  /// [available] logical pixels.
  factory HomeScale.fit({
    required double available,
    required double naturalHeight,
  }) {
    if (naturalHeight <= 0 || !available.isFinite) return full;
    return HomeScale((available / naturalHeight.h).clamp(minFactor, 1.0));
  }

  final double factor;

  double h(double value) => value.h * factor;

  double w(double value) => value.w * factor;

  double sp(double value) => value.sp * math.max(factor, minFontFactor);
}
