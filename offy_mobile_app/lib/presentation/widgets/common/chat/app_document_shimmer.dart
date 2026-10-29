import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../core/theme/app_colors.dart';

class AppDocumentShimmer extends StatelessWidget {
  final bool isImage;

  const AppDocumentShimmer({super.key, this.isImage = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = AppColors.shimmerBase(isDark);
    final highlightColor = AppColors.shimmerHighlight(isDark);
    final skeletonColor =
        isDark ? AppColors.darkTertiary : const Color(0xFFEAE1D8);
    final cardBgColor = isDark ? AppColors.darkCard : AppColors.white;

    if (isImage) {
      return Shimmer.fromColors(
        baseColor: baseColor,
        highlightColor: highlightColor,
        child: Center(
          child: Container(
            width: double.infinity,
            height: double.infinity,
            margin: EdgeInsets.all(24.r),
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: BorderRadius.circular(12.r),
            ),
          ),
        ),
      );
    }

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16.w, 64.h, 16.w, 16.h),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          padding: EdgeInsets.all(20.r),
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 160.w,
                height: 18.h,
                decoration: BoxDecoration(
                  color: skeletonColor,
                  borderRadius: BorderRadius.circular(4.r),
                ),
              ),
              SizedBox(height: 12.h),
              Container(
                width: 100.w,
                height: 12.h,
                decoration: BoxDecoration(
                  color: skeletonColor,
                  borderRadius: BorderRadius.circular(4.r),
                ),
              ),
              SizedBox(height: 24.h),
              Divider(color: skeletonColor, thickness: 1.h),
              SizedBox(height: 20.h),
              for (int i = 0; i < 8; i++) ...[
                Container(
                  width: i % 3 == 0
                      ? double.infinity
                      : (i % 3 == 1 ? 260.w : 180.w),
                  height: 12.h,
                  decoration: BoxDecoration(
                    color: skeletonColor,
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                ),
                SizedBox(height: 14.h),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
