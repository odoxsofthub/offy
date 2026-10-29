import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/filter_model.dart';
import 'app_filter_check_item.dart';
import 'app_filter_date_range_trigger.dart';
import 'app_filter_preset_chips.dart';
import 'app_filter_shimmers.dart';

class AppFilterMonthsSection extends StatelessWidget {
  final DateTimeRange? selectedDateRange;
  final bool isCustomRangeActive;
  final Set<String> selectedMonths;
  final ValueChanged<String> onMonthToggled;
  final String selectedPreset;
  final ValueChanged<String> onPresetSelected;
  final VoidCallback? onDateRangeTap;
  final VoidCallback? onSelectMonth;
  final VoidCallback? onCustomRangeActivated;
  final VoidCallback? onClearMonthSelection;
  final VoidCallback? onDeactivateMonth;
  final bool isMonthActive;
  final List<String> months;
  final List<FilterBucketModel>? buckets;
  final List<FilterItemModel>? monthItems;
  final bool isLoading;
  final bool customRangeAvailable;
  final bool? hasAnyMonthSelected;
  final Set<String>? bucketsWithSelection;

  const AppFilterMonthsSection({
    super.key,
    this.selectedDateRange,
    this.isCustomRangeActive = false,
    this.isMonthActive = false,
    required this.selectedMonths,
    required this.onMonthToggled,
    required this.selectedPreset,
    required this.onPresetSelected,
    this.onDateRangeTap,
    this.onSelectMonth,
    this.onCustomRangeActivated,
    this.onClearMonthSelection,
    this.onDeactivateMonth,
    this.months = const [
      'Sep 2026',
      'Aug 2026',
      'Jul 2026',
      'Jun 2026',
      'May 2026',
      'Apr 2026',
      'Mar 2026',
      'Feb 2026',
      'Jan 2026',
      'Dec 2025',
      'Nov 2025',
      'Oct 2025',
    ],
    this.buckets,
    this.monthItems,
    this.isLoading = false,
    this.customRangeAvailable = true,
    this.hasAnyMonthSelected,
    this.bucketsWithSelection,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final anyMonthSelected = hasAnyMonthSelected ?? selectedMonths.isNotEmpty;
    final isDateRangeDisabled =
        isMonthActive && anyMonthSelected && !isCustomRangeActive;
    final isNeutralState =
        customRangeAvailable && !isMonthActive && !isCustomRangeActive;
    final areBothEmpty = (selectedDateRange == null) && !anyMonthSelected;
    final shouldInterceptMonthTap = isNeutralState && !areBothEmpty;
    final shouldDimCheckboxes = isNeutralState && !areBothEmpty;

    void handleDateRangeTriggerTap() {
      if (isDateRangeDisabled) {
        if (selectedDateRange != null) {
          onCustomRangeActivated?.call();
        } else {
          (onDeactivateMonth ?? onClearMonthSelection)?.call();
        }
      } else if (isCustomRangeActive) {
        onDateRangeTap?.call();
      } else {
        if (selectedDateRange != null) {
          onCustomRangeActivated?.call();
        } else {
          onDateRangeTap?.call();
        }
      }
    }

    final hasBuckets = buckets != null && buckets!.isNotEmpty;
    if (isLoading && !hasBuckets) {
      return const AppFilterMonthsShimmer(showHeader: true);
    }

    final hasServerItems = monthItems != null;
    final items = monthItems ?? const <FilterItemModel>[];

    return Container(
      color: isDark ? AppColors.darkBg : const Color(0xFFFBF8F5),
      child: Column(
        children: [
          if (customRangeAvailable)
            AppFilterDateRangeTrigger(
              selectedDateRange: selectedDateRange,
              isCustomRangeActive: isCustomRangeActive,
              isDisabled: isDateRangeDisabled,
              onTap: handleDateRangeTriggerTap,
            ),
          Expanded(
            child: GestureDetector(
              behavior: isCustomRangeActive
                  ? HitTestBehavior.opaque
                  : HitTestBehavior.deferToChild,
              onTap: isCustomRangeActive ? onSelectMonth : null,
              child: AnimatedOpacity(
                opacity: isCustomRangeActive ? 0.45 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: AbsorbPointer(
                  absorbing: isCustomRangeActive,
                  child: Column(
                    children: [
                      AppFilterPresetChips(
                        selectedPreset: selectedPreset,
                        isDisabled: isCustomRangeActive,
                        onPresetSelected: onPresetSelected,
                        buckets: buckets,
                        bucketsWithSelection: bucketsWithSelection,
                      ),
                      Expanded(
                        child: GestureDetector(
                          behavior: shouldInterceptMonthTap
                              ? HitTestBehavior.opaque
                              : HitTestBehavior.deferToChild,
                          onTap: shouldInterceptMonthTap ? onSelectMonth : null,
                          child: AbsorbPointer(
                            absorbing: shouldInterceptMonthTap,
                            child: isLoading
                                ? const AppFilterMonthsShimmer(
                                    showHeader: false,
                                  )
                                : hasServerItems
                                ? items.isEmpty
                                      ? Center(
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(
                                              vertical: 32.h,
                                            ),
                                            child: Text(
                                              'No months available',
                                              style: TextStyle(
                                                fontSize: 14.sp,
                                                color: isDark
                                                    ? AppColors.white
                                                          .withValues(
                                                            alpha: 0.5,
                                                          )
                                                    : const Color(0xFF75706B),
                                              ),
                                            ),
                                          ),
                                        )
                                      : ListView.builder(
                                          padding: EdgeInsets.only(
                                            bottom: 82.46.h,
                                          ),
                                          physics: shouldInterceptMonthTap
                                              ? const NeverScrollableScrollPhysics()
                                              : const AlwaysScrollableScrollPhysics(),
                                          itemCount: items.length,
                                          itemBuilder: (context, index) {
                                            final item = items[index];
                                            final isSelected = selectedMonths
                                                .contains(item.idAsString);
                                            return AppFilterCheckItem(
                                              label: item.label,
                                              isSelected: isSelected,
                                              isDimmedCheckbox:
                                                  shouldDimCheckboxes,
                                              onTap: () => onMonthToggled(
                                                item.idAsString,
                                              ),
                                              showTopBorder: index > 0,
                                            );
                                          },
                                        )
                                : ListView.builder(
                                    padding: EdgeInsets.only(bottom: 82.46.h),
                                    physics: shouldInterceptMonthTap
                                        ? const NeverScrollableScrollPhysics()
                                        : const AlwaysScrollableScrollPhysics(),
                                    itemCount: months.length,
                                    itemBuilder: (context, index) {
                                      final month = months[index];
                                      final isSelected = selectedMonths
                                          .contains(month);
                                      return AppFilterCheckItem(
                                        label: month,
                                        isSelected: isSelected,
                                        isDimmedCheckbox: shouldDimCheckboxes,
                                        onTap: () => onMonthToggled(month),
                                        showTopBorder: index > 0,
                                      );
                                    },
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
