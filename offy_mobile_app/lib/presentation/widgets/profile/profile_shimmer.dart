import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/theme/app_colors.dart';

class ProfileShimmer extends StatelessWidget {
  const ProfileShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final double avatarSize = 110.w;
    final double halfAvatar = avatarSize / 2;
    final totalHeight = statusBarHeight + 96.h + halfAvatar;

    return Container(
      color: isDark ? AppColors.darkTopCard : AppColors.light,
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: totalHeight,
            child: Shimmer.fromColors(
              baseColor: AppColors.shimmerBase(isDark),
              highlightColor: AppColors.shimmerHighlight(isDark),
              child: Stack(
                children: [
                  // AppBar Header shimmer
                  Positioned(
                    left: 0,
                    top: 0,
                    right: 0,
                    height: statusBarHeight + 96.h,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(20.r),
                          bottomRight: Radius.circular(20.r),
                        ),
                      ),
                    ),
                  ),
                  // Avatar Shimmer Box
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Center(
                      child: Container(
                        width: avatarSize,
                        height: avatarSize,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18.r),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 14.h),
          Shimmer.fromColors(
            baseColor: AppColors.shimmerBase(isDark),
            highlightColor: AppColors.shimmerHighlight(isDark),
            child: Column(
              children: [
                Container(width: 200.w, height: 20.h, color: Colors.white),
                SizedBox(height: 10.h),
                Container(width: 140.w, height: 16.h, color: Colors.white),
              ],
            ),
          ),
          SizedBox(height: 25.h),
          Shimmer.fromColors(
            baseColor: AppColors.shimmerBase(isDark),
            highlightColor: AppColors.shimmerHighlight(isDark),
            child: Center(
              child: Container(
                width: 332.w,
                height: 59.h,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(60.r),
                ),
              ),
            ),
          ),
          SizedBox(height: 23.h),
          Expanded(
            child: SafeArea(
              top: false,
              child: Shimmer.fromColors(
                baseColor: AppColors.shimmerBase(isDark),
                highlightColor: AppColors.shimmerHighlight(isDark),
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20.w),
                        child: Container(
                          width: double.infinity,
                          height: 120.h,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                      ),
                      SizedBox(height: 16.h),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20.w),
                        child: Container(
                          width: double.infinity,
                          height: 183.h,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                      ),
                      SizedBox(height: 16.h),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20.w),
                        child: Container(
                          width: double.infinity,
                          height: 183.h,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
