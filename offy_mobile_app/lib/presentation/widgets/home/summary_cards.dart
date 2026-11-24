import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/navigation/app_router.dart';
import '../../../../data/models/home_response_model.dart';
import '../../screens/time_off/time_off_page.dart';
import '../../screens/pay_slip/pay_slip_page.dart';
import '../../screens/expenses/submit_expense_page.dart';
import '../../viewmodels/pay_slip/payslip_provider.dart';
import '../../viewmodels/home/home_provider.dart';
import '../../viewmodels/time_off/time_off_provider.dart';
import '../../viewmodels/attendance/attendance_provider.dart';
import '../../viewmodels/expenses/expenses_provider.dart';
import '../../viewmodels/home/home_navigation_provider.dart';
import '../../viewmodels/user/access_provider.dart';
import '../../../../injection_container.dart' as di;
import '../../../../l10n/app_localizations.dart';
import 'checked_in_card.dart';
import 'home_scale.dart';

class SummaryCards extends StatefulWidget {
  const SummaryCards({super.key, required this.availableHeight});

  /// Height the cards may use before the Home page has to scroll.
  final double availableHeight;

  @override
  State<SummaryCards> createState() => _SummaryCardsState();
}

class _SummaryCardsState extends State<SummaryCards> {
  // Design heights (before `.h`) of the tallest check-in card and a tile row.
  static const double _checkInCardHeight = 216;
  static const double _tileRowHeight = 165;
  static const double _messageHeight = 163;
  static const double _rowGap = 14;
  static const double _checkInGap = 16;

  HomeScale _s = HomeScale.full;

  @override
  Widget build(BuildContext context) {
    final homeProvider = context.watch<HomeProvider>();
    final homeData = homeProvider.homeData?.home;
    final currencySymbol =
        context
            .read<AccessProvider>()
            .accessDetails
            ?.company
            ?.defaultCompanyCurrency
            ?.symbol ??
        '\$';

    // Format the remaining leave. E.g. "5.0" -> "5", "5.5" -> "5.5"
    final remainingLeave = homeData?.totalRemainingLeave;
    final remainingLeaveStr = remainingLeave != null
        ? (remainingLeave % 1 == 0
              ? remainingLeave.toInt().toString()
              : remainingLeave.toString())
        : ' ';

    // Payslip
    final payslip = homeData?.payslip;
    final payslipAmount = payslip?.finalAmount != null
        ? '${payslip?.currency?.symbol ?? currencySymbol}${payslip!.finalAmount}'
        : ' ';
    final payslipSubtitle =
        payslip?.month?.toUpperCase() ??
        AppLocalizations.of(context)?.emptyPayslip.toUpperCase() ??
        '';

    // Expenses
    final expense = homeData?.expense;
    final expensesAmount = expense?.totalAmount != null
        ? '${expense?.currency?.symbol ?? currencySymbol}${expense!.totalAmount}'
        : '${currencySymbol}0.00';
    final currentMonthYear =
        expense?.month?.toUpperCase() ??
        DateFormat('MMMM yyyy').format(DateTime.now()).toUpperCase();

    final accessProvider = context.watch<AccessProvider>();
    final hasTimeOff = accessProvider.hasFeature('time_off');
    final hasExpense = accessProvider.hasFeature('expense');
    final hasCalendar = accessProvider.hasFeature('calendar');
    final hasPayslip = accessProvider.hasFeature('payslip');
    final hasAttendance = accessProvider.hasFeature('attendance');

    Widget buildFullWidthRow(Widget card) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [Expanded(child: card)],
        ),
      );
    }

    Widget buildHalfWidthRow(Widget card1, Widget card2) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 14.w,
          children: [
            Expanded(child: card1),
            Expanded(child: card2),
          ],
        ),
      );
    }

    final activeCount =
        (hasTimeOff ? 1 : 0) +
        (hasExpense ? 1 : 0) +
        (hasCalendar ? 1 : 0) +
        (hasPayslip ? 1 : 0);

    final tileRows = hasAttendance
        ? math.min(activeCount, 2)
        : math.min(activeCount, 3);
    final hasMessageRow = hasAttendance ? activeCount == 1 : activeCount == 2;
    final messageHeight = hasMessageRow ? _rowGap + _messageHeight : 0.0;
    final tileHeight = tileRows == 0
        ? 0.0
        : tileRows * _tileRowHeight + (tileRows - 1) * _rowGap;
    final checkInHeight = hasAttendance
        ? _checkInCardHeight + _checkInGap
        : 0.0;
    _s = HomeScale.fit(
      available: widget.availableHeight,
      naturalHeight: checkInHeight + tileHeight + messageHeight,
    );

    final isTimeOffExpanded =
        hasTimeOff && (hasAttendance ? activeCount != 4 : true);
    final isExpenseExpanded =
        hasExpense &&
        (hasAttendance
            ? (activeCount == 1 ||
                  activeCount == 2 ||
                  (activeCount == 3 && !hasTimeOff))
            : true);
    final isCalendarExpanded =
        hasCalendar &&
        (hasAttendance
            ? (activeCount == 1 || activeCount == 2)
            : activeCount != 4);
    final isPayslipExpanded =
        hasPayslip &&
        (hasAttendance
            ? (activeCount == 1 || activeCount == 2)
            : activeCount != 4);

    Widget? cardTimeOff;
    if (hasTimeOff) {
      cardTimeOff = GestureDetector(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              settings: const RouteSettings(name: AppRouter.timeOff),
              builder: (routeContext) => MultiProvider(
                providers: [
                  ChangeNotifierProvider.value(value: di.sl<TimeOffProvider>()),
                  ChangeNotifierProvider.value(
                    value: context.read<AccessProvider>(),
                  ),
                ],
                child: const TimeOffPage(),
              ),
            ),
          );

          if (result != false && context.mounted) {
            final attendanceProvider = context.read<AttendanceProvider>();
            final homeProv = context.read<HomeProvider>();
            homeProv.fetchHomeData(attendanceProvider);
          }
        },
        child: _buildCard(
          context,
          svgAsset: AppAssets.timeOff,
          title:
              AppLocalizations.of(context)?.timeOff.toUpperCase() ?? 'TIME OFF',
          value: remainingLeaveStr,
          unit: remainingLeave != null
              ? (AppLocalizations.of(context)?.days ?? 'Days')
              : null,
          subtitle: AppLocalizations.of(context)?.remaining ?? 'Remaining',
          isEmpty: remainingLeave == null,
          emptyMessage:
              AppLocalizations.of(context)?.emptyLeaves ??
              'Your leaves will appear here',
          cardImage: isTimeOffExpanded ? AppAssets.timeOffCard : null,
          actionSvgAsset: isTimeOffExpanded ? AppAssets.arrowUpRight : null,
        ),
      );
    }

    Widget? cardExpense;
    if (hasExpense) {
      cardExpense = GestureDetector(
        onTap: () {
          context.read<HomeNavigationProvider>().switchToTab(HomeTab.expense);
        },
        child: _buildCard(
          context,
          svgAsset: AppAssets.expensesUnselected,
          title:
              AppLocalizations.of(context)?.expenses.toUpperCase() ??
              'EXPENSES',
          value: expensesAmount,
          subtitle: currentMonthYear,
          isEmpty: expense == null || expense.totalAmount == null,
          emptyMessage:
              AppLocalizations.of(context)?.emptyExpenses ??
              'Your expenses will appear here',
          cardImage: isExpenseExpanded ? AppAssets.expenseCard : null,
          actionIcon: Icons.add,
          onActionPressed: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                settings: const RouteSettings(name: AppRouter.submitExpense),
                builder: (context) => const SubmitExpensePage(),
              ),
            );
            if (result == true && context.mounted) {
              final attendanceProvider = context.read<AttendanceProvider>();
              final homeProv = context.read<HomeProvider>();
              final expensesProvider = context.read<ExpensesProvider>();
              homeProv.fetchHomeData(attendanceProvider);
              expensesProvider.fetchExpenseSummary();
            }
          },
        ),
      );
    }

    Widget? cardCalendar;
    if (hasCalendar) {
      cardCalendar = GestureDetector(
        onTap: () {
          Navigator.pushNamed(context, AppRouter.calendar);
        },
        child: _buildScheduleCard(
          context,
          calendarData: homeData?.calendar,
          isExpanded: isCalendarExpanded,
        ),
      );
    }

    Widget? cardPayslip;
    if (hasPayslip) {
      cardPayslip = GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              settings: const RouteSettings(name: AppRouter.paySlip),
              builder: (ctx) => ChangeNotifierProvider.value(
                value: context.read<PayslipProvider>(),
                child: const PaySlipPage(),
              ),
            ),
          );
        },
        child: _buildCard(
          context,
          svgAsset: AppAssets.payslip,
          title:
              AppLocalizations.of(context)?.paySlip.toUpperCase() ?? 'PAYSLIP',
          value: payslipAmount,
          subtitle: payslipSubtitle,
          isEmpty:
              payslip == null ||
              payslip.finalAmount == null ||
              payslip.month == null,
          emptyMessage:
              AppLocalizations.of(context)?.emptyPayslip ?? 'No payslip yet',
          cardImage: isPayslipExpanded ? AppAssets.payslipCard : null,
          actionSvgAsset: isPayslipExpanded ? AppAssets.arrowUpRight : null,
        ),
      );
    }

    final visibleCards = <Widget>[];
    if (cardTimeOff != null) visibleCards.add(cardTimeOff);
    if (cardExpense != null) visibleCards.add(cardExpense);
    if (cardCalendar != null) visibleCards.add(cardCalendar);
    if (cardPayslip != null) visibleCards.add(cardPayslip);

    final count = visibleCards.length;

    final rows = <Widget>[];

    if (hasAttendance) {
      rows.add(CheckedInCard(scale: _s));
      rows.add(SizedBox(height: _s.h(_checkInGap)));
    }

    if (hasAttendance) {
      if (count == 4) {
        rows.add(buildHalfWidthRow(cardTimeOff!, cardExpense!));
        rows.add(SizedBox(height: _s.h(14)));
        rows.add(buildHalfWidthRow(cardCalendar!, cardPayslip!));
      } else if (count == 3) {
        if (!hasTimeOff) {
          // Remove 1 -> [2] / [3][4]
          rows.add(buildFullWidthRow(cardExpense!));
          rows.add(SizedBox(height: _s.h(14)));
          rows.add(buildHalfWidthRow(cardCalendar!, cardPayslip!));
        } else if (!hasExpense) {
          // Remove 2 -> [1] / [3][4]
          rows.add(buildFullWidthRow(cardTimeOff!));
          rows.add(SizedBox(height: _s.h(14)));
          rows.add(buildHalfWidthRow(cardCalendar!, cardPayslip!));
        } else if (!hasCalendar) {
          // Remove 3 -> [1] / [2][4]
          rows.add(buildFullWidthRow(cardTimeOff!));
          rows.add(SizedBox(height: _s.h(14)));
          rows.add(buildHalfWidthRow(cardExpense!, cardPayslip!));
        } else if (!hasPayslip) {
          // Remove 4 -> [1] / [3][2]
          rows.add(buildFullWidthRow(cardTimeOff!));
          rows.add(SizedBox(height: _s.h(14)));
          rows.add(buildHalfWidthRow(cardCalendar!, cardExpense!));
        }
      } else if (count == 2) {
        rows.add(buildFullWidthRow(visibleCards[0]));
        rows.add(SizedBox(height: _s.h(14)));
        rows.add(buildFullWidthRow(visibleCards[1]));
      } else if (count == 1) {
        rows.add(buildFullWidthRow(visibleCards[0]));
        rows.add(SizedBox(height: _s.h(14)));
        rows.add(Expanded(child: _buildSingleCardMessage(context)));
      } else if (count == 0) {
        rows.add(
          Expanded(
            child: _buildNoCardsUI(context, image: AppAssets.emptyEventsCard),
          ),
        );
      }
    } else {
      if (count == 4) {
        rows.add(buildFullWidthRow(visibleCards[0]));
        rows.add(SizedBox(height: _s.h(14)));
        rows.add(buildFullWidthRow(visibleCards[1]));
        rows.add(SizedBox(height: _s.h(14)));
        rows.add(buildHalfWidthRow(visibleCards[2], visibleCards[3]));
      } else if (count == 3) {
        rows.add(buildFullWidthRow(visibleCards[0]));
        rows.add(SizedBox(height: _s.h(14)));
        rows.add(buildFullWidthRow(visibleCards[1]));
        rows.add(SizedBox(height: _s.h(14)));
        rows.add(buildFullWidthRow(visibleCards[2]));
      } else if (count == 2) {
        rows.add(buildFullWidthRow(visibleCards[0]));
        rows.add(SizedBox(height: _s.h(14)));
        rows.add(buildFullWidthRow(visibleCards[1]));
        rows.add(SizedBox(height: _s.h(14)));
        rows.add(Expanded(child: _buildSingleCardMessage(context)));
      } else if (count == 1) {
        rows.add(buildFullWidthRow(visibleCards[0]));
        rows.add(SizedBox(height: _s.h(14)));
        rows.add(
          Expanded(
            child: _buildNoCardsUI(context, image: AppAssets.emptyEventsCard),
          ),
        );
      } else if (count == 0) {
        rows.add(
          Expanded(
            child: _buildNoCardsUI(context, image: AppAssets.emptyHomeCard),
          ),
        );
      }
    }

    if (rows.isEmpty) {
      return const SizedBox();
    }

    return Column(mainAxisAlignment: MainAxisAlignment.center, children: rows);
  }

  Widget _buildNoCardsUI(BuildContext context, {required String image}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (image == AppAssets.emptyHomeCard) {
      return Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: EdgeInsets.only(bottom: 36.h),
            child: SizedBox(
              width: 289.w,
              height: 433.5.h,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Image.asset(
                    AppAssets.emptyHomeCard,
                    width: 289.w,
                    height: 433.5.h,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox(),
                  ),
                  Positioned(
                    bottom: 36.h,
                    left: 16.w,
                    right: 16.w,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          AppLocalizations.of(context)?.allSet ??
                              "You're all set for a productive day!",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w500,
                            height: 16 / 16,
                            color: isDark
                                ? AppColors.midLight
                                : AppColors.darkTopCard,
                          ),
                        ),
                        SizedBox(height: 7.h),
                        Text(
                          AppLocalizations.of(context)?.keepGoing ??
                              'keep going. stay focused',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w300,
                            height: 16 / 14,
                            color: isDark
                                ? AppColors.darkNav
                                : AppColors.black.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 20.h),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 249.w),
              child: FractionallySizedBox(
                widthFactor: 0.65,
                child: Image.asset(
                  image,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox(),
                ),
              ),
            ),
            SizedBox(height: 10.5.h),
            Text(
              AppLocalizations.of(context)?.allSet ??
                  "You're all set for a productive day!",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w500,
                height: 16 / 16,
                color: isDark ? AppColors.midLight : AppColors.darkTopCard,
              ),
            ),
            SizedBox(height: 7.h),
            Text(
              AppLocalizations.of(context)?.keepGoing ??
                  'keep going. stay focused',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w300,
                height: 16 / 14,
                color: isDark
                    ? AppColors.darkNav
                    : AppColors.black.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleCardMessage(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(minHeight: _s.h(163)),
      width: double.infinity,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            AppLocalizations.of(context)?.allSet ??
                "You're all set for a productive day!",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: _s.sp(16),
              fontWeight: FontWeight.w500,
              height: 16 / 16,
              color: isDark ? AppColors.midLight : AppColors.darkTopCard,
            ),
          ),
          SizedBox(height: _s.h(7)),
          Text(
            AppLocalizations.of(context)?.keepGoing ??
                'keep going. stay focused',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: _s.sp(14),
              fontWeight: FontWeight.w300,
              height: 16 / 14,
              color: isDark
                  ? AppColors.darkNav
                  : AppColors.black.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeetingItem({
    required BuildContext context,
    required String time,
    required String description,
    required bool isDark,
    bool constrainContent = false,
  }) {
    Widget content = Padding(
      padding: EdgeInsets.only(right: 10.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            time,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: _s.sp(12),
              fontWeight: FontWeight.w400,
              height: 16 / 12,
              color: isDark ? AppColors.main : AppColors.secondary,
            ),
          ),
          Text(
            description,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: _s.sp(12),
              fontWeight: FontWeight.w600,
              height: 16 / 12,
              color: isDark ? AppColors.midLight : AppColors.black,
            ),
          ),
        ],
      ),
    );

    if (constrainContent) {
      content = Row(
        children: [
          Expanded(child: content),
          SizedBox(width: 20.w),
          const Expanded(child: SizedBox()),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Divider(
          height: _s.h(0.5),
          thickness: _s.h(0.5),
          color: isDark
              ? Colors.white.withValues(alpha: 0.3)
              : Colors.black.withValues(alpha: 0.3),
        ),
        SizedBox(height: _s.h(8)),
        content,
        SizedBox(height: _s.h(8)),
      ],
    );
  }

  Widget _buildScheduleCard(
    BuildContext context, {
    Key? key,
    HomeCalendarModel? calendarData,
    double? height,
    bool isExpanded = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final items = calendarData?.items ?? [];
    final hasItems = items.isNotEmpty;

    return Container(
      constraints: BoxConstraints(
        minHeight: height ?? (isExpanded ? _s.h(163) : _s.h(165)),
      ),
      padding: EdgeInsets.symmetric(horizontal: 15.w, vertical: _s.h(10)),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: isDark
              ? Colors.transparent
              : const Color.fromRGBO(228, 226, 225, 0.3),
          width: 1.w,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0x0F2A2A2A),
            blurRadius: 20.r,
            offset: Offset(0, _s.h(4)),
          ),
        ],
      ),
      child: Container(
        key: key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SvgPicture.asset(
                          AppAssets.calendar,
                          width: _s.h(30),
                          height: _s.h(30),
                          colorFilter: const ColorFilter.mode(
                            AppColors.main,
                            BlendMode.srcIn,
                          ),
                        ),
                        if (isExpanded) ...[
                          SizedBox(width: 11.w),
                          Text(
                            AppLocalizations.of(
                                  context,
                                )?.calendar.toUpperCase() ??
                                'CALENDAR',
                            style: TextStyle(
                              fontSize: _s.sp(14),
                              fontWeight: FontWeight.w400,
                              height: 16 / 14,
                              color: isDark
                                  ? AppColors.midLight
                                  : AppColors.tertiary,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (isExpanded) SummaryCardActionButton(scale: _s),
                  ],
                ),
                if (!isExpanded && items.length < 2) ...[
                  SizedBox(height: _s.h(11)),
                  Text(
                    AppLocalizations.of(context)?.calendar.toUpperCase() ??
                        'CALENDAR',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: _s.sp(14),
                      fontWeight: FontWeight.w400,
                      height: 16 / 14,
                      color: isDark ? AppColors.midLight : AppColors.tertiary,
                    ),
                  ),
                ],
              ],
            ),
            if (hasItems)
              (isExpanded
                  ? (items.length <= 2
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: items.length == 1
                                ? MainAxisAlignment.end
                                : MainAxisAlignment.spaceEvenly,
                            children: [
                              if (items.isNotEmpty)
                                _buildMeetingItem(
                                  context: context,
                                  time: items[0].subtitle,
                                  description: items[0].title,
                                  isDark: isDark,
                                  constrainContent: true,
                                ),
                              if (items.length > 1)
                                _buildMeetingItem(
                                  context: context,
                                  time: items[1].subtitle,
                                  description: items[1].title,
                                  isDark: isDark,
                                  constrainContent: true,
                                ),
                            ],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: items.length == 1
                                      ? MainAxisAlignment.start
                                      : MainAxisAlignment.spaceEvenly,
                                  children: [
                                    if (items.isNotEmpty)
                                      _buildMeetingItem(
                                        context: context,
                                        time: items[0].subtitle,
                                        description: items[0].title,
                                        isDark: isDark,
                                      ),
                                    if (items.length > 1)
                                      _buildMeetingItem(
                                        context: context,
                                        time: items[1].subtitle,
                                        description: items[1].title,
                                        isDark: isDark,
                                      ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 20.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    if (items.length > 2)
                                      _buildMeetingItem(
                                        context: context,
                                        time: items[2].subtitle,
                                        description: items[2].title,
                                        isDark: isDark,
                                      ),
                                    if (items.length > 3)
                                      _buildMeetingItem(
                                        context: context,
                                        time: items[3].subtitle,
                                        description: items[3].title,
                                        isDark: isDark,
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: items.length == 1
                          ? MainAxisAlignment.end
                          : MainAxisAlignment.spaceEvenly,
                      children: [
                        if (items.isNotEmpty)
                          _buildMeetingItem(
                            context: context,
                            time: items[0].subtitle,
                            description: items[0].title,
                            isDark: isDark,
                          ),
                        if (items.length > 1)
                          _buildMeetingItem(
                            context: context,
                            time: items[1].subtitle,
                            description: items[1].title,
                            isDark: isDark,
                          ),
                      ],
                    ))
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SvgPicture.asset(
                    AppAssets.logs,
                    width: _s.h(24),
                    height: _s.h(24),
                    colorFilter: ColorFilter.mode(
                      isDark ? AppColors.darkNav : AppColors.navColor,
                      BlendMode.srcIn,
                    ),
                  ),
                  SizedBox(height: _s.h(5)),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      AppLocalizations.of(context)?.emptyEvents ??
                          'Your events will appear here',
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: _s.sp(12),
                        fontWeight: FontWeight.w500,
                        height: 18 / 12,
                        color: isDark ? AppColors.darkNav : AppColors.navColor,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(
    BuildContext context, {
    IconData? icon,
    String? svgAsset,
    required String title,
    required String value,
    String? unit,
    required String subtitle,
    double? height,
    VoidCallback? onActionPressed,
    bool isEmpty = false,
    String? emptyMessage,
    String? cardImage,
    IconData? actionIcon,
    String? actionSvgAsset,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(minHeight: height ?? _s.h(165)),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: isDark ? Colors.transparent : const Color(0x4DE4E2E1),
          width: 1.w,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0x0F2A2A2A),
            blurRadius: 20.r,
            offset: Offset(0, _s.h(4)),
          ),
        ],
      ),
      child: Stack(
        children: [
          if (cardImage != null)
            Positioned(
              right: 15.w,
              top: _s.h(10),
              bottom: _s.h(10),
              child: Image.asset(
                cardImage,
                fit: BoxFit.contain,
                alignment: Alignment.bottomRight,
                errorBuilder: (context, error, stackTrace) => const SizedBox(),
              ),
            ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 15.w, vertical: _s.h(10)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (cardImage != null) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (svgAsset != null)
                                SvgPicture.asset(
                                  svgAsset,
                                  width: _s.h(30),
                                  height: _s.h(30),
                                  colorFilter: const ColorFilter.mode(
                                    AppColors.main,
                                    BlendMode.srcIn,
                                  ),
                                )
                              else if (icon != null)
                                Icon(
                                  icon,
                                  color: AppColors.main,
                                  size: _s.h(30),
                                ),
                              SizedBox(width: 8.w),
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: _s.sp(14),
                                  fontWeight: FontWeight.w400,
                                  height: 16 / 14,
                                  color: isDark
                                      ? AppColors.midLight
                                      : AppColors.tertiary,
                                ),
                              ),
                            ],
                          ),
                          if (actionSvgAsset != null ||
                              actionIcon != null ||
                              onActionPressed != null)
                            SummaryCardActionButton(
                              scale: _s,
                              onTap: onActionPressed,
                              icon: actionIcon,
                              svgAsset: actionSvgAsset,
                            ),
                        ],
                      ),
                    ] else ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (svgAsset != null)
                            SvgPicture.asset(
                              svgAsset,
                              width: _s.h(30),
                              height: _s.h(30),
                              colorFilter: const ColorFilter.mode(
                                AppColors.main,
                                BlendMode.srcIn,
                              ),
                            )
                          else if (icon != null)
                            Icon(icon, color: AppColors.main, size: _s.h(30)),
                          if (onActionPressed != null || actionIcon != null)
                            SummaryCardActionButton(
                              scale: _s,
                              onTap: onActionPressed,
                              icon: actionIcon ?? Icons.add,
                            ),
                        ],
                      ),
                      SizedBox(height: _s.h(11)),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: _s.sp(14),
                          fontWeight: FontWeight.w400,
                          height: 16 / 14,
                          color: isDark
                              ? AppColors.midLight
                              : AppColors.tertiary,
                        ),
                      ),
                    ],
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isEmpty)
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              value,
                              style: TextStyle(
                                fontSize: _s.sp(24),
                                fontWeight: FontWeight.w600,
                                height: 32 / 24,
                                color: isDark
                                    ? AppColors.midLight
                                    : AppColors.black,
                              ),
                            ),
                            if (unit != null) ...[
                              SizedBox(width: 4.w),
                              Text(
                                unit,
                                style: TextStyle(
                                  fontSize: _s.sp(24),
                                  fontWeight: FontWeight.w600,
                                  height: 32 / 24,
                                  color: isDark
                                      ? AppColors.midLight
                                      : AppColors.black,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    if (isEmpty && emptyMessage != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SvgPicture.asset(
                            AppAssets.logs,
                            width: _s.h(24),
                            height: _s.h(24),
                            colorFilter: ColorFilter.mode(
                              isDark ? AppColors.darkNav : AppColors.navColor,
                              BlendMode.srcIn,
                            ),
                          ),
                          SizedBox(height: _s.h(5)),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              emptyMessage,
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: _s.sp(12),
                                fontWeight: FontWeight.w500,
                                height: 18 / 12,
                                color: isDark
                                    ? AppColors.darkNav
                                    : AppColors.navColor,
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: _s.sp(12),
                          fontWeight: FontWeight.w500,
                          height: 18 / 12,
                          color: isDark ? AppColors.main : AppColors.secondary,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SummaryCardActionButton extends StatelessWidget {
  final VoidCallback? onTap;
  final IconData? icon;
  final String? svgAsset;
  final HomeScale scale;

  const SummaryCardActionButton({
    super.key,
    this.onTap,
    this.icon,
    this.svgAsset,
    this.scale = HomeScale.full,
  });

  @override
  Widget build(BuildContext context) {
    Widget iconWidget;
    if (icon != null) {
      iconWidget = Icon(icon, color: Colors.white, size: scale.w(14));
    } else {
      iconWidget = SvgPicture.asset(
        svgAsset ?? AppAssets.arrowUpRight,
        width: scale.w(16),
        height: scale.h(16),
        errorBuilder: (context, error, stackTrace) =>
            Icon(Icons.north_east, color: Colors.white, size: scale.w(14)),
      );
    }

    final button = Container(
      width: scale.h(30),
      height: scale.h(30),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF000000), Color(0xFF000000)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0x1A000000),
            blurRadius: 8.r,
            offset: Offset(0, scale.h(5)),
          ),
          BoxShadow(
            color: const Color(0x1A000000),
            blurRadius: 3.r,
            offset: Offset(0, scale.h(2)),
          ),
        ],
      ),
      child: Center(child: iconWidget),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: button);
    }

    return button;
  }
}
