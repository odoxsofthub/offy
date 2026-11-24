import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../viewmodels/time_off/time_off_provider.dart';
import '../../viewmodels/user/access_provider.dart';

import 'package:office_app/presentation/widgets/calendar/calendar_card.dart';
import '../../widgets/common/custom_screen_header.dart';
import '../../widgets/time_off/leave_balances_card.dart';
import '../../widgets/time_off/upcoming_leaves_section.dart';
import '../../widgets/time_off/leave_history_section.dart';
import '../../widgets/time_off/new_leave_request_bottom_sheet.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../core/network/network_interceptor.dart';

class TimeOffPage extends StatefulWidget {
  const TimeOffPage({super.key});

  @override
  State<TimeOffPage> createState() => _TimeOffPageState();
}

class _TimeOffPageState extends State<TimeOffPage> {
  DateTime _currentMonth = DateTime.now();
  DateTime _selectedDate = DateTime.now();
  bool _showTooltip = false;
  bool _wasOffline = false;

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _fetchMonthData() async {
    if (!mounted) return;
    await context.read<TimeOffProvider>().fetchTimeOffCalendarMonth(
      year: _currentMonth.year,
      month: _currentMonth.month,
    );
  }

  Future<void> _fetchDaySchedule(DateTime date) async {
    if (!mounted) return;
    await context.read<TimeOffProvider>().fetchTimeOffCalendarDay(
      date: _formatDate(date),
    );
  }

  Future<void> _refreshAllData() async {
    if (!mounted) return;
    final provider = context.read<TimeOffProvider>();
    await Future.wait([
      provider.fetchTimeOffData(),
      provider.fetchAvailableTypes(),
      _fetchMonthData(),
      _fetchDaySchedule(_selectedDate),
    ]);
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
      _showTooltip = false;
    });
    _fetchMonthData();
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
      _showTooltip = false;
    });
    _fetchMonthData();
  }

  @override
  void initState() {
    super.initState();
    _wasOffline = NetworkInterceptor.instance.isOfflineBlocking;
    NetworkInterceptor.instance.addListener(_onNetworkStateChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<TimeOffProvider>();
      provider.fetchTimeOffData();
      provider.fetchAvailableTypes();
      _fetchMonthData();
      _fetchDaySchedule(_selectedDate);
    });
  }

  void _onNetworkStateChange() {
    if (!mounted) return;
    final isOffline = NetworkInterceptor.instance.isOfflineBlocking;
    if (_wasOffline && !isOffline) {
      _wasOffline = false;
      _refreshAllData();
    } else {
      _wasOffline = isOffline;
    }
  }

  @override
  void dispose() {
    NetworkInterceptor.instance.removeListener(_onNetworkStateChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TimeOffProvider>();
    final hasTimeOff = context.watch<AccessProvider>().hasFeature('time_off');

    final balances = provider.timeOffData?.balances ?? [];
    final hasLoadedAllInitialData =
        provider.timeOffData != null && provider.availableTypes.isNotEmpty;
    final showBalancesCard =
        (provider.isLoading && !hasLoadedAllInitialData) || balances.isNotEmpty;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: isDark ? AppColors.darkBg : Colors.white,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkTopCard
            : AppColors.midLight,
        body: Container(
          decoration: isDark
              ? const BoxDecoration(color: AppColors.darkBg)
              : const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFF3E9E0), Colors.white],
                    stops: [0.5375, 1.0],
                  ),
                ),
          child: Stack(
            children: [
              Column(
                children: [
                  CustomScreenHeader(
                    isSubmitting: false,
                    title:
                        AppLocalizations.of(context)?.timeOffTitle ??
                        'Time off',
                    centerTitle: false,
                    trailing: hasTimeOff
                        ? GestureDetector(
                            onTap: () {
                              final provider = context.read<TimeOffProvider>();
                              provider.clearCalculatedDuration();
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                enableDrag: false,
                                backgroundColor: Colors.transparent,
                                barrierColor: const Color(0xB2000000),
                                builder: (context) => BackdropFilter(
                                  filter: ImageFilter.blur(
                                    sigmaX: 4,
                                    sigmaY: 4,
                                  ),
                                  child: ChangeNotifierProvider.value(
                                    value: provider,
                                    child: NewLeaveRequestBottomSheet(
                                      initialDate: _selectedDate,
                                    ),
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              padding: EdgeInsets.all(8.64.r),
                              decoration: BoxDecoration(
                                color: AppColors.main.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(86.36.r),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.add,
                                    size: 24.r,
                                    color: AppColors.white,
                                  ),
                                  SizedBox(width: 4.64.w),
                                  Text(
                                    AppLocalizations.of(context)?.newLabel ??
                                        'New',
                                    style: TextStyle(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w400,
                                      height: 20 / 16,
                                      color: AppColors.white,
                                    ),
                                  ),
                                  SizedBox(width: 5.5.w),
                                ],
                              ),
                            ),
                          )
                        : null,
                  ),
                  Expanded(
                    child: SafeArea(
                      top: false,
                      child: RefreshIndicator(
                        onRefresh: _refreshAllData,
                        color: const Color(0xFFFD5223),
                        child: SingleChildScrollView(
                          key: const PageStorageKey<String>(
                            'time_off_scroll_view',
                          ),
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: ClampingScrollPhysics(),
                          ),
                          padding: EdgeInsets.fromLTRB(16.w, 28.h, 16.w, 27.h),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 1. Leave Balances Container
                              if (showBalancesCard) ...[
                                const LeaveBalancesCard(),
                                SizedBox(height: 27.h),
                              ],

                              // 2. Calendar Card
                              CalendarCard(
                                currentMonth: _currentMonth,
                                selectedDate: _selectedDate,
                                isLoading: provider.isCalendarMonthLoading,
                                onPreviousMonth: _previousMonth,
                                onNextMonth: _nextMonth,
                                onDateSelected: (date) {
                                  setState(() {
                                    if (date.year == _selectedDate.year &&
                                        date.month == _selectedDate.month &&
                                        date.day == _selectedDate.day) {
                                      _showTooltip = !_showTooltip;
                                    } else {
                                      _selectedDate = date;
                                      _showTooltip = true;
                                      if (date.year != _currentMonth.year ||
                                          date.month != _currentMonth.month) {
                                        _currentMonth = DateTime(
                                          date.year,
                                          date.month,
                                          1,
                                        );
                                        _fetchMonthData();
                                      }
                                    }
                                  });
                                  _fetchDaySchedule(date);
                                },
                                getEvents: (date) =>
                                    provider.getEventsForDate(date),
                                getTooltipTitle: (date) {
                                  if (date.year == _selectedDate.year &&
                                      date.month == _selectedDate.month &&
                                      date.day == _selectedDate.day) {
                                    if (provider.isCalendarDayLoading) {
                                      return const [];
                                    }
                                    final schedule =
                                        provider.selectedDaySchedule;
                                    final selectedFormatted =
                                        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                                    if (schedule != null &&
                                        schedule.date == selectedFormatted) {
                                      final items = schedule.items;
                                      if (items.isNotEmpty) {
                                        return items
                                            .map((e) => e.title)
                                            .toList();
                                      }
                                    }
                                  }
                                  return null;
                                },
                                getTooltipSubtitle: (date) {
                                  if (date.year == _selectedDate.year &&
                                      date.month == _selectedDate.month &&
                                      date.day == _selectedDate.day) {
                                    if (provider.isCalendarDayLoading) {
                                      return const [];
                                    }
                                    final schedule =
                                        provider.selectedDaySchedule;
                                    final selectedFormatted =
                                        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                                    if (schedule != null &&
                                        schedule.date == selectedFormatted) {
                                      final items = schedule.items;
                                      if (items.isNotEmpty) {
                                        return items
                                            .map(
                                              (e) => e.subtitle.isNotEmpty
                                                  ? e.subtitle
                                                  : e.leaveType,
                                            )
                                            .toList();
                                      }
                                    }
                                  }
                                  return null;
                                },
                                showTooltip: _showTooltip,
                                onTooltipDismissed: () {
                                  setState(() {
                                    _showTooltip = false;
                                  });
                                },
                                hasTooltipError: (date) {
                                  if (date.year == _selectedDate.year &&
                                      date.month == _selectedDate.month &&
                                      date.day == _selectedDate.day) {
                                    return provider.calendarDayError != null;
                                  }
                                  return false;
                                },
                                onTooltipRetry: (date) {
                                  _fetchDaySchedule(date);
                                },
                              ),

                              // 3. Upcoming Leaves Section
                              UpcomingLeavesSection(
                                onReturnFromDetail: _refreshAllData,
                              ),

                              // 4. Leave History Section
                              LeaveHistorySection(
                                onReturnFromDetail: _refreshAllData,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
