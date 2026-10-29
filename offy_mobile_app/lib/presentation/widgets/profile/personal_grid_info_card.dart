import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';


class _PersonalGridItemData {
  final String label;
  final String value;

  const _PersonalGridItemData({required this.label, required this.value});
}

class PersonalGridInfoCard extends StatelessWidget {
  final String gender;
  final String dob;
  final String maritalStatus;
  final String nationality;
  final String birthPlace;

  const PersonalGridInfoCard({
    super.key,
    required this.gender,
    required this.dob,
    required this.maritalStatus,
    required this.nationality,
    required this.birthPlace,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final allCandidates = [
      _PersonalGridItemData(label: AppLocalizations.of(context)?.gender ?? 'Gender', value: gender),
      _PersonalGridItemData(label: AppLocalizations.of(context)?.dob ?? 'DOB', value: dob),
      _PersonalGridItemData(label: AppLocalizations.of(context)?.maritalStatus ?? 'Marital Status', value: maritalStatus),
      _PersonalGridItemData(label: AppLocalizations.of(context)?.nationality ?? 'Nationality', value: nationality),
      _PersonalGridItemData(label: AppLocalizations.of(context)?.birthPlace ?? 'Birth place', value: birthPlace),
    ];

    final validItems = allCandidates.where((item) {
      final val = item.value.trim();
      return val.isNotEmpty && val != 'N/A';
    }).toList();

    if (validItems.isEmpty) return const SizedBox.shrink();

    // Group valid items into rows of at most 2 items
    final rows = <List<_PersonalGridItemData>>[];
    for (int i = 0; i < validItems.length; i += 2) {
      if (i + 1 < validItems.length) {
        rows.add([validItems[i], validItems[i + 1]]);
      } else {
        rows.add([validItems[i]]);
      }
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.darkCard.withValues(alpha: 0.3)
              : AppColors.light.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(rows.length, (rowIndex) {
            final isFirstRow = rowIndex == 0;
            final isLastRow = rowIndex == rows.length - 1;
            final rowItems = rows[rowIndex];

            if (rowItems.length == 1) {
              final item = rowItems[0];
              return _buildCell(
                context,
                label: item.label,
                value: item.value,
                border: isFirstRow
                    ? null
                    : Border(
                        top: BorderSide(color: AppColors.shade, width: 0.6.w),
                      ),
                borderRadius: BorderRadius.only(
                  topLeft: isFirstRow ? Radius.circular(12.r) : Radius.zero,
                  topRight: isFirstRow ? Radius.circular(12.r) : Radius.zero,
                  bottomLeft: isLastRow ? Radius.circular(10.r) : Radius.zero,
                  bottomRight: isLastRow ? Radius.circular(10.r) : Radius.zero,
                ),
              );
            }

            // 2 items in row
            final itemLeft = rowItems[0];
            final itemRight = rowItems[1];

            return Row(
              children: [
                Expanded(
                  child: _buildCell(
                    context,
                    label: itemLeft.label,
                    value: itemLeft.value,
                    border: isFirstRow
                        ? null
                        : Border(
                            top: BorderSide(
                              color: AppColors.shade,
                              width: 0.6.w,
                            ),
                          ),
                    borderRadius: BorderRadius.only(
                      topLeft: isFirstRow ? Radius.circular(12.r) : Radius.zero,
                      bottomLeft: isLastRow
                          ? Radius.circular(10.r)
                          : Radius.zero,
                    ),
                  ),
                ),
                Expanded(
                  child: _buildCell(
                    context,
                    label: itemRight.label,
                    value: itemRight.value,
                    border: Border(
                      top: isFirstRow
                          ? BorderSide.none
                          : BorderSide(color: AppColors.shade, width: 0.6.w),
                      left: BorderSide(color: AppColors.shade, width: 0.6.w),
                    ),
                    borderRadius: BorderRadius.only(
                      topRight: isFirstRow
                          ? Radius.circular(12.r)
                          : Radius.zero,
                      bottomRight: isLastRow
                          ? Radius.circular(10.r)
                          : Radius.zero,
                    ),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildCell(
    BuildContext context, {
    required String label,
    required String value,
    Border? border,
    BorderRadius? borderRadius,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 11.h),
      decoration: BoxDecoration(border: border, borderRadius: borderRadius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            textAlign: TextAlign.start,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              height: 18 / 12,
              color: AppColors.navColor,
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            value,
            textAlign: TextAlign.start,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w500,
              height: 18 / 16,
              color: isDark ? AppColors.white : AppColors.black,
            ),
          ),
        ],
      ),
    );
  }
}
