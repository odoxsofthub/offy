import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/attendance_log_response_model.dart';

class AttendanceDaySummaryHeader extends StatelessWidget {
  final AttendanceLogEntryModel log;

  const AttendanceDaySummaryHeader({
    super.key,
    required this.log,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final String statusText = log.displayStatus;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Left Column: Date & Shift Time
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Date Row
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 13.sp,
                    color: isDark ? AppColors.white : AppColors.tertiary,
                  ),
                  SizedBox(width: 8.w),
                  Flexible(
                    child: Text(
                      log.date,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppColors.white : AppColors.tertiary,
                        height: 18 / 14,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4.h),
              // Time Range
              Text(
                log.timeInfo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w400,
                  color: isDark
                      ? AppColors.white.withValues(alpha: 0.8)
                      : AppColors.tertiary,
                  height: 20 / 14,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 12.w),
        // Right: Status Pill
        if (log.status != AttendanceLogStatus.none)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.white,
              borderRadius: BorderRadius.circular(9999.r),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (log.status == AttendanceLogStatus.completed)
                  SvgPicture.asset(
                    AppAssets.completedStatus,
                    width: 11.67.w,
                    height: 11.67.w,
                  )
                else
                  Container(
                    width: 9.67.w,
                    height: 9.67.w,
                    decoration: const BoxDecoration(
                      color: AppColors.main,
                      shape: BoxShape.circle,
                    ),
                  ),
                SizedBox(width: 6.w),
                Text(
                  statusText,
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w400,
                    color: isDark ? AppColors.white : AppColors.tertiary,
                    height: 16 / 12,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
