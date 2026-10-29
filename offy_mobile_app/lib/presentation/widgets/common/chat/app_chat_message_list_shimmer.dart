import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../core/theme/app_colors.dart';

/// Reusable shimmer placeholder for chat log message lists across log pages.
class AppChatMessageListShimmer extends StatelessWidget {
  final Color? backgroundColor;

  const AppChatMessageListShimmer({super.key, this.backgroundColor});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = AppColors.shimmerBase(isDark);
    final highlightColor = AppColors.shimmerHighlight(isDark);
    final bgColor = backgroundColor ?? (isDark ? AppColors.darkBg : AppColors.white);

    return Container(
      color: bgColor,
      child: Shimmer.fromColors(
        baseColor: baseColor,
        highlightColor: highlightColor,
        child: ListView(
          reverse: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 16.w),
          children: [
            // Incoming Message Shimmer Bubble with Attachment preview placeholder (Bottom-most)
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 220.w,
                padding: EdgeInsets.all(10.r),
                decoration: BoxDecoration(
                  color: baseColor,
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 20.r,
                          height: 20.r,
                          decoration: BoxDecoration(
                            color: highlightColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Container(
                          width: 60.w,
                          height: 12.h,
                          decoration: BoxDecoration(
                            color: highlightColor,
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10.h),
                    Container(
                      width: 180.w,
                      height: 12.h,
                      decoration: BoxDecoration(
                        color: highlightColor,
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Container(
                      width: 87.w,
                      height: 29.h,
                      decoration: BoxDecoration(
                        color: highlightColor,
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16.h),

            // Outgoing Message Shimmer Bubble (Right-aligned)
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                width: 200.w,
                padding: EdgeInsets.all(10.r),
                decoration: BoxDecoration(
                  color: baseColor,
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 175.w,
                      height: 12.h,
                      decoration: BoxDecoration(
                        color: highlightColor,
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Container(
                      width: 110.w,
                      height: 12.h,
                      decoration: BoxDecoration(
                        color: highlightColor,
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16.h),

            // Incoming Message Shimmer Bubble (Left-aligned)
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 240.w,
                padding: EdgeInsets.all(10.r),
                decoration: BoxDecoration(
                  color: baseColor,
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 20.r,
                          height: 20.r,
                          decoration: BoxDecoration(
                            color: highlightColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Container(
                          width: 70.w,
                          height: 12.h,
                          decoration: BoxDecoration(
                            color: highlightColor,
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10.h),
                    Container(
                      width: 210.w,
                      height: 12.h,
                      decoration: BoxDecoration(
                        color: highlightColor,
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Container(
                      width: 140.w,
                      height: 12.h,
                      decoration: BoxDecoration(
                        color: highlightColor,
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20.h),

            // Date Header Placeholder (Top-most)
            Center(
              child: Container(
                width: 90.w,
                height: 18.h,
                decoration: BoxDecoration(
                  color: baseColor,
                  borderRadius: BorderRadius.circular(9.r),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
