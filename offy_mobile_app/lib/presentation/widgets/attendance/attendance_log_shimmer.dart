import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/theme/app_colors.dart';

class AttendanceLogShimmer extends StatelessWidget {
  final int itemCount;

  const AttendanceLogShimmer({super.key, this.itemCount = 5});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: List.generate(itemCount, (index) {
        final isLast = index == itemCount - 1;

        return Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0.0 : 12.h),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(12.r),
              border: Border(
                left: BorderSide(
                  color: isDark ? const Color(0x1AE4E2E1) : const Color(0x66E4E2E1),
                  width: 4.w,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0x0F2A2A2A),
                  blurRadius: 20.r,
                  offset: Offset(0, 4.h),
                ),
              ],
            ),
            child: Shimmer.fromColors(
              baseColor: AppColors.shimmerBase(isDark),
              highlightColor: AppColors.shimmerHighlight(isDark),
              child: Padding(
                padding: EdgeInsets.all(20.w),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Avatar/Icon shimmer
                    Container(
                      width: 48.w,
                      height: 48.w,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 16.w),
                    // Details column
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Date line
                              Container(
                                width: 120.w,
                                height: 16.h,
                                color: Colors.white,
                              ),
                              // Status badge
                              Container(
                                width: 70.w,
                                height: 24.h,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8.h),
                          // Time info line
                          Container(
                            width: 150.w,
                            height: 14.h,
                            color: Colors.white,
                          ),
                          SizedBox(height: 4.h),
                          // Shift duration line
                          Container(
                            width: 100.w,
                            height: 12.h,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
