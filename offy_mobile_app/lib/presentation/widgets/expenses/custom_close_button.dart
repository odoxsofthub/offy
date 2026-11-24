import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CustomCloseButton extends StatelessWidget {
  final VoidCallback? onTap;

  const CustomCloseButton({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.all(8.w),
        child: CustomPaint(
          size: Size(20.w, 20.w),
          painter: CloseButtonPainter(strokeWidth: 1.0.w),
        ),
      ),
    );
  }
}

class CloseButtonPainter extends CustomPainter {
  final double strokeWidth;

  CloseButtonPainter({required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Rect.fromLTWH(0, 0, w, h);
    final center = Offset(w / 2, h / 2);
    final radius = w / 2;

    // 1. Save layer to isolate BlendMode.clear to this widget only
    canvas.saveLayer(rect, Paint());

    // 2. Draw circular background (red)
    final bgPaint = Paint()
      ..color = const Color(0xFFFF5F57)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    // X Coordinates (centered, inset from circle edge)
    final startOffset = w * 0.32;
    final endOffset = w * 0.67;

    final p1Start = Offset(startOffset, startOffset);
    final p1End = Offset(endOffset, endOffset);
    final p2Start = Offset(endOffset, startOffset);
    final p2End = Offset(startOffset, endOffset);

    // 3. Cut out/Erase the center of the X (transparent hole)
    final clearPaint = Paint()
      ..blendMode = BlendMode.clear
      ..strokeWidth = 2.0 * strokeWidth
      ..strokeCap = StrokeCap.square;
    canvas.drawLine(p1Start, p1End, clearPaint);
    canvas.drawLine(p2Start, p2End, clearPaint);

    // 4. Restore the canvas layer
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CloseButtonPainter oldDelegate) =>
      oldDelegate.strokeWidth != strokeWidth;
}
