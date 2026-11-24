import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class TimeOffLogSendIconWidget extends StatelessWidget {
  final double? size;
  final Color color;

  const TimeOffLogSendIconWidget({
    super.key,
    this.size,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    final iconSize = size ?? 20.r;

    return CustomPaint(
      size: Size(iconSize, iconSize),
      painter: _SendIconPainter(color: color),
    );
  }
}

class _SendIconPainter extends CustomPainter {
  final Color color;

  _SendIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final w = size.width;
    final h = size.height;

    // Main right-pointing paper plane path (optically centered)
    path.moveTo(w * 0.95, h * 0.5);
    path.lineTo(w * 0.15, h * 0.15);
    path.lineTo(w * 0.40, h * 0.5);
    path.lineTo(w * 0.15, h * 0.85);
    path.close();

    // Inner line trace from notch to tip
    path.moveTo(w * 0.40, h * 0.5);
    path.lineTo(w * 0.95, h * 0.5);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SendIconPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
