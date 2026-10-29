import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_colors.dart';

class LeavePeriodBanner extends StatelessWidget {
  final String title;
  final bool isFirst;

  const LeavePeriodBanner({
    super.key,
    required this.title,
    this.isFirst = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardColor = isDark ? AppColors.darkCard : const Color(0xFFFFF6ED);
    final textColor = isDark ? AppColors.white : AppColors.black;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: isFirst ? 0 : 12.h, bottom: 14.h),
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
    );
  }
}
