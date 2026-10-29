import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../viewmodels/pay_slip/payslip_provider.dart';
import '../../../data/models/payslip_response_model.dart';
import '../../viewmodels/user/access_provider.dart';

class EarningSummarySection extends StatelessWidget {
  const EarningSummarySection({super.key});

  @override
  Widget build(BuildContext context) {
    final currencySymbol =
        context
            .read<AccessProvider>()
            .accessDetails
            ?.company
            ?.defaultCompanyCurrency
            ?.symbol ??
        '';
    final payslipProvider = context.watch<PayslipProvider>();
    final payslip = payslipProvider.payslip;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final titleStyle = TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 20.sp,
      height: 28 / 20,
      color: isDark ? AppColors.white : AppColors.black,
    );

    if (payslipProvider.isLoading) {
      return Shimmer.fromColors(
        baseColor: AppColors.shimmerBase(isDark),
        highlightColor: AppColors.shimmerHighlight(isDark),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)?.earningSummary ?? 'Earning summary',
              style: titleStyle,
            ),
            SizedBox(height: 16.h),
            Row(
              children: [
                Expanded(
                  child: _buildSmallSummaryCard(
                    context,
                    label:
                        AppLocalizations.of(context)?.basicPay ?? 'BASIC PAY',
                    value: '${currencySymbol}0.00',
                  ),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: _buildSmallSummaryCard(
                    context,
                    label: AppLocalizations.of(context)?.hra ?? 'HRA',
                    value: '${currencySymbol}0.00',
                  ),
                ),
              ],
            ),
            SizedBox(height: 14.h),
            _buildPerformanceBonusCard(context, 0.0),
            SizedBox(height: 14.h),
            _buildTaxDeductionsCard(
              context,
              AppLocalizations.of(context)?.taxDeductions ?? 'Tax Deductions',
              0.0,
            ),
          ],
        ),
      );
    }

    if (payslip == null) return const SizedBox();

    final basicPay = payslip.earnings?.firstWhere(
      (e) => e.code == 'BASIC',
      orElse: () =>
          PayslipLineItemModel(code: 'BASIC', name: 'Basic Pay', amount: 0.0),
    );
    final hra = payslip.earnings?.firstWhere(
      (e) => e.code == 'HRA',
      orElse: () => PayslipLineItemModel(code: 'HRA', name: 'HRA', amount: 0.0),
    );
    final bonus = payslip.earnings?.firstWhere(
      (e) => e.code == 'BONUS',
      orElse: () => PayslipLineItemModel(
        code: 'BONUS',
        name: 'Performance Bonus',
        amount: 0.0,
      ),
    );
    final deduction = payslip.deductions?.isNotEmpty == true
        ? payslip.deductions!.first
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)?.earningSummary ?? 'Earning summary',
          style: titleStyle,
        ),
        SizedBox(height: 16.h),

        // Row of Basic Pay and HRA
        Row(
          children: [
            Expanded(
              child: _buildSmallSummaryCard(
                context,
                label: AppLocalizations.of(context)?.basicPay ?? 'BASIC PAY',
                value:
                    '$currencySymbol${basicPay?.amount.toStringAsFixed(2) ?? '0.00'}',
              ),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: _buildSmallSummaryCard(
                context,
                label: AppLocalizations.of(context)?.hra ?? 'HRA',
                value:
                    '$currencySymbol${hra?.amount.toStringAsFixed(2) ?? '0.00'}',
              ),
            ),
          ],
        ),
        SizedBox(height: 14.h),

        if (bonus != null && bonus.amount > 0) ...[
          _buildPerformanceBonusCard(context, bonus.amount),
          SizedBox(height: 14.h),
        ],

        if (deduction != null)
          _buildTaxDeductionsCard(context, deduction.name, deduction.amount),
      ],
    );
  }

  Widget _buildSmallSummaryCard(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final labelStyle = TextStyle(
      fontSize: 12.sp,
      fontWeight: FontWeight.w400,
      height: 16 / 12,
      color: isDark ? const Color(0xFFEAE1D8) : const Color(0xFF5B4039),
    );

    final valueStyle = TextStyle(
      fontSize: 24.sp,
      fontWeight: FontWeight.w600,
      height: 32 / 24,
      color: isDark ? AppColors.white : const Color(0xFF1B1C1C),
    );

    return Container(
      padding: EdgeInsets.only(
        top: 10.h,
        right: 17.w,
        bottom: 10.h,
        left: 20.w,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: isDark ? const Color(0x4DE4E2E1) : const Color(0x4DE4BEB4),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0x0F2A2A2A),
            offset: const Offset(0, 4),
            blurRadius: 20.r,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: labelStyle),
          SizedBox(height: 4.h),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.bottomLeft,
            child: Text(value, style: valueStyle),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceBonusCard(BuildContext context, double amount) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final titleStyle = TextStyle(
      fontSize: 12.sp,
      fontWeight: FontWeight.w600,
      height: 16 / 12,
      color: isDark ? const Color(0xFFEAE1D8) : const Color(0xFF5B4039),
    );

    final valueStyle = TextStyle(
      fontSize: 20.sp,
      fontWeight: FontWeight.w600,
      height: 28 / 20,
      color: isDark ? const Color(0xFFF3E9E0) : AppColors.black,
    );

    final approvedStyle = TextStyle(
      fontSize: 13.sp,
      fontWeight: FontWeight.w500,
      height: 18 / 13,
      color: const Color(0xFF1E1C10),
    );

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: isDark ? null : Border.all(color: const Color(0x4DE4BEB4)),
        boxShadow: [
          BoxShadow(
            color: const Color(0x0F2A2A2A),
            offset: const Offset(0, 4),
            blurRadius: 20.r,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 40.w,
                  height: 40.w,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFDBD0),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.card_giftcard,
                    color: const Color(0xFF9F4122),
                    size: 20.w,
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context)?.performanceBonus ??
                            'Performance Bonus',
                        style: titleStyle,
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.bottomLeft,
                        child: Text(
                          '${context.read<AccessProvider>().accessDetails?.company?.defaultCompanyCurrency?.symbol ?? ''}${amount.toStringAsFixed(2)}',
                          style: valueStyle,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 12.w),
          Row(
            children: [
              Container(
                width: 84.58.w,
                height: 34.h,
                decoration: BoxDecoration(
                  color: const Color(0xFFE9E2CF),
                  borderRadius: BorderRadius.circular(9999.r),
                ),
                alignment: Alignment.center,
                child: Text(
                  AppLocalizations.of(context)?.approved ?? 'Approved',
                  style: approvedStyle,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTaxDeductionsCard(
    BuildContext context,
    String name,
    double amount,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final titleStyle = TextStyle(
      fontSize: 12.sp,
      fontWeight: FontWeight.w600,
      height: 16 / 12,
      color: isDark ? const Color(0xFFED7373) : const Color(0xFFBA1A1A),
    );

    final valueStyle = TextStyle(
      fontSize: 20.sp,
      fontWeight: FontWeight.w600,
      height: 28 / 20,
      color: isDark ? const Color(0xFFF87C7C) : const Color(0xFFBA1A1A),
    );

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: isDark ? null : Border.all(color: const Color(0x4DE4BEB4)),
        boxShadow: [
          BoxShadow(
            color: const Color(0x0F2A2A2A),
            offset: const Offset(0, 4),
            blurRadius: 20.r,
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon Container
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Container(
                  width: 40.w,
                  height: 40.w,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFDBD0),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.receipt_long_outlined,
                    color: const Color(0xFFBA1A1A),
                    size: 15.w,
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(child: Text(name, style: titleStyle)),
              ],
            ),
          ),
          Flexible(
            flex: 1,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '-${context.read<AccessProvider>().accessDetails?.company?.defaultCompanyCurrency?.symbol ?? ''}${amount.abs().toStringAsFixed(2)}',
                style: valueStyle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
