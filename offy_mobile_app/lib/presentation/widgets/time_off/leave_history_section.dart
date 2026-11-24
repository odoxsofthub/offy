import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/navigation/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../screens/time_off/leave_history_list_screen.dart';
import '../../viewmodels/time_off/time_off_provider.dart';
import '../common/two_lines_scaled_text.dart';
import 'leave_history_shimmer.dart';
import 'leave_item.dart';

class LeaveHistorySection extends StatelessWidget {
  final VoidCallback? onReturnFromDetail;

  const LeaveHistorySection({super.key, this.onReturnFromDetail});

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
    final historyLeaves = provider.timeOffData?.history ?? [];
    final isInitialLoading = provider.isLoading && provider.timeOffData == null;

    if (!isInitialLoading && historyLeaves.isEmpty) {
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
                    AppLocalizations.of(context)?.leaveHistory ??
                    'Leave History',
                style: sectionTitleStyle,
              ),
            ),
            if (historyLeaves.isNotEmpty)
              InkWell(
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      settings: const RouteSettings(
                        name: AppRouter.leaveHistory,
                      ),
                      builder: (newContext) => ChangeNotifierProvider.value(
                        value: context.read<TimeOffProvider>(),
                        child: const LeaveHistoryListScreen(),
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
        SizedBox(height: 12.h),
        if (isInitialLoading)
          const LeaveHistoryShimmer(itemCount: 2)
        else
          ...historyLeaves.asMap().entries.map(
            (entry) => LeaveItem(
              leave: entry.value,
              isLast: entry.key == historyLeaves.length - 1,
            ),
          ),
      ],
    );
  }
}
