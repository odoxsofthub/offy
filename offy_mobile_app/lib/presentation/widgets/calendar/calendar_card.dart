import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_colors.dart';
import 'day_cell.dart';
import 'month_selector_header.dart';
import 'days_of_week_header.dart';

class CalendarCard extends StatefulWidget {
  final DateTime currentMonth;
  final DateTime selectedDate;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<DateTime> onDateSelected;
  final List<Color>? Function(DateTime date)? getEvents;
  final List<String>? Function(DateTime date)? getTooltipTitle;
  final List<String>? Function(DateTime date)? getTooltipSubtitle;
  final bool? showTooltip;
  final VoidCallback? onTooltipDismissed;
  final bool isLoading;
  final bool Function(DateTime date)? hasTooltipError;
  final ValueChanged<DateTime>? onTooltipRetry;

  const CalendarCard({
    super.key,
    required this.currentMonth,
    required this.selectedDate,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onDateSelected,
    this.getEvents,
    this.getTooltipTitle,
    this.getTooltipSubtitle,
    this.showTooltip,
    this.onTooltipDismissed,
    this.isLoading = false,
    this.hasTooltipError,
    this.onTooltipRetry,
  });

  @override
  State<CalendarCard> createState() => _CalendarCardState();
}

class _CalendarCardState extends State<CalendarCard> {
  double _calculateGridHeight(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    // Padding: horizontal screen padding (16.w * 2 = 32.w), card padding (12.w * 2 = 24.w)
    final double gridWidth = screenWidth - 32.w - 24.w;
    final double cellWidth = (gridWidth - 6 * 8.w) / 7;
    return 6 * cellWidth + 5 * 8.h;
  }

  Widget _buildMonthGrid(BuildContext context, DateTime month) {
    // Weekday of the first day (Monday = 1, Sunday = 7)
    final DateTime firstDayOfMonth = DateTime(month.year, month.month, 1);
    final DateTime lastDayOfMonth = DateTime(month.year, month.month + 1, 0);
    final int startWeekday = firstDayOfMonth.weekday;
    final int daysInMonth = lastDayOfMonth.day;

    final prevMonthLastDay = DateTime(
      month.year,
      month.month,
      0,
    ).day;
    final int prefixDaysCount = startWeekday - 1;
    final int totalCellsSoFar = prefixDaysCount + daysInMonth;
    final int suffixDaysCount = (7 - (totalCellsSoFar % 7)) % 7;
    final int totalCellsInGrid = totalCellsSoFar + suffixDaysCount;
    final int totalRows = totalCellsInGrid ~/ 7;

    // Calculate dynamic childAspectRatio so cells stretch to fill vertical space
    final double gridHeight = _calculateGridHeight(context);
    final double screenWidth = MediaQuery.of(context).size.width;
    final double gridWidth = screenWidth - 32.w - 24.w;
    final double cellWidth = (gridWidth - 6 * 8.w) / 7;

    final double totalSpacing = (totalRows - 1) * 8.h;
    final double availableHeightForCells = gridHeight - totalSpacing;
    final double rowHeight = availableHeightForCells / totalRows;
    final double childAspectRatio = cellWidth / rowHeight;

    final List<Widget> dayWidgets = [];

    // Add prefix days (previous month)
    for (int i = prefixDaysCount - 1; i >= 0; i--) {
      final int dayNum = prevMonthLastDay - i;
      final DateTime prevMonthDate = DateTime(
        month.month == 1 ? month.year - 1 : month.year,
        month.month == 1 ? 12 : month.month - 1,
        dayNum,
      );

      dayWidgets.add(
        DayCell(
          key: ValueKey('prefix-${prevMonthDate.year}-${prevMonthDate.month}-$dayNum'),
          day: dayNum,
          isCurrentMonth: false,
          isSelected: false,
          onTap: widget.isLoading ? null : () => widget.onDateSelected(prevMonthDate),
        ),
      );
    }

    // Add current month days
    final DateTime now = DateTime.now();
    for (int day = 1; day <= daysInMonth; day++) {
      final DateTime date = DateTime(month.year, month.month, day);
      final bool isSelected = date.year == widget.selectedDate.year &&
          date.month == widget.selectedDate.month &&
          date.day == widget.selectedDate.day;

      final bool isToday = now.year == date.year &&
          now.month == date.month &&
          now.day == date.day;

      final bool isBottomRow = (dayWidgets.length ~/ 7) >= (totalRows - 2);

      dayWidgets.add(
        DayCell(
          key: ValueKey('day-${date.year}-${date.month}-$day'),
          day: day,
          isCurrentMonth: true,
          isSelected: isSelected,
          events: widget.getEvents?.call(date),
          onTap: widget.isLoading ? null : () => widget.onDateSelected(date),
          tooltipTitles: widget.getTooltipTitle?.call(date),
          tooltipSubtitles: widget.getTooltipSubtitle?.call(date),
          isBottomRow: isBottomRow,
          showTooltip: isSelected && (widget.showTooltip ?? false),
          isToday: isToday,
          onTooltipDismissed: widget.onTooltipDismissed,
          hasTooltipError: widget.hasTooltipError?.call(date) ?? false,
          onTooltipRetry: () => widget.onTooltipRetry?.call(date),
        ),
      );
    }

    // Add suffix days to make complete weeks (rows of 7)
    for (int day = 1; day <= suffixDaysCount; day++) {
      final DateTime nextMonthDate = DateTime(
        month.month == 12 ? month.year + 1 : month.year,
        month.month == 12 ? 1 : month.month + 1,
        day,
      );

      dayWidgets.add(
        DayCell(
          key: ValueKey('suffix-${nextMonthDate.year}-${nextMonthDate.month}-$day'),
          day: day,
          isCurrentMonth: false,
          isSelected: false,
          onTap: widget.isLoading ? null : () => widget.onDateSelected(nextMonthDate),
          isBottomRow: true,
        ),
      );
    }

    return GridView.count(
      clipBehavior: Clip.none,
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 7,
      childAspectRatio: childAspectRatio,
      mainAxisSpacing: 8.h,
      crossAxisSpacing: 8.w,
      children: dayWidgets,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final String currentMonthYear =
        '${_getMonthName(widget.currentMonth.month)} ${widget.currentMonth.year}';

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.white,
        borderRadius: BorderRadius.circular(12.68.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0x0F2A2A2A),
            blurRadius: 21.14.r,
            offset: Offset(0, 4.22.h),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          MonthSelectorHeader(
            monthYear: currentMonthYear,
            isLoading: widget.isLoading,
            onPrevious: widget.onPreviousMonth,
            onNext: widget.onNextMonth,
          ),
          SizedBox(height: 25.37.h),
          const DaysOfWeekHeader(),
          SizedBox(height: 10.h),
          SizedBox(
            height: _calculateGridHeight(context),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragEnd: widget.isLoading
                  ? null
                  : (details) {
                      final velocity = details.primaryVelocity ?? 0;
                      if (velocity < -100) {
                        widget.onNextMonth();
                      } else if (velocity > 100) {
                        widget.onPreviousMonth();
                      }
                    },
              child: Stack(
                children: [
                  _buildMonthGrid(context, widget.currentMonth),
                  if (widget.isLoading)
                    Positioned.fill(
                      child: Container(
                        color: (isDark ? AppColors.darkCard : AppColors.white)
                            .withValues(alpha: 0.6),
                        child: const Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(AppColors.main),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return months[month - 1];
  }
}
