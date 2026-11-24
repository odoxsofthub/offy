import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Reports [minHeight] as its intrinsic height so, under [IntrinsicHeight], the illustration
/// shrinks on short screens instead of forcing the full image height.
class OnboardingShrinkableHeight extends SingleChildRenderObjectWidget {
  const OnboardingShrinkableHeight({
    super.key,
    required this.minHeight,
    super.child,
  });

  final double minHeight;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderOnboardingShrinkableHeight(minHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderOnboardingShrinkableHeight renderObject,
  ) {
    renderObject.minHeight = minHeight;
  }
}

/// Render object for [OnboardingShrinkableHeight].
class RenderOnboardingShrinkableHeight extends RenderProxyBox {
  RenderOnboardingShrinkableHeight(this._minHeight);

  double _minHeight;

  set minHeight(double value) {
    if (value == _minHeight) return;
    _minHeight = value;
    markNeedsLayout();
  }

  @override
  double computeMinIntrinsicHeight(double width) => _minHeight;

  @override
  double computeMaxIntrinsicHeight(double width) => _minHeight;
}
