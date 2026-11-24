import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import 'custom_date_range_day_cell.dart';

class CustomDateRangeCalendar extends StatelessWidget {
  final DateTime displayedMonth;
  final DateTime? startDate;
  final DateTime? endDate;
  final ValueChanged<DateTime> onDateSelected;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  const CustomDateRangeCalendar({
    super.key,
    required this.displayedMonth,
    required this.startDate,
    required this.endDate,
    required this.onDateSelected,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  bool _isSameDay(DateTime a, DateTime? b) {
    if (b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isInRange(DateTime date) {
    if (startDate == null || endDate == null) return false;
    final cleanDate = DateTime(date.year, date.month, date.day);
    final cleanStart = DateTime(
      startDate!.year,
      startDate!.month,
      startDate!.day,
    );
    final cleanEnd = DateTime(endDate!.year, endDate!.month, endDate!.day);
    return cleanDate.isAfter(cleanStart) && cleanDate.isBefore(cleanEnd);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final monthYearText = DateFormat('MMMM yyyy').format(displayedMonth);
    const dayNames = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

    final firstDayOfMonth = DateTime(
      displayedMonth.year,
      displayedMonth.month,
      1,
    );
    final daysInMonth = DateTime(
      displayedMonth.year,
      displayedMonth.month + 1,
      0,
    ).day;
    // Monday is 1, Sunday is 7 -> offset is 0 for Monday, 6 for Sunday
    final prefixOffset = firstDayOfMonth.weekday - 1;
    final totalCells = prefixOffset + daysInMonth;
    final rowCount = (totalCells / 7).ceil();

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity < -100) {
          onNextMonth();
        } else if (velocity > 100) {
          onPreviousMonth();
        }
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.white,
          border: Border.all(
            color: isDark
                ? AppColors.darkNav.withValues(alpha: 0.4)
                : AppColors.midLight,
            width: 1.w,
          ),
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Month Navigation Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  monthYearText,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16.sp,
                    height: 19 / 16,
                    color: isDark ? AppColors.white : Colors.black,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 8.w),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildNavButton(
                    isDark: isDark,
                    icon: Icons.chevron_left_rounded,
                    onTap: onPreviousMonth,
                  ),
                  SizedBox(width: 16.w),
                  _buildNavButton(
                    isDark: isDark,
                    icon: Icons.chevron_right_rounded,
                    onTap: onNextMonth,
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 16.h),
          // Day Names Row
          Row(
            children: dayNames.map((day) {
              return Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12.sp,
                      height: 14 / 12,
                      color: const Color(0xFF8E837D),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: 16.h),
          // Calendar Days Grid
          Column(
            children: List.generate(rowCount, (rowIndex) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom: rowIndex == rowCount - 1 ? 0 : 4.h,
                ),
                child: Row(
                  children: List.generate(7, (colIndex) {
                    final cellIndex = rowIndex * 7 + colIndex;
                    final dayNumber = cellIndex - prefixOffset + 1;

                    if (dayNumber < 1 || dayNumber > daysInMonth) {
                      return const Expanded(
                        child: CustomDateRangeDayCell(),
                      );
                    }

                    final cellDate = DateTime(
                      displayedMonth.year,
                      displayedMonth.month,
                      dayNumber,
                    );

                    final isStart = _isSameDay(cellDate, startDate);
                    final isEnd = _isSameDay(cellDate, endDate);
                    final inRange = _isInRange(cellDate);
                    return Expanded(
                      child: CustomDateRangeDayCell(
                        dayNumber: dayNumber,
                        isStart: isStart,
                        isEnd: isEnd,
                        isInRange: inRange,
                        onTap: () => onDateSelected(cellDate),
                      ),
                    );
                  }),
                ),
              );
            }),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildNavButton({
    required bool isDark,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8.r),
      child: Container(
        width: 26.w,
        height: 26.w,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkTertiary : const Color(0xFFF9F6F0),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Icon(
          icon,
          size: 14.sp,
          color: isDark ? AppColors.white : Colors.black,
        ),
      ),
    );
  }
}
