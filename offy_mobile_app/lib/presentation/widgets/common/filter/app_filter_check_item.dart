import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';

class AppFilterCheckItem extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool showTopBorder;
  final IconData? icon;
  final Color? iconColor;
  final Color? indicatorColor;
  final int? count;
  final bool isDisabled;
  final bool isDimmedCheckbox;

  const AppFilterCheckItem({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.showTopBorder = true,
    this.icon,
    this.iconColor,
    this.indicatorColor,
    this.count,
    this.isDisabled = false,
    this.isDimmedCheckbox = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final effectiveIconColor = iconColor ??
        (isSelected
            ? AppColors.main
            : (isDark ? AppColors.navColor : const Color(0xFF75706B)));

    return InkWell(
      onTap: isDisabled ? null : onTap,
      child: Container(
        decoration: BoxDecoration(
          border: showTopBorder
              ? Border(
                  top: BorderSide(
                    color: isDark
                        ? AppColors.darkNav.withValues(alpha: 0.3)
                        : const Color(0xFFE7E0D8).withValues(alpha: 0.4),
                    width: 1.03.w,
                  ),
                )
              : null,
        ),
        padding: isSelected
            ? EdgeInsets.fromLTRB(16.49.w, 12.63.h, 14.43.w, 12.63.h)
            : EdgeInsets.fromLTRB(16.49.w, 14.43.h, 16.49.w, 14.43.h),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  if (indicatorColor != null) ...[
                    Container(
                      width: 10.w,
                      height: 10.w,
                      decoration: BoxDecoration(
                        color: indicatorColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 8.w),
                  ] else if (icon != null) ...[
                    Icon(
                      icon,
                      size: 16.sp,
                      color: effectiveIconColor,
                    ),
                    SizedBox(width: 8.w),
                  ],
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 15.46.sp,
                              fontWeight: FontWeight.w500,
                              height: 23 / 15.46,
                              color: isDisabled
                                  ? (isDark
                                      ? AppColors.white.withValues(alpha: 0.3)
                                      : const Color(0xFF75706B)
                                          .withValues(alpha: 0.5))
                                  : (isDark
                                      ? AppColors.white
                                      : const Color(0xFF1A1918)),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (count != null && count! > 0) ...[
                          SizedBox(width: 6.w),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6.w,
                              vertical: 2.h,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.darkTertiary
                                  : const Color(0xFFE7E0D8)
                                      .withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                            child: Text(
                              '$count',
                              style: TextStyle(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? AppColors.white.withValues(alpha: 0.7)
                                    : const Color(0xFF75706B),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 12.w),
            isSelected
                ? Container(
                    width: 26.8.w,
                    height: 26.8.w,
                    decoration: BoxDecoration(
                      color: isDimmedCheckbox
                          ? AppColors.main.withValues(alpha: 0.45)
                          : AppColors.main,
                      borderRadius: BorderRadius.circular(6.18.r),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.check_rounded,
                        size: 18.sp,
                        color: isDimmedCheckbox
                            ? AppColors.white.withValues(alpha: 0.7)
                            : AppColors.white,
                      ),
                    ),
                  )
                : Container(
                    width: 22.68.w,
                    height: 22.68.w,
                    decoration: BoxDecoration(
                      color: isDimmedCheckbox
                          ? (isDark
                              ? AppColors.darkNav.withValues(alpha: 0.35)
                              : const Color(0xFFE8E2DA))
                          : (isDark ? AppColors.darkCard : AppColors.white),
                      border: Border.all(
                        color: isDimmedCheckbox
                            ? (isDark
                                ? AppColors.darkNav.withValues(alpha: 0.5)
                                : const Color(0xFFCCC4BA))
                            : (isDark
                                ? AppColors.darkNav
                                : const Color(0xFFA39C94)),
                        width: 2.06.w,
                      ),
                      borderRadius: BorderRadius.circular(6.18.r),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
