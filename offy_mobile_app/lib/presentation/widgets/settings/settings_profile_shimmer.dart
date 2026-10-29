import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';
import 'package:office_app/core/theme/app_colors.dart';

class SettingsProfileShimmer extends StatelessWidget {
  const SettingsProfileShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Shimmer.fromColors(
      baseColor: AppColors.shimmerBase(isDark),
      highlightColor: AppColors.shimmerHighlight(isDark),
      child: Container(
        height: 80.h,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.white,
          borderRadius: BorderRadius.circular(16.r),
        ),
      ),
    );
  }
}
