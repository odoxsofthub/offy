import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/theme/app_colors.dart';
import '../../viewmodels/attendance/attendance_log_provider.dart';
import 'month_year_picker_dialog.dart';
import '../../../../l10n/app_localizations.dart';

class AttendanceStatsRow extends StatelessWidget {
  final bool showStats;

  const AttendanceStatsRow({
    super.key,
    this.showStats = true,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AttendanceLogProvider>();
    final selectedDate = DateTime(provider.currentYear, provider.currentMonth);
    final formattedDate =
        DateFormat('MMMM yyyy').format(selectedDate).toUpperCase();

    Future<void> openMonthYearPicker() async {
      if (provider.isLoading) return;
      final selected = await MonthYearPickerDialog.show(
        context: context,
        initialDate: selectedDate,
        maxDate: DateTime.now(),
      );

      if (selected != null) {
        if (!context.mounted) return;
        context
            .read<AttendanceLogProvider>()
            .updateDateFilter(selected.month, selected.year);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // "Recent Logs" heading with month badge
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              AppLocalizations.of(context)?.recentLogs ?? 'Recent Logs',
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.white
                    : AppColors.black,
                height: 28 / 20,
              ),
            ),
            GestureDetector(
              onTap: provider.isLoading ? null : openMonthYearPicker,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_month_outlined,
                      size: 15.w,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.main
                          : const Color(0xFF5B4039),
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      formattedDate,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.main
                          : const Color(0xFF5B4039),
                        height: 16 / 12,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (showStats) ...[
          SizedBox(height: 28.h),
          // Two stat cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  context,
                  icon: Icons.timer_outlined,
                  label: AppLocalizations.of(context)?.avgInTime ?? 'AVG. IN-TIME',
                  value: provider.avgInTime,
                  isLoading: provider.isLoading,
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: _buildStatCard(
                  context,
                  icon: Icons.calendar_month_outlined,
                  label: AppLocalizations.of(context)?.avgWorked ?? 'AVG. WORKED',
                  value: provider.avgWorkedHour,
                  isLoading: provider.isLoading,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    bool isLoading = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.only(
        top: 10.h,
        right: 16.w,
        bottom: 10.h,
        left: 16.w,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkCard
            : Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0x0F2A2A2A),
            blurRadius: 20.r,
            offset: Offset(0, 4.h),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: isDark
                ? AppColors.main
                : AppColors.secondary,
            size: 24.w,
          ),
          SizedBox(height: 8.h),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppColors.white
                  : AppColors.tertiary,
              height: 16 / 12,
              letterSpacing: 0.6,
            ),
          ),
          SizedBox(
            height: 28.h,
            child: Align(
              alignment: Alignment.centerLeft,
              child: isLoading
                  ? Shimmer.fromColors(
                      baseColor: AppColors.shimmerBase(isDark),
                      highlightColor: AppColors.shimmerHighlight(isDark),
                      child: Container(
                        width: 50.w,
                        height: 18.h,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                      ),
                    )
                  : Text(
                      value,
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.white
                            : AppColors.black,
                        height: 28 / 20,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
