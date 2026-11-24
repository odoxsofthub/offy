import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/attendance_log_response_model.dart';
import '../../../../l10n/app_localizations.dart';
import '../../common/custom_back_button.dart';
import 'attendance_day_summary_header.dart';
import 'attendance_logged_hours_card.dart';

class AttendanceDayDetailAppBar extends StatelessWidget {
  final AttendanceLogEntryModel log;

  const AttendanceDayDetailAppBar({
    super.key,
    required this.log,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);

    return Container(
      decoration: BoxDecoration(
        gradient: isDark
            ? const LinearGradient(
                begin: Alignment(-0.99, -0.11),
                end: Alignment(0.99, 0.11),
                colors: [
                  AppColors.darkTopCard,
                  AppColors.darkBg,
                  AppColors.darkCard,
                ],
              )
            : const LinearGradient(
                begin: Alignment(-0.99, -0.11),
                end: Alignment(0.99, 0.11),
                colors: [
                  Color(0xFFFFE1D7),
                  Color(0xFFFFFFFF),
                  Color(0xFFFAE1C8),
                ],
                stops: [0.2147, 0.5242, 0.8887],
              ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Navigation Row
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const CustomBackButton(),
                  Text(
                    loc?.attendance ?? 'Attendance',
                    style: TextStyle(
                      fontSize: 22.sp,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.white : AppColors.black,
                      height: 20 / 22,
                    ),
                  ),
                  SizedBox(width: 41.27.w),
                ],
              ),
            ),
            // Day Summary Header (Date, Shift Time, Status)
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 34.73.h, 16.w, 0),
              child: AttendanceDaySummaryHeader(log: log),
            ),
            // Logged Hours Card
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 16.h),
              child: AttendanceLoggedHoursCard(log: log),
            ),
          ],
        ),
      ),
    );
  }
}
