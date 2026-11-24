import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';
import 'package:office_app/core/theme/app_colors.dart';
import 'home_scale.dart';

class HomeShimmer extends StatelessWidget {
  const HomeShimmer({super.key});

  // Design height (before `.h`) of the placeholder blocks and gaps.
  static const double _naturalHeight = 200 + 20 + 165 + 20 + 165;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = HomeScale.fit(
          available: constraints.maxHeight,
          naturalHeight: _naturalHeight,
        );
        return SingleChildScrollView(
          child: SafeArea(
            top: false,
            bottom: true,
            left: false,
            right: false,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Shimmer.fromColors(
                baseColor: AppColors.shimmerBase(isDark),
                highlightColor: AppColors.shimmerHighlight(isDark),
                child: Column(
                  children: [
                    Container(
                      height: scale.h(200),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : AppColors.white,
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    SizedBox(height: scale.h(20)),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: scale.h(165),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.darkCard
                                  : AppColors.white,
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                          ),
                        ),
                        SizedBox(width: 14.w),
                        Expanded(
                          child: Container(
                            height: scale.h(165),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.darkCard
                                  : AppColors.white,
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: scale.h(20)),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: scale.h(165),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.darkCard
                                  : AppColors.white,
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                          ),
                        ),
                        SizedBox(width: 14.w),
                        Expanded(
                          child: Container(
                            height: scale.h(165),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.darkCard
                                  : AppColors.white,
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
