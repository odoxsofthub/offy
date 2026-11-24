import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_colors.dart';
import '../common/gradient_circle_painter.dart';

class FaqItemTile extends StatelessWidget {
  final String question;
  final String answer;
  final bool isFirst;
  final bool isLast;
  final bool isExpanded;
  final VoidCallback onTap;

  const FaqItemTile({
    super.key,
    required this.question,
    required this.answer,
    this.isFirst = false,
    this.isLast = false,
    this.isExpanded = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    BorderRadius borderRadius;
    if (isFirst && isLast) {
      borderRadius = BorderRadius.circular(16.r);
    } else if (isFirst) {
      borderRadius = BorderRadius.vertical(top: Radius.circular(16.r));
    } else if (isLast) {
      borderRadius = BorderRadius.vertical(bottom: Radius.circular(16.r));
    } else {
      borderRadius = BorderRadius.zero;
    }

    final tileContent = Container(
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkCard
            : Colors.white.withValues(alpha: 0.7),
        borderRadius: borderRadius,
        border: !isLast
            ? Border(
                bottom: BorderSide(
                  color: isDark ? AppColors.darkTertiary : AppColors.shade,
                  width: 0.6.w,
                ),
              )
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: borderRadius,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 22.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Text(
                        question,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          height: 1,
                          letterSpacing: 0,
                          color: isDark ? AppColors.white : Colors.black,
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    AnimatedRotation(
                      turns: isExpanded ? -0.25 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.chevron_right,
                        size: 20.sp,
                        color: isDark
                            ? AppColors.navColor
                            : AppColors.tertiary.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
                if (isExpanded) ...[
                  SizedBox(height: 19.h),
                  Padding(
                    padding: EdgeInsets.only(left: 10.w, right: 46.w),
                    child: Text(
                      answer,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w400,
                        height: 20 / 14,
                        letterSpacing: 0,
                        color: isDark
                            ? AppColors.white.withValues(alpha: 0.75)
                            : const Color(0xFF545352),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    if (isFirst || isLast) {
      final double highlightAlpha = isDark ? 0.3 : 0.8;
      final List<Color> colors;

      if (isFirst && isLast) {
        colors = [
          Colors.white.withValues(alpha: highlightAlpha),
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: highlightAlpha),
        ];
      } else if (isFirst) {
        colors = [
          Colors.white.withValues(alpha: highlightAlpha),
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.0),
        ];
      } else {
        colors = [
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: highlightAlpha),
        ];
      }

      return CustomPaint(
        painter: GradientCirclePainter(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
            stops: const [0.0, 0.5, 1.0],
          ),
          strokeWidth: 1.5.w,
          borderRadius: borderRadius,
        ),
        child: tileContent,
      );
    }

    return tileContent;
  }
}
