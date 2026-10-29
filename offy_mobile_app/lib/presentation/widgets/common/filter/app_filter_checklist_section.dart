import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/filter_model.dart';
import '../../../../data/models/expense_response_model.dart';
import '../../../../data/models/timeoff_response_model.dart';
import 'app_filter_check_item.dart';
import 'app_filter_shimmers.dart';

class AppFilterChecklistSection extends StatelessWidget {
  final List<FilterItemModel>? items;
  final Set<dynamic> selectedIds;
  final ValueChanged<dynamic> onIdToggled;
  final bool isLoading;
  final String emptyText;
  final IconData? icon;
  final Color? Function(FilterItemModel item)? indicatorColorResolver;
  final IconData? Function(FilterItemModel item)? iconResolver;
  final Color? Function(FilterItemModel item)? iconColorResolver;

  const AppFilterChecklistSection({
    super.key,
    required this.items,
    required this.selectedIds,
    required this.onIdToggled,
    this.isLoading = false,
    this.emptyText = 'No options available',
    this.icon,
    this.indicatorColorResolver,
    this.iconResolver,
    this.iconColorResolver,
  });

  /// Standard status color helper matching expense / timeoff status colors
  static Color statusColor(
    String key, {
    bool isDark = false,
    FilterSource? source,
  }) {
    if (source == FilterSource.timeoff) {
      return TimeOffLeaveStage.fromString(key).getColor(isDark: isDark);
    }
    return ExpenseStatus.fromString(key).getColor(isDark: isDark);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if ((isLoading || items == null) && (items == null || items!.isEmpty)) {
      return const AppFilterChecklistShimmer();
    }

    final itemList = items ?? const <FilterItemModel>[];

    if (itemList.isEmpty) {
      return Container(
        color: isDark ? AppColors.darkBg : const Color(0xFFFBF8F5),
        alignment: Alignment.center,
        padding: EdgeInsets.all(24.w),
        child: Text(
          emptyText,
          style: TextStyle(
            fontSize: 14.sp,
            color: isDark
                ? AppColors.white.withValues(alpha: 0.5)
                : const Color(0xFF75706B),
          ),
        ),
      );
    }

    return Container(
      color: isDark ? AppColors.darkBg : const Color(0xFFFBF8F5),
      child: ListView.builder(
        padding: EdgeInsets.only(bottom: 80.h),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: itemList.length,
        itemBuilder: (context, index) {
          final item = itemList[index];
          // Check if selected by int ID, string ID, or item ID
          final isSelected = selectedIds.contains(item.id) ||
              selectedIds.contains(item.idAsInt) ||
              selectedIds.contains(item.idAsString);

          final itemIcon = iconResolver?.call(item) ?? icon;
          final itemIconColor = iconColorResolver?.call(item);
          final indicatorColor = indicatorColorResolver?.call(item);

          return AppFilterCheckItem(
            label: item.label,
            isSelected: isSelected,
            onTap: () {
              // Pass int if item ID is int, selectedIds holds ints, or non-empty with int
              if (item.id is int ||
                  selectedIds is Set<int> ||
                  (selectedIds.isNotEmpty && selectedIds.first is int)) {
                onIdToggled(item.idAsInt);
              } else {
                onIdToggled(item.idAsString);
              }
            },
            showTopBorder: index > 0,
            icon: itemIcon,
            iconColor: itemIconColor,
            indicatorColor: indicatorColor,
          );
        },
      ),
    );
  }
}
