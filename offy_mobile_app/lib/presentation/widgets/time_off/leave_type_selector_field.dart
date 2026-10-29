import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/timeoff_response_model.dart';
import '../../../../l10n/app_localizations.dart';
import '../common/custom_error_text.dart';

class LeaveTypeSelectorField extends StatelessWidget {
  final List<TimeOffTypeModel> types;
  final int? selectedTypeId;
  final ValueChanged<TimeOffTypeModel> onTypeSelected;
  final bool hasError;
  final String? errorText;

  final bool isLoading;

  const LeaveTypeSelectorField({
    super.key,
    required this.types,
    required this.selectedTypeId,
    required this.onTypeSelected,
    this.hasError = false,
    this.errorText,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final inputBgColor = hasError
        ? (isDark ? const Color(0x26FD2323) : const Color(0xFFFFEFEF))
        : (isDark ? const Color(0xFF7B5C38) : Colors.white);
    final inputBorderColor = hasError
        ? const Color(0xFFFD2323)
        : (isDark ? const Color(0xFF7B5C38) : const Color(0xFFCAC3C0));

    if (isLoading && types.isEmpty) {
      return Shimmer.fromColors(
        baseColor: AppColors.shimmerBase(isDark),
        highlightColor: AppColors.shimmerHighlight(isDark),
        child: Container(
          height: 52.h,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.white,
            borderRadius: BorderRadius.circular(12.r),
          ),
        ),
      );
    }

    final selectedType = types.any((t) => t.id == selectedTypeId)
        ? types.firstWhere((t) => t.id == selectedTypeId)
        : null;

    final placeholder = AppLocalizations.of(context)?.selectLeaveType ?? 'Select Leave Type';
    String displayText = placeholder;
    if (selectedType != null) {
      displayText = selectedType.name;
      if (selectedType.remainingDisplay != 'Unlimited') {
        displayText += ' (${selectedType.remainingDisplay})';
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PopupMenuButton<TimeOffTypeModel>(
              initialValue: selectedType,
              enabled: types.isNotEmpty,
          position: PopupMenuPosition.under,
          offset: Offset(0, 4.h),
          elevation: 4,
          color: isDark ? AppColors.darkCard : Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
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
          onSelected: onTypeSelected,
          itemBuilder: (BuildContext context) {
            return types.map((TimeOffTypeModel type) {
              final isSelected = type.id == selectedTypeId;
              String title = type.name;
              if (type.remainingDisplay != 'Unlimited') {
                title += ' (${type.remainingDisplay})';
              }

              return PopupMenuItem<TimeOffTypeModel>(
                value: type,
                height: 44.h,
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isSelected
                              ? AppColors.main
                              : (isDark ? AppColors.white : AppColors.black),
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
              );
            }).toList();
          },
          child: Opacity(
            opacity: types.isEmpty ? 0.45 : 1.0,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
              decoration: BoxDecoration(
                color: inputBgColor,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: inputBorderColor,
                  width: 1.w,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      displayText,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: selectedType != null ? FontWeight.w500 : FontWeight.w400,
                        height: 20 / 14,
                        color: selectedType != null
                            ? (isDark ? AppColors.white : AppColors.black)
                            : (isDark ? const Color(0xFFA49D95) : AppColors.navColor),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Icon(
                    Icons.keyboard_arrow_down,
                    color: isDark ? Colors.white : const Color(0xFF5B4039),
                    size: 20.w,
                  ),
                ],
              ),
            ),
          ),
        ),
        CustomErrorText(errorText: hasError ? errorText : null),
      ],
    );
  },
    );
  }
}
