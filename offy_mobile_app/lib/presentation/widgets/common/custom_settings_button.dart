import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_assets.dart';
import 'gradient_circle_painter.dart';

class CustomSettingsButton extends StatelessWidget {
  final VoidCallback? onTap;

  const CustomSettingsButton({
    super.key,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: GradientCirclePainter(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: Theme.of(context).brightness == Brightness.dark
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
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF5E340E).withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.5),
          ),
          child: Center(
            child: SvgPicture.asset(
              AppAssets.settings,
              colorFilter: ColorFilter.mode(
                Theme.of(context).brightness == Brightness.dark
                    ? AppColors.white
                    : AppColors.black,
                BlendMode.srcIn,
              ),
              width: 24.w,
              height: 24.w,
            ),
          ),
        ),
      ),
    );
  }
}
