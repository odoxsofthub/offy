import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../viewmodels/attendance/attendance_log_provider.dart';
import '../../widgets/attendance/attendance_header.dart';
import '../../widgets/attendance/attendance_stats_row.dart';
import '../../widgets/attendance/attendance_log_list.dart';
import '../../widgets/attendance/attendance_log_shimmer.dart';
import '../../widgets/common/app_pagination_loader.dart';
import '../../widgets/empty_state/empty_state_view.dart';
import '../../../../l10n/app_localizations.dart';

import '../../viewmodels/home/home_navigation_provider.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.read<HomeNavigationProvider>().consumeSuppressNextTabFetch()) {
        return;
      }
      context.read<AttendanceLogProvider>().fetchLogs(refresh: true);
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200) {
      context.read<AttendanceLogProvider>().fetchLogs(refresh: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AttendanceLogProvider>();
    final logs = provider.logs;
    final bool isEmpty = logs.isEmpty && !provider.isLoading;
    final now = DateTime.now();
    final bool isCurrentMonth =
        provider.currentMonth == now.month && provider.currentYear == now.year;

    return Container(
      decoration: Theme.of(context).brightness == Brightness.dark
          ? const BoxDecoration(color: AppColors.darkBg)
          : const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.light, AppColors.light, Colors.white],
                stops: [0.0, 0.5375, 1.0],
              ),
            ),
      child: Column(
        children: [
          const AttendanceHeader(),
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: SafeArea(
                top: false,
                bottom: false,
                left: false,
                right: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 28.h),
                    AttendanceStatsRow(showStats: !isEmpty),
                    SizedBox(height: 28.h),
                    if (provider.isLoading && (logs.isEmpty || !isCurrentMonth))
                      const AttendanceLogShimmer()
                    else if (isEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: 32.h, bottom: 40.h),
                        child: EmptyStateView(
                          imagePath: AppAssets.noAttendances,
                          title: AppLocalizations.of(context)?.noAttendanceRecords ?? 'No attendance records',
                          subtitle: isCurrentMonth
                              ? AppLocalizations.of(context)?.checkInToStart ?? 'Check in to start tracking \nyour attendance.'
                              : AppLocalizations.of(context)?.noRecordsThisMonth ?? 'No attendance records found \nfor this month.',
                        ),
                      )
                    else
                      AttendanceLogList(
                        logs: logs,
                        isTopCardLoading: provider.isLoading && isCurrentMonth,
                      ),
                    if (provider.isLoadingMore) ...[
                      SizedBox(height: 16.h),
                      const AppPaginationLoader(),
                    ],
                    SizedBox(height: 24.h),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
