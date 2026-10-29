import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/date_formatter.dart';
import 'package:shimmer/shimmer.dart';

import '../common/two_lines_scaled_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/navigation/app_router.dart';
import '../../../l10n/app_localizations.dart';
import '../../viewmodels/pay_slip/payslip_provider.dart';
import '../../../core/utils/payslip_year_grouping.dart';
import '../../screens/pay_slip/payslip_history_list_screen.dart';
import '../../screens/pay_slip/payslip_details_screen.dart';
import 'payslip_history_item.dart';
import '../../viewmodels/user/access_provider.dart';

class PayslipHistorySection extends StatelessWidget {
  const PayslipHistorySection({super.key});

  @override
  Widget build(BuildContext context) {
    final payslipProvider = context.watch<PayslipProvider>();
    final historyList = payslipProvider.payslip?.history ?? [];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencySymbol =
        context
            .read<AccessProvider>()
            .accessDetails
            ?.company
            ?.defaultCompanyCurrency
            ?.symbol ??
        '';

    final yearLabelStyle = TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 12.sp,
      height: 16 / 12,
      letterSpacing: 1.2.sp,
      color: isDark ? AppColors.white : const Color(0xFF907067),
    );

    final cardContainerDecoration = BoxDecoration(
      color: isDark ? AppColors.darkCard : Colors.white,
      borderRadius: BorderRadius.circular(12.r),
      boxShadow: [
        BoxShadow(
          color: const Color(0x0D000000),
          offset: const Offset(0, 1),
          blurRadius: 2.r,
        ),
      ],
    );

    final titleStyle = TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 20.sp,
      height: 28 / 20,
      color: isDark ? AppColors.white : AppColors.black,
    );

    final showHistoryShimmer =
        payslipProvider.isLoading && payslipProvider.payslip == null;

    if (showHistoryShimmer) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)?.history ?? 'History',
            style: titleStyle,
          ),
          SizedBox(height: 16.h),
          Shimmer.fromColors(
            baseColor: AppColors.shimmerBase(isDark),
            highlightColor: AppColors.shimmerHighlight(isDark),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${DateTime.now().year}', style: yearLabelStyle),
                SizedBox(height: 8.h),
                Container(
                  decoration: cardContainerDecoration,
                  child: Column(
                    children: List.generate(
                      3,
                      (index) => PayslipHistoryItem(
                        monthLabel: 'JUL',
                        yearLabel: '26',
                        title: 'Payslip Loading...',
                        subtitle: 'Net Pay',
                        amount: '${currencySymbol}0.00',
                        hasTopBorder: index > 0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final groupedHistory = PayslipYearGrouping.group(historyList);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: TwoLinesScaledText(
                text: AppLocalizations.of(context)?.history ?? 'History',
                style: titleStyle,
              ),
            ),
            if (historyList.isNotEmpty)
              InkWell(
                borderRadius: BorderRadius.circular(6.r),
                onTap: payslipProvider.isLoading
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            settings: const RouteSettings(
                              name: AppRouter.payslipHistory,
                            ),
                            builder: (_) => ChangeNotifierProvider.value(
                              value: payslipProvider,
                              child: const PayslipHistoryListScreen(),
                            ),
                          ),
                        );
                      },
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 8.w,
                    vertical: 8.h,
                  ),
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

        if (historyList.isEmpty)
          Expanded(
            child: Container(
              width: double.infinity,
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
                  AppLocalizations.of(context)?.noHistoryAvailable ??
                      'No history available',
                  style: TextStyle(
                    color: isDark
                        ? const Color(0xFFEAE1D8)
                        : const Color(0xFF907067),
                    fontSize: 14.sp,
                  ),
                ),
              ),
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...groupedHistory.map((section) {
                final items = section.payslips;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(section.label.toUpperCase(), style: yearLabelStyle),
                    SizedBox(height: 10.h),
                    Container(
                      decoration: cardContainerDecoration,
                      child: Column(
                        children: items.asMap().entries.map((e) {
                          final index = e.key;
                          final item = e.value;

                          String monthLabel = '';
                          String yearLabel = '';
                          String subtitle = '';
                          if (item.distributedDate.isNotEmpty) {
                            final dt = DateTime.tryParse(item.distributedDate);
                            if (dt != null) {
                              subtitle =
                                  AppLocalizations.of(context)?.distributedDate(
                                    AppDateFormatter.mmmDd(dt),
                                  ) ??
                                  'Distributed ${AppDateFormatter.mmmDd(dt)}';
                            }
                          }

                          final labelDateStr = item.dateTo.isNotEmpty
                              ? item.dateTo
                              : item.dateFrom;
                          if (labelDateStr.isNotEmpty) {
                            final dt = DateTime.tryParse(labelDateStr);
                            if (dt != null) {
                              monthLabel = AppDateFormatter.mmmUppercase(dt);
                              yearLabel = (dt.year % 100).toString().padLeft(
                                2,
                                '0',
                              );
                            }
                          }

                          if (yearLabel.isEmpty && item.period.isNotEmpty) {
                            final match = RegExp(
                              r'\b\d{4}\b',
                            ).firstMatch(item.period);
                            if (match != null) {
                              final fullYear = match.group(0)!;
                              yearLabel = fullYear.length >= 2
                                  ? fullYear.substring(fullYear.length - 2)
                                  : fullYear;
                            }
                            if (monthLabel.isEmpty) {
                              final monthMatch = RegExp(
                                r'[A-Za-z]+',
                              ).firstMatch(item.period);
                              if (monthMatch != null) {
                                final mStr = monthMatch.group(0)!;
                                monthLabel = mStr.length >= 3
                                    ? mStr.substring(0, 3).toUpperCase()
                                    : mStr.toUpperCase();
                              }
                            }
                          }

                          return PayslipHistoryItem(
                            monthLabel: monthLabel,
                            yearLabel: yearLabel,
                            title: item.period,
                            subtitle: subtitle,
                            amount: item.netPay != null
                                ? '$currencySymbol${item.netPay}'
                                : '${currencySymbol}0.00',
                            hasTopBorder: index > 0,
                            onTap: payslipProvider.isLoading
                                ? null
                                : () {
                                    final provider = context
                                        .read<PayslipProvider>();
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        settings: const RouteSettings(
                                          name: '/payslip/detail',
                                        ),
                                        builder: (_) =>
                                            ChangeNotifierProvider.value(
                                              value: provider,
                                              child: PayslipDetailsScreen(
                                                payslipItem: item,
                                              ),
                                            ),
                                      ),
                                    );
                                  },
                          );
                        }).toList(),
                      ),
                    ),
                    SizedBox(height: 24.h),
                  ],
                );
              }),
            ],
          ),
      ],
    );
  }
}
