import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/navigation/app_router.dart';
import '../../viewmodels/expenses/expenses_provider.dart';
import 'expense_item_widget.dart';
import '../../screens/expenses/my_expenses_list_screen.dart';
import '../../viewmodels/user/access_provider.dart';
import '../common/two_lines_scaled_text.dart';

class ExpensesList extends StatelessWidget {
  const ExpensesList({super.key});

  Widget _buildShimmerLoading(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencySymbol =
        context
            .read<AccessProvider>()
            .accessDetails
            ?.company
            ?.defaultCompanyCurrency
            ?.symbol ??
        '\$';
    return Column(
      children: List.generate(
        3,
        (index) => Container(
          margin: EdgeInsets.only(bottom: 14.h),
          padding: EdgeInsets.all(10.w),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.white,
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Shimmer.fromColors(
            baseColor: AppColors.shimmerBase(isDark),
            highlightColor: AppColors.shimmerHighlight(isDark),
            child: Row(
              children: [
                Container(
                  width: 53.w,
                  height: 54.19.w,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : AppColors.white,
                    borderRadius: BorderRadius.circular(9.03.r),
                  ),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        height: 14.h,
                        color: isDark ? AppColors.darkCard : AppColors.white,
                      ),
                      SizedBox(height: 8.h),
                      Container(
                        width: 100.w,
                        height: 12.h,
                        color: isDark ? AppColors.darkCard : AppColors.white,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 20.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${currencySymbol}0.00',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        height: 22 / 16,
                        color: isDark ? AppColors.white : AppColors.black,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Container(
                      width: 80.w,
                      height: 12.h,
                      color: isDark ? AppColors.darkCard : AppColors.white,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpensesProvider>();
    final expenses = provider.summary?.recentExpenses ?? [];
    final isLoading = provider.isLoading && provider.summary == null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: TwoLinesScaledText(
                text: AppLocalizations.of(context)?.myExpenses ?? 'My Expenses',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w600,
                  height: 28 / 18,
                  letterSpacing: 0,
                  color: isDark ? Colors.white : AppColors.black,
                ),
              ),
            ),
            if (expenses.isNotEmpty)
              InkWell(
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      settings: const RouteSettings(
                        name: AppRouter.myExpensesList,
                      ),
                      builder: (context) => const MyExpensesListScreen(),
                    ),
                  );
                  if (result != false && context.mounted) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (context.mounted) {
                        context.read<ExpensesProvider>().fetchExpenseSummary();
                      }
                    });
                  }
                },
                borderRadius: BorderRadius.circular(6.r),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
                  child: Text(
                    AppLocalizations.of(context)?.viewAll ?? 'View All',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      height: 16 / 12,
                      letterSpacing: 0.6.sp,
                      color: isDark ? AppColors.main : AppColors.secondary,
                    ),
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: 16.h),
        if (isLoading)
          _buildShimmerLoading(context)
        else if (expenses.isEmpty)
          Container(
            height: 150.h,
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
                AppLocalizations.of(context)?.noExpensesFound ??
                    'No expenses found',
                style: TextStyle(
                  color: isDark ? const Color(0xFFEAE1D8) : Colors.grey[600],
                  fontSize: 14.sp,
                ),
              ),
            ),
          )
        else ...[
          ...expenses.map((expense) => ExpenseItemWidget(expense: expense)),
        ],
      ],
    );
  }
}
