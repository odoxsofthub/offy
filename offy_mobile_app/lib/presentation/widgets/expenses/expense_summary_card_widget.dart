import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/expense_response_model.dart';
import 'expense_documents_section.dart';
import 'expense_expandable_bottom_section.dart';

class ExpenseSummaryCardWidget extends StatelessWidget {
  final String category;
  final String title;
  final String date;
  final String status;
  final IconData? icon;
  final bool isCompact;
  final bool hasReceipt;
  final List<dynamic>? documents;
  final String? amountDisplay;
  final String? paymentStatus;
  final List<ExpenseBreakdownItem>? breakdownItems;
  final bool isPartiallyPaid;
  final String? amountPaidDisplay;

  const ExpenseSummaryCardWidget({
    super.key,
    this.category = '',
    this.title = '',
    this.date = '',
    this.status = '',
    this.icon,
    this.isCompact = false,
    this.hasReceipt = false,
    this.documents,
    this.amountDisplay,
    this.paymentStatus,
    this.breakdownItems,
    this.isPartiallyPaid = false,
    this.amountPaidDisplay,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusEnum = ExpenseStatus.fromString(status);
    final statusColor = statusEnum.getColor(isDark: isDark);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Frame 33: Category & Title Container
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Frame 2609831: Category Badge & Status Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Icon Box Background (26px x 26px, 4.98.r)
                      Container(
                        width: 26.w,
                        height: 26.w,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0x1AE4E2E1)
                              : const Color(0xFFE4E2E1),
                          borderRadius: BorderRadius.circular(4.98.r),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          icon ?? Icons.receipt_long_rounded,
                          size: 14.r,
                          color: AppColors.secondary,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        category,
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          height: 24 / 14,
                          color: AppColors.secondary,
                        ),
                      ),
                    ],
                  ),
                  if (status.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusEnum.icon, size: 16.r, color: statusColor),
                        SizedBox(width: 4.w),
                        Text(
                          status,
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w500,
                            height: 18 / 13,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              SizedBox(height: 9.h),

              // Title Text
              Text(
                title,
                maxLines: isCompact ? 1 : null,
                overflow: isCompact ? TextOverflow.ellipsis : null,
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w600,
                  height: 22 / 18,
                  color: isDark ? AppColors.white : AppColors.black,
                ),
              ),
            ],
          ),
          if (!isCompact) ...[
            SizedBox(height: 10.h),

            if (documents != null && documents!.isNotEmpty)
              ExpenseDocumentsSection(documents: documents!),

            // Line 3 Divider (full horizontal space)
            Divider(
              height: 0,
              thickness: 0.6,
              color: isDark ? AppColors.darkNav : AppColors.navColor,
            ),
            SizedBox(height: 10.h),

            // Expandable Bottom Section
            ExpenseExpandableBottomSection(
              date: date,
              amountDisplay: amountDisplay,
              paymentStatus: paymentStatus,
              breakdownItems: breakdownItems,
              isPartiallyPaid: isPartiallyPaid,
              amountPaidDisplay: amountPaidDisplay,
            ),
          ],
        ],
      ),
    );
  }
}
