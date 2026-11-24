import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';

enum ActiveDateSelection { start, end }

class CustomDateRangeIndicator extends StatelessWidget {
  final DateTime? startDate;
  final DateTime? endDate;
  final ActiveDateSelection activeSelection;
  final ValueChanged<ActiveDateSelection>? onSelectionChanged;

  const CustomDateRangeIndicator({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.activeSelection,
    this.onSelectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final dateFormat = DateFormat('MMM d, yyyy');

    final startDateText = startDate != null
        ? dateFormat.format(startDate!)
        : (l10n?.selectDate ?? 'Select Date');

    final endDateText = endDate != null
        ? dateFormat.format(endDate!)
        : (l10n?.selectDate ?? 'Select Date');

    return Row(
      children: [
        Expanded(
          child: _buildDateBox(
            context: context,
            isDark: isDark,
            label: l10n?.startDate ?? 'START DATE',
            dateText: startDateText,
            hasValue: startDate != null,
            isActive: activeSelection == ActiveDateSelection.start,
            onTap: () => onSelectionChanged?.call(ActiveDateSelection.start),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w),
          child: Icon(
            Icons.arrow_forward_rounded,
            size: 16.sp,
            color: const Color(0xFF8E837D),
          ),
        ),
        Expanded(
          child: _buildDateBox(
            context: context,
            isDark: isDark,
            label: l10n?.endDate ?? 'END DATE',
            dateText: endDateText,
            hasValue: endDate != null,
            isActive: activeSelection == ActiveDateSelection.end,
            onTap: () => onSelectionChanged?.call(ActiveDateSelection.end),
          ),
        ),
      ],
    );
  }

  Widget _buildDateBox({
    required BuildContext context,
    required bool isDark,
    required String label,
    required String dateText,
    required bool hasValue,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final borderColor = isActive
        ? AppColors.main
        : (isDark ? AppColors.darkNav.withValues(alpha: 0.4) : AppColors.midLight);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.white,
          border: Border.all(
            color: borderColor,
            width: 1.w,
          ),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 12.sp,
                height: 14 / 12,
                color: const Color(0xFF8E837D),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 4.h),
            Text(
              dateText,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16.sp,
                height: 19 / 16,
                color: hasValue
                    ? (isDark ? AppColors.white : Colors.black)
                    : const Color(0xFF8E837D),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
