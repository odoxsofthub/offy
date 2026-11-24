import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/filter_model.dart';
import '../../../../l10n/app_localizations.dart';
import 'app_filter_shimmers.dart';

class AppFilterCategoryAside extends StatelessWidget {
  final List<FilterOptionItemModel>? options;
  final FilterOption selectedOption;
  final ValueChanged<FilterOption> onOptionSelected;
  final bool Function(FilterOption option)? isOptionActive;
  final bool isLoading;
  final List<FilterOptionItemModel>? fallbackOptions;
  final int? optionsShimmerCount;

  const AppFilterCategoryAside({
    super.key,
    this.options,
    required this.selectedOption,
    required this.onOptionSelected,
    this.isOptionActive,
    this.isLoading = false,
    this.fallbackOptions,
    this.optionsShimmerCount,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    final resolvedOptions = (options != null && options!.isNotEmpty)
        ? options!
        : (fallbackOptions ??
            [
              FilterOptionItemModel(
                option: 'month',
                label: l10n?.months ?? 'Months',
                selection: 'multi',
                url: '',
              ),
            ]);

    // Ensure 'month' is always first if present
    final orderedOptions = () {
      final list = List<FilterOptionItemModel>.from(resolvedOptions);
      final monthIdx = list.indexWhere((o) => o.option.toLowerCase() == 'month');
      if (monthIdx > 0) {
        final monthOpt = list.removeAt(monthIdx);
        list.insert(0, monthOpt);
      }
      return list;
    }();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : const Color(0xFFF3EEE8),
        border: Border(
          right: BorderSide(
            color: isDark
                ? AppColors.darkNav.withValues(alpha: 0.3)
                : const Color(0xFFE7E0D8),
            width: 1.03.w,
          ),
        ),
      ),
      child: isLoading
          ? AppFilterOptionsShimmer(
              itemCount:
                  optionsShimmerCount ??
                  (options != null && options!.isNotEmpty
                      ? options!.length
                      : (fallbackOptions != null && fallbackOptions!.isNotEmpty
                          ? fallbackOptions!.length
                          : 3)),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: orderedOptions.map((opt) {
                final optOption = opt.filterOption;
                final isSelected = selectedOption == optOption;
                final hasFilter = isOptionActive?.call(optOption) ?? false;

                return InkWell(
                  onTap: () => onOptionSelected(optOption),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.49.w,
                      vertical: 16.49.h,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isDark ? AppColors.darkBg : const Color(0xFFFBF8F5))
                          : Colors.transparent,
                      border: Border(
                        left: BorderSide(
                          color:
                              isSelected ? AppColors.main : Colors.transparent,
                          width: 3.09.w,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            opt.label,
                            style: TextStyle(
                              fontSize: 14.95.sp,
                              fontWeight:
                                  isSelected ? FontWeight.w700 : FontWeight.w500,
                              height: 22 / 14.95,
                              color: isSelected
                                  ? (isDark
                                      ? AppColors.white
                                      : const Color(0xFF1A1918))
                                  : (isDark
                                      ? AppColors.white.withValues(alpha: 0.7)
                                      : const Color(0xFF43403D)),
                            ),
                          ),
                        ),
                        if (hasFilter)
                          Container(
                            width: 6.18.w,
                            height: 6.18.w,
                            decoration: const BoxDecoration(
                              color: AppColors.main,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }
}
