import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/expense_response_model.dart';
import '../../../core/navigation/app_router.dart';
import '../../screens/expenses/expense_log_screen.dart';
import '../../viewmodels/expenses/expenses_provider.dart';

class ExpenseItemWidget extends StatelessWidget {
  final RecentExpenseModel expense;
  final VoidCallback? onBeforeNavigate;

  const ExpenseItemWidget({
    super.key,
    required this.expense,
    this.onBeforeNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = expense.statusEnum.getColor(isDark: isDark);

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: () async {
          final provider = context.read<ExpensesProvider>();
          if (provider.isInteractionBlocked) return;
          provider.cancelDebounce();
          onBeforeNavigate?.call();
          FocusManager.instance.primaryFocus?.unfocus();
          FocusScope.of(context).unfocus();

          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              settings: const RouteSettings(name: AppRouter.expenseLog),
              builder: (context) => ExpenseLogsScreen(expenseId: expense.id),
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
        child: Container(
          margin: EdgeInsets.only(bottom: 14.h),
          padding: EdgeInsets.all(10.w),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : const Color(0xFFFFFFFF),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    Container(
                      width: 53.w,
                      height: 54.19.w,
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0x1AE4E2E1)
                            : const Color(0XFFE4E2E1),
                        borderRadius: BorderRadius.circular(9.03.r),
                      ),
                      child: Center(
                        child: Icon(
                          expense.iconData,
                          color: AppColors.secondary,
                          size: 19.w,
                        ),
                      ),
                    ),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            expense.title,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              height: 24 / 14,
                              letterSpacing: 0,
                              color: isDark ? Colors.white : AppColors.black,
                            ),
                          ),
                          SizedBox(height: 5.h),
                          Text(
                            _formatExpenseDate(expense.date),
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w500,
                              height: 18 / 13,
                              letterSpacing: 0,
                              color: isDark
                                  ? AppColors.light
                                  : AppColors.navColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 12.w),
                  ],
                ),
              ),
              Flexible(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final minScale = 10.sp / 16.sp;
                        final maxChildWidth = constraints.maxWidth > 0
                            ? constraints.maxWidth / minScale
                            : double.infinity;

                        return FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: maxChildWidth,
                            ),
                            child: Text(
                              expense.amountDisplay,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w700,
                                height: 24 / 16,
                                letterSpacing: 0,
                                color: isDark ? Colors.white : AppColors.black,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    SizedBox(height: 5.h),
                    Wrap(
                      alignment: WrapAlignment.end,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 4.w,
                      runSpacing: 2.h,
                      children: [
                        Icon(
                          expense.statusEnum.icon,
                          size: 11.67.w,
                          color: statusColor,
                        ),
                        Text(
                          expense.statusDisplay.isNotEmpty
                              ? expense.statusDisplay
                              : expense.status,
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w500,
                            height: 18 / 13,
                            letterSpacing: 0,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatExpenseDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return AppDateFormatter.mmmmDdYyyy(dt);
    } catch (_) {
      return dateStr;
    }
  }
}
