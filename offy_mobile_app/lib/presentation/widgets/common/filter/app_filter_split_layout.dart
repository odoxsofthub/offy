import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/filter_model.dart';
import 'app_filter_action_bar.dart';
import 'app_filter_category_aside.dart';
import 'app_filter_checklist_section.dart';
import 'app_filter_months_section.dart';

class AppFilterSplitLayout extends StatelessWidget {
  // Navigation & Options
  final List<FilterOptionItemModel>? options;
  final FilterOption selectedOption;
  final ValueChanged<FilterOption> onOptionSelected;
  final bool isOptionsLoading;
  final bool isContentLoading;
  final bool Function(FilterOption option)? isOptionActive;
  final List<FilterOptionItemModel>? fallbackOptions;
  final int? optionsShimmerCount;

  // Month / Date Range
  final Set<String> selectedMonths;
  final ValueChanged<String> onMonthToggled;
  final String selectedPreset;
  final ValueChanged<String> onPresetSelected;
  final VoidCallback? onDateRangeTap;
  final VoidCallback? onSelectMonth;
  final VoidCallback? onCustomRangeActivated;
  final VoidCallback? onClearMonthSelection;
  final VoidCallback? onDeactivateMonth;
  final DateTimeRange? selectedDateRange;
  final bool isCustomRangeActive;
  final bool isMonthActive;
  final bool customRangeAvailable;
  final List<FilterBucketModel>? buckets;
  final List<FilterItemModel>? monthItems;
  final bool? hasDateFilter;
  final bool? hasAnyMonthSelected;
  final Set<String>? bucketsWithSelection;

  // Category / Type / Status Checklist props
  final List<FilterItemModel>? categoryItems;
  final Set<dynamic>? selectedCategoryIds;
  final ValueChanged<dynamic>? onCategoryIdToggled;

  final List<FilterItemModel>? typeItems;
  final Set<dynamic>? selectedTypeIds;
  final ValueChanged<dynamic>? onTypeIdToggled;

  final List<FilterItemModel>? statusItems;
  final Set<dynamic>? selectedStatusIds;
  final ValueChanged<dynamic>? onStatusIdToggled;
  final Color? Function(FilterItemModel item)? statusIndicatorColorResolver;
  final FilterSource? source;

  // Generic extension for custom or future options
  final Widget Function(BuildContext context, FilterOption option)?
  customContentBuilder;

  // Footer: selections only take effect on Apply; Reset clears them.
  final VoidCallback? onApply;
  final VoidCallback? onReset;
  final bool isApplying;

  const AppFilterSplitLayout({
    super.key,
    this.options,
    required this.selectedOption,
    required this.onOptionSelected,
    this.isOptionsLoading = false,
    this.isContentLoading = false,
    this.isOptionActive,
    this.fallbackOptions,
    this.optionsShimmerCount,
    // Month props
    this.selectedMonths = const {},
    required this.onMonthToggled,
    this.selectedPreset = 'recent',
    required this.onPresetSelected,
    this.onDateRangeTap,
    this.onSelectMonth,
    this.onCustomRangeActivated,
    this.onClearMonthSelection,
    this.onDeactivateMonth,
    this.selectedDateRange,
    this.isCustomRangeActive = false,
    this.isMonthActive = false,
    this.customRangeAvailable = true,
    this.buckets,
    this.monthItems,
    this.hasDateFilter,
    this.hasAnyMonthSelected,
    this.bucketsWithSelection,
    // Checklist props
    this.categoryItems,
    this.selectedCategoryIds,
    this.onCategoryIdToggled,
    this.typeItems,
    this.selectedTypeIds,
    this.onTypeIdToggled,
    this.statusItems,
    this.selectedStatusIds,
    this.onStatusIdToggled,
    this.statusIndicatorColorResolver,
    this.source,
    this.customContentBuilder,
    this.onApply,
    this.onReset,
    this.isApplying = false,
  });

  FilterSource get _effectiveSource {
    if (source != null) return source!;
    if (typeItems != null || selectedTypeIds != null) {
      return FilterSource.timeoff;
    }
    return FilterSource.expense;
  }

  bool _defaultIsOptionActive(FilterOption option) {
    switch (option) {
      case FilterOption.month:
      case FilterOption.dateRange:
        return hasDateFilter ??
            (isCustomRangeActive
                ? (selectedDateRange != null)
                : (isMonthActive &&
                      (hasAnyMonthSelected ?? selectedMonths.isNotEmpty)));
      case FilterOption.category:
        return selectedCategoryIds != null && selectedCategoryIds!.isNotEmpty;
      case FilterOption.leaveType:
        return selectedTypeIds != null && selectedTypeIds!.isNotEmpty;
      case FilterOption.status:
        return selectedStatusIds != null && selectedStatusIds!.isNotEmpty;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final panel = Container(
      color: isDark ? AppColors.darkBg : const Color(0xFFFBF8F5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            flex: 38,
            fit: FlexFit.tight,
            child: AppFilterCategoryAside(
              options: options,
              selectedOption: selectedOption,
              onOptionSelected: onOptionSelected,
              isLoading: isOptionsLoading,
              isOptionActive: (opt) =>
                  isOptionActive?.call(opt) ?? _defaultIsOptionActive(opt),
              fallbackOptions: fallbackOptions,
              optionsShimmerCount: optionsShimmerCount,
            ),
          ),
          Expanded(flex: 62, child: _buildContent(context)),
        ],
      ),
    );
    if (onApply == null) return panel;
    return Column(
      children: [
        Expanded(child: panel),
        AppFilterActionBar(
          onReset: onReset ?? () {},
          onPrimary: onApply!,
          isBusy: isApplying,
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveLoading = isContentLoading || isOptionsLoading;
    if (customContentBuilder != null) {
      final customWidget = customContentBuilder!(context, selectedOption);
      if (customWidget is! SizedBox) {
        return customWidget;
      }
    }

    switch (selectedOption) {
      case FilterOption.month:
      case FilterOption.dateRange:
        return AppFilterMonthsSection(
          selectedDateRange: selectedDateRange,
          isCustomRangeActive: isCustomRangeActive,
          isMonthActive: isMonthActive,
          selectedMonths: selectedMonths,
          onMonthToggled: onMonthToggled,
          selectedPreset: selectedPreset,
          onPresetSelected: onPresetSelected,
          onDateRangeTap: onDateRangeTap,
          onSelectMonth: onSelectMonth,
          onCustomRangeActivated: onCustomRangeActivated,
          onClearMonthSelection: onClearMonthSelection,
          onDeactivateMonth: onDeactivateMonth ?? onClearMonthSelection,
          buckets: buckets,
          monthItems: monthItems,
          isLoading: effectiveLoading,
          customRangeAvailable: customRangeAvailable,
          hasAnyMonthSelected: hasAnyMonthSelected,
          bucketsWithSelection: bucketsWithSelection,
        );

      case FilterOption.status:
        return AppFilterChecklistSection(
          items: statusItems,
          selectedIds: selectedStatusIds ?? const {},
          onIdToggled: onStatusIdToggled ?? (_) {},
          isLoading: effectiveLoading,
          emptyText: 'No status options available',
          indicatorColorResolver:
              statusIndicatorColorResolver ??
              (item) => AppFilterChecklistSection.statusColor(
                item.idAsString.isNotEmpty ? item.idAsString : item.label,
                isDark: isDark,
                source: _effectiveSource,
              ),
        );

      case FilterOption.category:
        return AppFilterChecklistSection(
          items: categoryItems,
          selectedIds: selectedCategoryIds ?? const {},
          onIdToggled: onCategoryIdToggled ?? (_) {},
          isLoading: effectiveLoading,
          emptyText: 'No categories available',
        );

      case FilterOption.leaveType:
        return AppFilterChecklistSection(
          items: typeItems,
          selectedIds: selectedTypeIds ?? const {},
          onIdToggled: onTypeIdToggled ?? (_) {},
          isLoading: effectiveLoading,
          emptyText: 'No leave types available',
        );
    }
  }
}
