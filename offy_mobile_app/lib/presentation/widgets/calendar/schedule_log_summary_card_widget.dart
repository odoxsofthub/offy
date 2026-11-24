import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';

class ScheduleLogSummaryCardWidget extends StatelessWidget {
  final String title;
  final String startTime;
  final String endTime;
  final String description;
  final bool allDay;
  final String timeDisplay;
  final double? maxContentHeight;
  final bool isCompact;

  const ScheduleLogSummaryCardWidget({
    super.key,
    this.title = '',
    this.startTime = '',
    this.endTime = '',
    this.description = '',
    this.allDay = true,
    this.timeDisplay = '',
    this.maxContentHeight,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final String dateDisplay = AppDateFormatter.formatCalendarLogRangeStr(
      startTime,
      endTime,
    );

    final String finalTimeOrDateDisplay = !allDay && timeDisplay.isNotEmpty
        ? timeDisplay
        : dateDisplay;

    if (isCompact) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12.r),
          boxShadow: [
            BoxShadow(
              color: const Color(0x0F2A2A2A),
              blurRadius: 20.r,
              offset: Offset(0, 4.h),
            ),
          ],
        ),
        child: Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
            height: 24 / 18,
            color: isDark ? AppColors.white : AppColors.black,
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0x0F2A2A2A),
            blurRadius: 20.r,
            offset: Offset(0, 4.h),
          ),
        ],
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxContentHeight ?? 140.h),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w600,
                  height: 24 / 18,
                  color: isDark ? AppColors.white : AppColors.black,
                ),
              ),
              SizedBox(height: 8.h),
              Row(
                children: [
                  if (!allDay) ...[
                    Icon(
                      Icons.access_time_rounded,
                      size: 16.r,
                      color: AppColors.secondary,
                    ),
                    SizedBox(width: 6.w),
                  ],
                  Flexible(
                    child: Text(
                      finalTimeOrDateDisplay,
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w400,
                        height: 1,
                        color: AppColors.secondary,
                      ),
                    ),
                  ),
                ],
              ),
              if (description.isNotEmpty) ...[
                SizedBox(height: 8.h),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w400,
                    height: 20 / 14,
                    color: AppColors.navColor,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
