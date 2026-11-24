import 'package:flutter/material.dart';

class AppZoomableImageView extends StatefulWidget {
  final Widget child;
  final ValueChanged<bool> onZoomChanged;

  const AppZoomableImageView({
    super.key,
    required this.child,
    required this.onZoomChanged,
  });

  @override
  State<AppZoomableImageView> createState() => _AppZoomableImageViewState();
}

class _AppZoomableImageViewState extends State<AppZoomableImageView>
    with SingleTickerProviderStateMixin {
  final TransformationController _transformationController =
      TransformationController();
  late final AnimationController _animationController;
  Animation<Matrix4>? _animation;
  TapDownDetails? _doubleTapDetails;
  bool _currentlyZoomed = false;

  @override
  void initState() {
    super.initState();
    _transformationController.addListener(_onTransformationChanged);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..addListener(() {
        if (_animation != null) {
          _transformationController.value = _animation!.value;
        }
      });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _transformationController.removeListener(_onTransformationChanged);
    _transformationController.dispose();
    super.dispose();
  }

  void _onTransformationChanged() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    final isZoomed = scale > 1.05;
    if (_currentlyZoomed != isZoomed) {
      _currentlyZoomed = isZoomed;
      widget.onZoomChanged(isZoomed);
    }
  }

  void _onDoubleTap() {
    if (_animationController.isAnimating) return;

    final currentMatrix = _transformationController.value;
    final scale = currentMatrix.getMaxScaleOnAxis();
    final Matrix4 targetMatrix;

    if (scale > 1.05) {
      targetMatrix = Matrix4.identity();
    } else {
      final position = _doubleTapDetails?.localPosition ?? Offset.zero;
      const targetScale = 2.5;
      final x = -position.dx * (targetScale - 1);
      final y = -position.dy * (targetScale - 1);
      targetMatrix = Matrix4.translationValues(x, y, 0.0)
        ..multiply(Matrix4.diagonal3Values(targetScale, targetScale, 1.0));
    }

    _animation = Matrix4Tween(
      begin: currentMatrix,
      end: targetMatrix,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    _animationController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: (details) => _doubleTapDetails = details,
      onDoubleTap: _onDoubleTap,
      child: InteractiveViewer(
        transformationController: _transformationController,
        minScale: 1.0,
        maxScale: 4.0,
        child: Center(child: widget.child),
      ),
    );
  }
}
