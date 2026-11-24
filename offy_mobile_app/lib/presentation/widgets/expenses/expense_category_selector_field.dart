import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/expense_category_model.dart';
import '../common/custom_error_text.dart';

class ExpenseCategorySelectorField extends StatelessWidget {
  final bool isSubmitting;
  final String? selectedCategory;
  final List<ExpenseCategoryModel> categories;
  final ValueChanged<String?> onCategorySelected;
  final String? hintText;
  final bool showAllOption;

  final bool isLoading;
  final String? errorText;

  const ExpenseCategorySelectorField({
    super.key,
    required this.isSubmitting,
    required this.selectedCategory,
    required this.categories,
    required this.onCategorySelected,
    this.hintText,
    this.showAllOption = false,
    this.isLoading = false,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final inputBorderColor = isDark
        ? const Color.fromRGBO(209, 199, 176, 0.1)
        : const Color(0xFFD1C7B0);

    if (isLoading && categories.isEmpty) {
      return Shimmer.fromColors(
        baseColor: AppColors.shimmerBase(isDark),
        highlightColor: AppColors.shimmerHighlight(isDark),
        child: Container(
          height: 52.h,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.white,
            borderRadius: BorderRadius.circular(8.r),
          ),
        ),
      );
    }

    final selectedCategoryModel = categories.any((c) => c.name == selectedCategory)
        ? categories.firstWhere((c) => c.name == selectedCategory)
        : null;

    final effectiveHint = hintText ?? AppLocalizations.of(context)?.selectCategory ?? 'Select Category';

    return LayoutBuilder(
      builder: (context, constraints) {
        return PopupMenuButton<String>(
          initialValue: selectedCategory,
          enabled: !isSubmitting && categories.isNotEmpty,
          position: PopupMenuPosition.under,
          offset: Offset(0, 4.h),
          elevation: 4,
          color: isDark ? AppColors.darkCard : Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.r),
            side: BorderSide(
              color: inputBorderColor,
              width: 1.w,
            ),
          ),
          constraints: BoxConstraints(
            minWidth: constraints.maxWidth,
            maxWidth: constraints.maxWidth,
            maxHeight: 260.h,
          ),
          onSelected: (val) {
            if (val.isEmpty) {
              onCategorySelected(null);
            } else {
              onCategorySelected(val);
            }
          },
          itemBuilder: (BuildContext context) {
            final List<PopupMenuEntry<String>> items = [];

            if (showAllOption) {
              final isAllSelected = selectedCategory == null || selectedCategory!.isEmpty;
              items.add(
                PopupMenuItem<String>(
                  value: '',
                  height: 44.h,
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          AppLocalizations.of(context)?.allCategories ?? 'All Categories',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: isAllSelected ? FontWeight.w600 : FontWeight.w400,
                            height: 1.5,
                            color: isAllSelected
                                ? AppColors.main
                                : (isDark ? const Color(0xFFF3E9E0) : AppColors.black),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isAllSelected) ...[
                        SizedBox(width: 8.w),
                        Icon(
                          Icons.check_rounded,
                          color: AppColors.main,
                          size: 18.w,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }

            for (final cat in categories) {
              final isSelected = cat.name == selectedCategory;
              items.add(
                PopupMenuItem<String>(
                  value: cat.name,
                  height: 44.h,
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          cat.name,
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            height: 1.5,
                            color: isSelected
                                ? AppColors.main
                                : (isDark ? const Color(0xFFF3E9E0) : AppColors.black),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isSelected) ...[
                        SizedBox(width: 8.w),
                        Icon(
                          Icons.check_rounded,
                          color: AppColors.main,
                          size: 18.w,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }

            return items;
          },
          child: Opacity(
            opacity: (isSubmitting || categories.isEmpty) ? 0.45 : 1.0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                  decoration: BoxDecoration(
                    color: errorText != null
                        ? (isDark ? const Color(0x26FD2323) : const Color(0xFFFFEFEF))
                        : (isDark
                            ? const Color.fromRGBO(246, 243, 242, 0.1)
                            : const Color(0xFFF6F3F2)),
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(
                      color: errorText != null
                          ? const Color(0xFFFD2323)
                          : inputBorderColor,
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          selectedCategoryModel?.name ?? effectiveHint,
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w400,
                            height: 1.5,
                            color: selectedCategoryModel != null
                                ? (isDark
                                    ? const Color(0xFFF3E9E0)
                                    : AppColors.black)
                                : (isDark
                                    ? const Color(0xFFA49D95)
                                    : const Color(0xFF6B7280)),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Icon(
                        Icons.keyboard_arrow_down,
                        color: isDark
                            ? const Color(0xFF9F4122)
                            : AppColors.tertiary,
                        size: 20.w,
                      ),
                    ],
                  ),
                ),
                CustomErrorText(errorText: errorText),
              ],
            ),
          ),
        );
      },
    );
  }
}
