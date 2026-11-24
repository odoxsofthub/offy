import 'package:flutter/material.dart';

class GradientCirclePainter extends CustomPainter {
  final Gradient gradient;
  final double strokeWidth;
  final BorderRadius? borderRadius;

  GradientCirclePainter({
    required this.gradient,
    required this.strokeWidth,
    this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Rect.fromLTWH(0, 0, size.width, size.height);

    final Paint paint = Paint()
      ..shader = gradient.createShader(rect)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    if (borderRadius != null) {
      final RRect rrect = borderRadius!.toRRect(rect);
      final RRect insetRRect = rrect.deflate(strokeWidth / 2);
      canvas.drawRRect(insetRRect, paint);
    } else {
      final Rect insetRect = rect.deflate(strokeWidth / 2);
      canvas.drawOval(insetRect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant GradientCirclePainter oldDelegate) =>
      oldDelegate.gradient != gradient ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.borderRadius != borderRadius;
}
