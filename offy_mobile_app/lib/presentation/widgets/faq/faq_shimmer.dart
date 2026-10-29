import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/theme/app_colors.dart';
import '../common/gradient_circle_painter.dart';

class FaqShimmer extends StatelessWidget {
  const FaqShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = AppColors.shimmerBase(isDark);
    final highlightColor = AppColors.shimmerHighlight(isDark);
    final cardBgColor = isDark
        ? AppColors.darkCard
        : Colors.white.withValues(alpha: 0.7);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0x0D000000),
            offset: const Offset(0, 1),
            blurRadius: 2.r,
          ),
        ],
      ),
      child: Column(
        children: List.generate(6, (index) {
          final isFirst = index == 0;
          final isLast = index == 5;

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

          final double titleWidthRatio = switch (index % 4) {
            0 => 0.7,
            1 => 0.85,
            2 => 0.6,
            _ => 0.75,
          };

          Widget tileContent = Container(
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: borderRadius,
              border: !isLast
                  ? Border(
                      bottom: BorderSide(
                        color: isDark
                            ? AppColors.darkTertiary
                            : AppColors.shade,
                        width: 0.6.w,
                      ),
                    )
                  : null,
            ),
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 22.h),
            child: Shimmer.fromColors(
              baseColor: baseColor,
              highlightColor: highlightColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: titleWidthRatio,
                            child: Container(
                              height: 16.h,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4.r),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Container(
                        width: 20.sp,
                        height: 20.sp,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                      ),
                    ],
                  ),
                ],
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
        }),
      ),
    );
  }
}
