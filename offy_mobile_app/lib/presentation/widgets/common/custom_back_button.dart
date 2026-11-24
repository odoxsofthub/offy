import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import 'gradient_circle_painter.dart';

class CustomBackButton extends StatelessWidget {
  final VoidCallback? onTap;

  /// Circle diameter and icon size in logical pixels. Default to the
  /// app-wide ScreenUtil sizes when omitted.
  final double? size;
  final double? iconSize;

  const CustomBackButton({super.key, this.onTap, this.size, this.iconSize});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap ?? () => Navigator.pop(context),
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
          width: size ?? 41.27.w,
          height: size ?? 41.27.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark
                ? const Color(0xFF5E340E).withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.5),
          ),
          child: Center(
            child: SvgPicture.asset(
              AppAssets.back,
              colorFilter: ColorFilter.mode(
                isDark ? AppColors.white : AppColors.black,
                BlendMode.srcIn,
              ),
              width: iconSize ?? 20.w,
              height: iconSize ?? 20.w,
            ),
          ),
        ),
      ),
    );
  }
}
