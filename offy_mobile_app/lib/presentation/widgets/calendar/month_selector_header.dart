import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_colors.dart';

class MonthSelectorHeader extends StatelessWidget {
  final String monthYear;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final bool isLoading;

  const MonthSelectorHeader({
    super.key,
    required this.monthYear,
    required this.onPrevious,
    required this.onNext,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          monthYear,
          style: TextStyle(
            fontSize: 24.sp,
            fontWeight: FontWeight.w600,
            height: 34 / 24,
            letterSpacing: -0.25.sp,
            color: isDark ? AppColors.white : AppColors.black,
          ),
        ),
        Row(
          children: [
            GestureDetector(
              onTap: isLoading ? null : onPrevious,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: EdgeInsets.all(5.w),
                child: Opacity(
                  opacity: isLoading ? 0.5 : 1.0,
                  child: Container(
                    width: 33.83.w,
                    height: 33.83.h,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEAE7E7),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.chevron_left_rounded,
                      color: AppColors.tertiary,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: 2.69.w),
            GestureDetector(
              onTap: isLoading ? null : onNext,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: EdgeInsets.all(5.w),
                child: Opacity(
                  opacity: isLoading ? 0.5 : 1.0,
                  child: Container(
                    width: 33.83.w,
                    height: 33.83.h,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEAE7E7),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.tertiary,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
