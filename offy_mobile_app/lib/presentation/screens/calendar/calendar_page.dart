import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../viewmodels/calendar/calendar_provider.dart';
import '../../widgets/calendar/calendar_card.dart';
import '../../widgets/calendar/schedule_section.dart';
import '../../widgets/calendar/new_event_bottom_sheet.dart';
import '../../widgets/common/custom_screen_header.dart';
import '../../../core/navigation/app_router.dart';
import '../../../core/network/network_interceptor.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _currentMonth = DateTime.now();
  DateTime _selectedDate = DateTime.now();
  bool _showTooltip = false;
  bool _wasOffline = false;

  @override
  void initState() {
    super.initState();
    _wasOffline = NetworkInterceptor.instance.isOfflineBlocking;
    NetworkInterceptor.instance.addListener(_onNetworkStateChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
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

  String _formatDate(DateTime date) {
    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  void _fetchMonthData() {
    final calendarProvider = context.read<CalendarProvider>();
    calendarProvider.fetchCalendarMonth(
      year: _currentMonth.year,
      month: _currentMonth.month,
    );
  }

  void _fetchDaySchedule(DateTime date) {
    final calendarProvider = context.read<CalendarProvider>();
    calendarProvider.fetchCalendarDay(date: _formatDate(date));
  }

  Future<void> _refreshAllData() async {
    final calendarProvider = context.read<CalendarProvider>();
    await Future.wait([
      calendarProvider.fetchCalendarMonth(
        year: _currentMonth.year,
        month: _currentMonth.month,
      ),
      calendarProvider.fetchCalendarDay(date: _formatDate(_selectedDate)),
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
  Widget build(BuildContext context) {


    final isDark = Theme.of(context).brightness == Brightness.dark;
    final calendarProvider = context.watch<CalendarProvider>();

    // Gradient colors
    final bgGradient = isDark
        ? const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.darkBg, AppColors.darkBg],
          )
        : const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.light, AppColors.white],
            stops: [0.5375, 1.0],
          );

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
        backgroundColor: isDark ? AppColors.darkTopCard : AppColors.midLight,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(gradient: bgGradient),
          child: Column(
            children: [
              CustomScreenHeader(
                centerTitle: false,
                title:
                    AppLocalizations.of(context)?.calendarTitle ?? 'Calendar',
                onBackTap: () => Navigator.pop(context),
                trailing: GestureDetector(
                  onTap: () {
                    final provider = context.read<CalendarProvider>();
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      enableDrag: false,
                      backgroundColor: Colors.transparent,
                      barrierColor: const Color(0xB2000000),
                      builder: (ctx) => ChangeNotifierProvider.value(
                        value: provider,
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                          child: NewEventBottomSheet(
                            initialDate: _selectedDate,
                          ),
                        ),
                      ),
                    );
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 14.w,
                      vertical: 8.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.main,
                      borderRadius: BorderRadius.circular(100.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, size: 16.r, color: AppColors.white),
                        SizedBox(width: 8.w),
                        Text(
                          AppLocalizations.of(context)?.newEvent ?? 'New event',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w400,
                            height: 24 / 16,
                            color: AppColors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: SafeArea(
                  top: false,
                  child: RefreshIndicator(
                    onRefresh: _refreshAllData,
                    color: AppColors.main,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: ClampingScrollPhysics(),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 19.h,
                      ),
                      child: Column(
                        children: [
                          CalendarCard(
                            currentMonth: _currentMonth,
                            selectedDate: _selectedDate,
                            isLoading: calendarProvider.isLoading,
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
                                calendarProvider.getEventsForDate(date),
                            showTooltip: false,
                          ),
                          SizedBox(height: 29.h),
                          ScheduleSection(
                            selectedDate: _selectedDate,
                            schedule: calendarProvider.selectedDaySchedule,
                            isLoading: calendarProvider.isScheduleLoading,
                            onItemTap: (item) async {
                              if (item.type.trim().toLowerCase() == 'meeting') {
                                await Navigator.pushNamed(
                                  context,
                                  AppRouter.scheduleLog,
                                  arguments: item,
                                );
                                if (context.mounted) {
                                  _refreshAllData();
                                }
                              }
                            },
                          ),
                          SizedBox(height: 34.h), // spacing at bottom
                        ],
                      ),
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
