import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_colors.dart';
import '../common/gradient_circle_painter.dart';

class NoNetworkLogoutButton extends StatelessWidget {
  final VoidCallback? onTap;

  const NoNetworkLogoutButton({
    super.key,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: GradientCirclePainter(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    Colors.white.withValues(alpha: 0.3),
                    Colors.white.withValues(alpha: 0.0),
                    Colors.white.withValues(alpha: 0.3),
                  ]
                : [
                    Colors.white,
                    Colors.white.withValues(alpha: 0.0),
                    Colors.white,
                  ],
            stops: const [0.0, 0.5, 1.0],
          ),
          strokeWidth: 1.5.w,
        ),
        child: Container(
          width: 41.27.w,
          height: 41.27.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark
                ? const Color(0xFF5E340E).withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.5),
          ),
          child: Icon(
            Icons.logout_outlined,
            color: isDark ? AppColors.white : AppColors.black,
            size: 22.w,
          ),
        ),
      ),
    );
  }
}
