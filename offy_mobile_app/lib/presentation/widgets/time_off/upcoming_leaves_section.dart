import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../core/utils/date_formatter.dart';

import '../common/two_lines_scaled_text.dart';
import '../../screens/time_off/upcoming_leaves_list_screen.dart';
import '../../viewmodels/time_off/time_off_provider.dart';
import 'leave_item.dart';
import '../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';

class UpcomingLeavesSection extends StatelessWidget {
  final VoidCallback? onReturnFromDetail;

  const UpcomingLeavesSection({super.key, this.onReturnFromDetail});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final sectionTitleStyle = TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 20.sp,
      height: 28 / 20,
      letterSpacing: 0,
      color: isDark ? AppColors.white : const Color(0xFF1B1C1C),
    );

    final provider = context.watch<TimeOffProvider>();
    final upcomingLeaves = provider.upcomingOverviewLeaves;
    final isInitialLoading = provider.isLoading && provider.timeOffData == null;

    if (!isInitialLoading && upcomingLeaves.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 27.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: TwoLinesScaledText(
                text:
                    AppLocalizations.of(context)?.upcomingLeaves ??
                    'Upcoming Leaves',
                style: sectionTitleStyle,
              ),
            ),
            if (upcomingLeaves.isNotEmpty)
              InkWell(
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (newContext) => ChangeNotifierProvider.value(
                        value: context.read<TimeOffProvider>(),
                        child: const UpcomingLeavesListScreen(),
                      ),
                    ),
                  );
                  if (result == true) {
                    onReturnFromDetail?.call();
                  }
                },
                borderRadius: BorderRadius.circular(6.r),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
                  child: Text(
                    AppLocalizations.of(context)?.viewAll ?? 'View All',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w400,
                      height: 24 / 16,
                      color: isDark ? AppColors.main : const Color(0xFFB02F00),
                    ),
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: 16.h),
        if (isInitialLoading)
          Shimmer.fromColors(
            baseColor: AppColors.shimmerBase(isDark),
            highlightColor: AppColors.shimmerHighlight(isDark),
            child: const Column(
              children: [
                LeaveItem(
                  month: 'JUL',
                  day: '00',
                  title: 'Annual Leave',
                  durationText: '0 Days',
                  isApproved: true,
                ),
                LeaveItem(
                  month: 'AUG',
                  day: '00',
                  title: 'Sick Leave',
                  durationText: '0 Days',
                  isApproved: false,
                ),
              ],
            ),
          )
        else
          ...upcomingLeaves.take(3).toList().asMap().entries.map((entry) {
            final index = entry.key;
            final leave = entry.value;
            final isLast = index == (upcomingLeaves.take(3).length - 1);
            final dateFrom = DateTime.tryParse(leave.dateFrom);

            final month = dateFrom != null
                ? AppDateFormatter.mmmUppercase(dateFrom)
                : '';
            final day = dateFrom != null ? AppDateFormatter.dd(dateFrom) : '';
            final durationText =
                '${leave.days} Day${leave.days > 1 ? 's' : ''} · ${leave.leaveType?.name ?? (AppLocalizations.of(context)?.leave ?? 'Leave')}';

            return LeaveItem(
              month: month,
              day: day,
              title: leave.name,
              durationText: durationText,
              isApproved: leave.stage.toLowerCase() == 'approved',
              leave: leave,
              isLast: isLast,
            );
          }),
      ],
    );
  }
}
