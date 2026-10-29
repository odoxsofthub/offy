import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';

class AppFilterDateRangeTrigger extends StatelessWidget {
  final DateTimeRange? selectedDateRange;
  final bool isCustomRangeActive;
  final bool isDisabled;
  final VoidCallback? onTap;

  const AppFilterDateRangeTrigger({
    super.key,
    this.selectedDateRange,
    this.isCustomRangeActive = false,
    this.isDisabled = false,
    this.onTap,
  });

  String _formatRange(DateTime start, DateTime end) {
    if (start.year == end.year &&
        start.month == end.month &&
        start.day == end.day) {
      return DateFormat('MMM d, yyyy').format(start);
    }
    return '${DateFormat('MMM d, yyyy').format(start)} – ${DateFormat('MMM d, yyyy').format(end)}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasDateRange = selectedDateRange != null;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final effectiveIsDisabled = isDisabled;

    final days = hasDateRange
        ? selectedDateRange!.end.difference(selectedDateRange!.start).inDays.abs() + 1
        : 0;
    final daysText = AppLocalizations.of(context)?.daysSelected(days) ??
        '$days ${days == 1 ? 'day' : 'days'} selected';

    final iconColor = effectiveIsDisabled
        ? (isDark
            ? AppColors.white.withValues(alpha: 0.38)
            : const Color(0xFF75706B).withValues(alpha: 0.4))
        : (isDark ? AppColors.white : null);

    final titleColor = effectiveIsDisabled
        ? (isDark
            ? AppColors.white.withValues(alpha: 0.38)
            : const Color(0xFF43403D).withValues(alpha: 0.38))
        : (isDark ? AppColors.white : const Color(0xFF43403D));

    final dateRangeColor = effectiveIsDisabled
        ? (isDark
            ? AppColors.white.withValues(alpha: 0.38)
            : const Color(0xFF75706B).withValues(alpha: 0.5))
        : (isDark ? const Color(0xFFFF8A65) : AppColors.secondary);

    final daysTextColor = effectiveIsDisabled
        ? (isDark
            ? AppColors.white.withValues(alpha: 0.3)
            : const Color(0xFF75706B).withValues(alpha: 0.4))
        : (isDark
            ? AppColors.white.withValues(alpha: 0.6)
            : const Color(0xFF75706B));

    final chevronColor = effectiveIsDisabled
        ? (isDark
            ? AppColors.navColor.withValues(alpha: 0.35)
            : const Color(0xFF75706B).withValues(alpha: 0.35))
        : (isDark ? AppColors.navColor : const Color(0xFF75706B));

    return AnimatedOpacity(
      opacity: effectiveIsDisabled ? 0.45 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: InkWell(
        onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? (effectiveIsDisabled
                  ? AppColors.darkTopCard.withValues(alpha: 0.5)
                  : AppColors.darkTopCard)
              : (effectiveIsDisabled
                  ? const Color(0xFFFAF6F1).withValues(alpha: 0.35)
                  : const Color(0xFFFAF6F1).withValues(alpha: 0.6)),
          border: Border(
            bottom: BorderSide(
              color: isDark
                  ? AppColors.darkNav.withValues(alpha: 0.3)
                  : const Color(0xFFE7E0D8).withValues(alpha: 0.5),
              width: 1.03.w,
            ),
          ),
        ),
        padding: hasDateRange
            ? EdgeInsets.symmetric(horizontal: 16.49.w, vertical: 10.31.h)
            : EdgeInsets.symmetric(horizontal: 16.49.w, vertical: 21.91.h),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment:
              hasDateRange ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: hasDateRange
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    AppAssets.dateRange,
                    width: isLandscape ? 16.49 : 16.49.w,
                    height: isLandscape ? 16.49 : 16.49.w,
                    colorFilter: iconColor != null
                        ? ColorFilter.mode(
                            iconColor,
                            BlendMode.srcIn,
                          )
                        : null,
                  ),
                  SizedBox(width: 8.25.w),
                  Expanded(
                    child: hasDateRange
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      AppLocalizations.of(context)
                                              ?.customDateRange ??
                                          'Custom Date Range',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12.37.sp,
                                        fontWeight: FontWeight.w500,
                                        height: 16 / 12.37,
                                        color: titleColor,
                                      ),
                                    ),
                                  ),
                                  if (isCustomRangeActive && !effectiveIsDisabled) ...[
                                    SizedBox(width: isLandscape ? 6 : 6.w),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isLandscape ? 6 : 6.w,
                                        vertical: 2,
                                      ),
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: AppColors.main,
                                        borderRadius:
                                            BorderRadius.circular(9999.r),
                                      ),
                                      child: Text(
                                        AppLocalizations.of(context)
                                                ?.activeStatus ??
                                            AppLocalizations.of(context)
                                                ?.active ??
                                            'Active',
                                        style: TextStyle(
                                          fontSize: 10.sp,
                                          fontWeight: FontWeight.w600,
                                          height: 12 / 10,
                                          color: AppColors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              SizedBox(height: 7.h),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _formatRange(
                                      selectedDateRange!.start,
                                      selectedDateRange!.end,
                                    ),
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w600,
                                      height: 14 / 12,
                                      color: dateRangeColor,
                                    ),
                                  ),
                                  SizedBox(height: 2.h),
                                  Text(
                                    daysText,
                                    style: TextStyle(
                                      fontSize: 10.sp,
                                      fontWeight: FontWeight.w400,
                                      height: 16 / 10,
                                      color: daysTextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          )
                        : Text(
                            AppLocalizations.of(context)?.customDateRange ??
                                'Custom Date Range',
                            style: TextStyle(
                              fontSize: 12.37.sp,
                              fontWeight: FontWeight.w500,
                              height: 16 / 12.37,
                              color: titleColor,
                            ),
                          ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: hasDateRange ? 2.h : 0),
              child: Icon(
                Icons.chevron_right_rounded,
                size: 14.43.sp,
                color: chevronColor,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
}
