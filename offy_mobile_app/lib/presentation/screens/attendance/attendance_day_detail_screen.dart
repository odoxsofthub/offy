import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/attendance_log_response_model.dart';
import '../../widgets/attendance/day_detail/attendance_day_detail_app_bar.dart';
import '../../widgets/attendance/day_detail/attendance_timeline_list.dart';

class AttendanceDayDetailScreen extends StatelessWidget {
  final AttendanceLogEntryModel log;

  const AttendanceDayDetailScreen({
    super.key,
    required this.log,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBg : AppColors.light,
        body: Container(
          decoration: isDark
              ? const BoxDecoration(color: AppColors.darkBg)
              : const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.light,
                      AppColors.light,
                      AppColors.white,
                    ],
                    stops: [0.0, 0.8438, 1.0],
                  ),
                ),
          child: Column(
            children: [
              // Top Header Gradient App Bar
              AttendanceDayDetailAppBar(log: log),

              // Scrollable Timeline List below the App Bar
              Expanded(
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(16.w, 28.h, 16.w, 24.h),
                    child: AttendanceTimelineList(
                      sessions: log.effectiveSessions,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

