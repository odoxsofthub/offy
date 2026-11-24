import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/theme/app_colors.dart';

class AppFilterOptionsShimmer extends StatelessWidget {
  final int itemCount;

  const AppFilterOptionsShimmer({super.key, this.itemCount = 3});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = AppColors.shimmerBase(isDark);
    final highlightColor = AppColors.shimmerHighlight(isDark);
    final widths = [60.w, 76.w, 55.w];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List.generate(itemCount, (index) {
        final isFirst = index == 0;
        final itemWidth = widths[index % widths.length];

        return Container(
          decoration: BoxDecoration(
            color: isFirst
                ? (isDark ? AppColors.darkBg : const Color(0xFFFBF8F5))
                : Colors.transparent,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: 16.49.w,
            vertical: 14.43.h,
          ),
          child: Shimmer.fromColors(
            baseColor: baseColor,
            highlightColor: highlightColor,
            child: Row(
              children: [
                Container(
                  width: itemWidth,
                  height: 15.h,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class AppFilterMonthsShimmer extends StatelessWidget {
  final bool showHeader;

  const AppFilterMonthsShimmer({
    super.key,
    this.showHeader = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = AppColors.shimmerBase(isDark);
    final highlightColor = AppColors.shimmerHighlight(isDark);

    return Container(
      color: isDark ? AppColors.darkBg : const Color(0xFFFBF8F5),
      child: Column(
        children: [
          if (showHeader) ...[
            // Date Range Trigger shimmer
            Container(
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkTopCard
                    : const Color(0xFFFAF6F1).withValues(alpha: 0.6),
                border: Border(
                  bottom: BorderSide(
                    color: isDark
                        ? AppColors.darkNav.withValues(alpha: 0.3)
                        : const Color(0xFFE7E0D8).withValues(alpha: 0.5),
                    width: 1.03.w,
                  ),
                ),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: 16.49.w,
                vertical: 21.91.h,
              ),
              child: Shimmer.fromColors(
                baseColor: baseColor,
                highlightColor: highlightColor,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 16.49.w,
                          height: 16.49.w,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                        ),
                        SizedBox(width: 8.25.w),
                        Container(
                          width: 110.w,
                          height: 14.h,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      width: 10.w,
                      height: 10.w,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Quick preset chips shimmer
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDark
                        ? AppColors.darkNav.withValues(alpha: 0.3)
                        : const Color(0xFFE7E0D8).withValues(alpha: 0.5),
                    width: 1.03.w,
                  ),
                ),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: 16.49.w,
                vertical: 14.43.h,
              ),
              child: Shimmer.fromColors(
                baseColor: baseColor,
                highlightColor: highlightColor,
                child: Row(
                  children: [
                    Container(
                      width: 60.w,
                      height: 28.h,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(100.r),
                      ),
                    ),
                    SizedBox(width: 17.52.w),
                    Container(
                      width: 50.w,
                      height: 28.h,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(100.r),
                      ),
                    ),
                    SizedBox(width: 17.52.w),
                    Container(
                      width: 50.w,
                      height: 28.h,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(100.r),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          // Month item rows shimmer
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 6,
              itemBuilder: (context, index) {
                return Container(
                  decoration: BoxDecoration(
                    border: index > 0
                        ? Border(
                            top: BorderSide(
                              color: isDark
                                  ? AppColors.darkNav.withValues(alpha: 0.3)
                                  : const Color(0xFFE7E0D8).withValues(alpha: 0.4),
                              width: 1.03.w,
                            ),
                          )
                        : null,
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.49.w,
                    vertical: 14.43.h,
                  ),
                  child: Shimmer.fromColors(
                    baseColor: baseColor,
                    highlightColor: highlightColor,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 80.w,
                          height: 14.h,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                        ),
                        Container(
                          width: 18.55.w,
                          height: 18.55.w,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class AppFilterChecklistShimmer extends StatelessWidget {
  const AppFilterChecklistShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = AppColors.shimmerBase(isDark);
    final highlightColor = AppColors.shimmerHighlight(isDark);

    return Container(
      color: isDark ? AppColors.darkBg : const Color(0xFFFBF8F5),
      child: ListView.builder(
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 6,
        itemBuilder: (context, index) {
          return Container(
            decoration: BoxDecoration(
              border: index > 0
                  ? Border(
                      top: BorderSide(
                        color: isDark
                            ? AppColors.darkNav.withValues(alpha: 0.3)
                            : const Color(0xFFE7E0D8).withValues(alpha: 0.4),
                        width: 1.w,
                      ),
                    )
                  : null,
            ),
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            child: Shimmer.fromColors(
              baseColor: baseColor,
              highlightColor: highlightColor,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 16.w,
                        height: 16.w,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Container(
                        width: 90.w,
                        height: 14.h,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    width: 20.w,
                    height: 20.w,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
