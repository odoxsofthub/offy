import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/calendar_day_schedule_model.dart';
import 'meeting_item.dart';
import 'schedule_shimmer.dart';

class ScheduleSection extends StatelessWidget {
  final DateTime selectedDate;
  final CalendarDayScheduleModel? schedule;
  final bool isLoading;
  final void Function(CalendarScheduleItemModel item)? onItemTap;

  const ScheduleSection({
    super.key,
    required this.selectedDate,
    this.schedule,
    this.isLoading = false,
    this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final bool isSelectedToday =
        selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;
    final l10n = AppLocalizations.of(context);
    final String titleText = isSelectedToday
        ? l10n?.todaysSchedule ?? "Today's Schedule"
        : l10n?.schedule ?? "Schedule";
    final String formattedDate = DateFormat(
      'EEEE, MMMM d',
    ).format(selectedDate);

    final List<Widget> scheduleWidgets = [];

    if (isLoading) {
      scheduleWidgets.add(const ScheduleShimmer());
    } else if (schedule == null || schedule!.items.isEmpty) {
      scheduleWidgets.add(
        Container(
          height: 150.h,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(12.r),
            boxShadow: [
              BoxShadow(
                color: const Color(0x0F2A2A2A),
                offset: const Offset(0, 4),
                blurRadius: 20.r,
              ),
            ],
          ),
          child: Center(
            child: Text(
              AppLocalizations.of(context)?.noEventsScheduled ??
                  'No events scheduled for this day',
              style: TextStyle(
                color: isDark ? const Color(0xFFEAE1D8) : Colors.grey[600],
                fontSize: 14.sp,
              ),
            ),
          ),
        ),
      );
    } else {
      final items = schedule!.items;
      for (int i = 0; i < items.length; i++) {
        final item = items[i];
        final String displaySubtitle = item.allDay
            ? (item.subtitle.isNotEmpty ? item.subtitle : item.leaveType)
            : (item.timeDisplay.isNotEmpty
                  ? AppDateFormatter.formatTimeDisplay(item.timeDisplay)
                  : (item.subtitle.isNotEmpty
                        ? item.subtitle
                        : item.leaveType));

        scheduleWidgets.add(
          MeetingItem(
            title: item.title,
            subtitle: displaySubtitle,
            accentColor: item.accentColor,
            onTap: onItemTap != null ? () => onItemTap!(item) : null,
            icon: !item.allDay ? Icons.access_time_outlined : null,
          ),
        );
        if (i < items.length - 1) {
          scheduleWidgets.add(SizedBox(height: 12.h));
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              titleText,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w400,
                height: 24 / 16,
                color: isDark ? AppColors.white : AppColors.black,
              ),
            ),
            Text(
              formattedDate,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w500,
                height: 18 / 13,
                color: const Color(0xFFB02F00),
              ),
            ),
          ],
        ),
        SizedBox(height: 16.h),
        ...scheduleWidgets,
      ],
    );
  }
}
