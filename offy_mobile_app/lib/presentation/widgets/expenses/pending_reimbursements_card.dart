import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/theme/app_colors.dart';
import '../../viewmodels/expenses/expenses_provider.dart';
import '../../viewmodels/user/access_provider.dart';

class PendingReimbursementsCard extends StatelessWidget {
  const PendingReimbursementsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpensesProvider>();
    final summary = provider.summary;
    final currencySymbol =
        context
            .read<AccessProvider>()
            .accessDetails
            ?.company
            ?.defaultCompanyCurrency
            ?.symbol ??
        '\$';
    final pendingTotalDisplay =
        summary?.pendingReimbursementDisplay ?? '${currencySymbol}0.00';
    final avgApprovalTime =
        summary?.averageApprovalTime?.display ??
        (AppLocalizations.of(context)?.twoBusinessDays ?? '2 business days');
    final isLoading = provider.isLoading && provider.summary == null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.white,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)?.myPendingReimbursements ??
                'My Pending Reimbursements',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
              height: 28 / 18,
              letterSpacing: 0,
              color: isDark ? AppColors.white : AppColors.black,
            ),
          ),
          SizedBox(height: 12.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (isLoading) ...[
                Shimmer.fromColors(
                  baseColor: AppColors.shimmerBase(isDark),
                  highlightColor: AppColors.shimmerHighlight(isDark),
                  child: Text(
                    '${currencySymbol}0.00',
                    style: TextStyle(
                      fontSize: 32.sp,
                      fontWeight: FontWeight.w700,
                      height: 40 / 32,
                      letterSpacing: -0.64.sp,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.main
                          : AppColors.secondary,
                    ),
                  ),
                ),
              ] else ...[
                Flexible(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final minScale = 12.sp / 32.sp;
                      final maxChildWidth = constraints.maxWidth > 0
                          ? constraints.maxWidth / minScale
                          : double.infinity;

                      return FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: maxChildWidth),
                          child: Text(
                            pendingTotalDisplay,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 32.sp,
                              fontWeight: FontWeight.w700,
                              height: 40 / 32,
                              letterSpacing: -0.64.sp,
                              color: isDark
                                  ? AppColors.main
                                  : AppColors.secondary,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 14.w,
                color: isDark ? AppColors.white : AppColors.darkNav,
              ),
              SizedBox(width: 8.w),
              if (isLoading)
                Shimmer.fromColors(
                  baseColor: AppColors.shimmerBase(isDark),
                  highlightColor: AppColors.shimmerHighlight(isDark),
                  child: Container(
                    width: 180.w,
                    height: 14.sp,
                    color: isDark ? AppColors.darkCard : AppColors.white,
                  ),
                )
              else
                Expanded(
                  child: Text(
                    AppLocalizations.of(
                          context,
                        )?.avgApprovalTimeDesc(avgApprovalTime) ??
                        'Average approval time: $avgApprovalTime',
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: isDark ? AppColors.white : AppColors.navColor,
                      fontWeight: FontWeight.w500,
                      height: 18 / 13,
                      letterSpacing: 0,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
