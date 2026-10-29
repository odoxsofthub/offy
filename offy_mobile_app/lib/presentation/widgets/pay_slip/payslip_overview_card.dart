import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../viewmodels/pay_slip/payslip_provider.dart';
// import '../common/custom_snackbar.dart';
import '../../screens/pay_slip/payslip_details_screen.dart';
import '../../viewmodels/user/access_provider.dart';

class PayslipOverviewCard extends StatefulWidget {
  const PayslipOverviewCard({super.key});

  @override
  State<PayslipOverviewCard> createState() => _PayslipOverviewCardState();
}

class _PayslipOverviewCardState extends State<PayslipOverviewCard> {
  //   bool _isDownloading = false;

  @override
  Widget build(BuildContext context) {
    final payslipProvider = context.watch<PayslipProvider>();
    final payslip = payslipProvider.payslip;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final period = payslip?.period.toUpperCase() ?? '';
    final currencySymbol =
        context
            .read<AccessProvider>()
            .accessDetails
            ?.company
            ?.defaultCompanyCurrency
            ?.symbol ??
        '';
    final amount = payslip != null
        ? '$currencySymbol${payslip.netPay}'
        : '${currencySymbol}0.00';

    final periodWidget = Text(
      period,
      style: TextStyle(
        fontSize: 18.sp,
        fontWeight: FontWeight.w500,
        height: 1.2,
        color: const Color(0xFF9F4122),
      ),
    );

    final amountWidget = Text(
      amount,
      style: TextStyle(
        fontSize: 45.sp,
        fontWeight: FontWeight.w600,
        height: 1.1,
        letterSpacing: -0.64.sp,
        color: isDark ? Colors.white : Colors.black,
      ),
    );

    final isDisabled = payslip == null || payslipProvider.isLoading;

    final childColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Row 1: Month/Amount and Image Illustration
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  periodWidget,
                  SizedBox(height: 8.h),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.bottomLeft,
                    child: amountWidget,
                  ),
                ],
              ),
            ),
            Row(
              children: [
                Image.asset(
                  AppAssets.payslipIllustration,
                  width: 84.w,
                  height: 84.w,
                  fit: BoxFit.contain,
                ),
                SizedBox(width: 11.w),
              ],
            ),
          ],
        ),
        SizedBox(height: 27.h),

        // Row 2: Action Buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // View details Button
            Expanded(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: isDisabled ? 0.6 : 1.0,
                child: GestureDetector(
                  onTap: isDisabled
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              settings: const RouteSettings(
                                name: '/payslip/detail',
                              ),
                              builder: (context) =>
                                  ChangeNotifierProvider.value(
                                    value: payslipProvider,
                                    child: PayslipDetailsScreen(
                                      payslipItem: payslip,
                                    ),
                                  ),
                            ),
                          );
                        },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      vertical: 14.h,
                      horizontal: 17.w,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.main : const Color(0xFFFF7241),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Center(
                      child: Text(
                        AppLocalizations.of(context)?.viewPayslip ??
                            'View payslip',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w500,
                          height: 20 / 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.r),
        gradient: isDark
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF5C4126),
                  Color(0xFF130A02),
                  Color(0xFFFF5C23),
                ],
                stops: [0.0101, 0.5971, 1.0],
              )
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFCEEE0),
                  Color(0xFFFFFFFF),
                  Color(0xFFFF7241),
                ],
                stops: [0.0101, 0.5971, 1.0],
              ),
        border: isDark
            ? Border.all(color: const Color(0xFF7B5C38), width: 1.w)
            : null,
        boxShadow: [
          BoxShadow(
            color: const Color(0x12000000),
            offset: Offset(0, 5.h),
            blurRadius: 8.r,
          ),
        ],
      ),
      padding: EdgeInsets.all(10.w),
      child: childColumn,
    );
  }
}
