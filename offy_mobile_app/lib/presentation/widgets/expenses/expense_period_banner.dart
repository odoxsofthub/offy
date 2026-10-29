import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_colors.dart';

class ExpensePeriodBanner extends StatelessWidget {
  final String title;
  final String amount;
  final bool isFirst;

  const ExpensePeriodBanner({
    super.key,
    required this.title,
    required this.amount,
    this.isFirst = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Card background: #FFF6ED in light mode per user specification,
    // and distinct darkCard/darkTopCard in dark mode to remain distinct from page background.
    final cardColor = isDark ? AppColors.darkCard : const Color(0xFFFFF6ED);
    final textColor = isDark ? AppColors.white : AppColors.black;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: 0, bottom: 14.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: cardColor,
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? AppColors.darkNav.withValues(alpha: 0.25)
                : AppColors.shade.withValues(alpha: 0.35),
            width: 1.w,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                height: 20 / 14,
                letterSpacing: 0,
                color: textColor,
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                amount,
                maxLines: 1,
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  height: 22 / 16,
                  letterSpacing: 0,
                  color: textColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
