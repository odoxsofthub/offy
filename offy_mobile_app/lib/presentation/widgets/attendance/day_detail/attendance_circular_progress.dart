import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/constants/app_assets.dart';

class AttendanceCircularProgress extends StatelessWidget {
  final double progress;
  final bool? isCompleted;
  final Widget? centerChild;

  const AttendanceCircularProgress({
    super.key,
    required this.progress,
    this.isCompleted,
    this.centerChild,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool completed = isCompleted ?? (progress >= 1.0);

    return SizedBox(
      width: 64.w,
      height: 64.w,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(64.w, 64.w),
            painter: _AttendanceCircularProgressPainter(
              progress: progress.clamp(0.0, 1.0),
              trackColor: isDark ? const Color(0xFF352012) : const Color(0xFFE4E2E1),
              progressColor: const Color(0xFFFF5722),
              strokeWidth: 5.79.w,
            ),
          ),
          centerChild ??
              SvgPicture.asset(
                completed ? AppAssets.dayCompleted : AppAssets.dayActive,
                width: 20.w,
                height: 20.w,
                fit: BoxFit.contain,
              ),
        ],
      ),
    );
  }
}

class _AttendanceCircularProgressPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  const _AttendanceCircularProgressPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // If 8 hours is completed, all the round is in primary color
    if (progress >= 1.0) {
      final completePaint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;

      canvas.drawCircle(center, radius, completePaint);
      return;
    }

    // Incompleted part is shown in #E4E2E1 color (trackColor)
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    canvas.drawCircle(center, radius, trackPaint);

    // Completed part is shown in primary with sharp edges, not round
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;

      // Start from top (-90 degrees)
      const startAngle = -math.pi / 2;
      final sweepAngle = 2 * math.pi * progress;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AttendanceCircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
