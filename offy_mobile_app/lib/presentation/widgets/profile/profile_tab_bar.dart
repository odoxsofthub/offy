import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';


class ProfileTabBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabChanged;

  const ProfileTabBar({
    super.key,
    required this.currentIndex,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget buildTab(int index, String label) {
      final isSelected = currentIndex == index;
      return Expanded(
        child: GestureDetector(
          onTap: () => onTabChanged(index),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? (isDark ? AppColors.darkCard : AppColors.midLight)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(isSelected ? 70.r : 6.r),
            ),
            padding: EdgeInsets.symmetric(vertical: 12.h),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w500,
                  height: 22 / 16,
                  color: isSelected
                      ? (isDark ? AppColors.main : AppColors.secondary)
                      : (isDark ? AppColors.midLight : AppColors.black),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 35.w),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.darkNav.withValues(alpha: 0.4)
              : AppColors.light.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(60.r),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            buildTab(0, AppLocalizations.of(context)?.work ?? 'Work'),
            buildTab(1, AppLocalizations.of(context)?.personal ?? 'Personal'),
            buildTab(2, AppLocalizations.of(context)?.docs ?? 'Docs'),
          ],
        ),
      ),
    );
  }
}
