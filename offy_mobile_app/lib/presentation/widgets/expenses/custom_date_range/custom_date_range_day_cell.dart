import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';

class CustomDateRangeDayCell extends StatelessWidget {
  final int? dayNumber;
  final bool isStart;
  final bool isEnd;
  final bool isInRange;
  final VoidCallback? onTap;

  const CustomDateRangeDayCell({
    super.key,
    this.dayNumber,
    this.isStart = false,
    this.isEnd = false,
    this.isInRange = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (dayNumber == null) {
      return const AspectRatio(aspectRatio: 1, child: SizedBox.shrink());
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEndpoint = isStart || isEnd;

    BoxDecoration decoration;
    TextStyle textStyle;

    if (isEndpoint) {
      decoration = BoxDecoration(
        color: AppColors.main,
        borderRadius: BorderRadius.circular(20.r),
      );
      textStyle = TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 15.sp,
        height: 18 / 15,
        color: AppColors.white,
      );
    } else if (isInRange) {
      decoration = BoxDecoration(
        color: AppColors.main.withValues(alpha: 0.101961),
        borderRadius: BorderRadius.circular(4.r),
      );
      textStyle = TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 15.sp,
        height: 18 / 15,
        color: AppColors.main,
      );
    } else {
      decoration = BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20.r),
      );
      textStyle = TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 15.sp,
        height: 18 / 15,
        color: isDark ? AppColors.white : Colors.black,
      );
    }

    return AspectRatio(
      aspectRatio: 1,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 2.w),
        child: InkWell(
          onTap: onTap,
          borderRadius: decoration.borderRadius as BorderRadius?,
          child: Container(
            decoration: decoration,
            alignment: Alignment.center,
            child: Text('$dayNumber', style: textStyle),
          ),
        ),
      ),
    );
  }
}
