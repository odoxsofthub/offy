import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/notification_model.dart';
import '../../../l10n/app_localizations.dart';

class NotificationCard extends StatelessWidget {
  final NotificationItem item;
  final bool isNew;

  const NotificationCard({super.key, required this.item, required this.isNew});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color containerBgColor = isNew
        ? (isDark ? const Color(0x1AFFDBD0) : const Color(0x4DFFDBD0))
        : (isDark ? const Color(0x1AE9E2CF) : const Color(0x4DE9E2CF));

    final Color iconColor = isNew
        ? AppColors.secondary
        : const Color(0xFF625E50);

    final Color cardBgColor = isDark
        ? (isNew ? AppColors.darkCard : const Color(0x1AFFFFFF))
        : (isNew ? AppColors.white : const Color(0x33FFFFFF));

    final Color borderColor = isNew
        ? const Color(0x33E4BEB4)
        : const Color(0x1AE4BEB4);

    final Color titleColor = isDark
        ? (isNew ? AppColors.light : AppColors.midLight)
        : AppColors.black;

    final Color descriptionColor = isDark
        ? (isNew ? AppColors.midLight : const Color(0xFFD7B0A6))
        : AppColors.tertiary;

    final Color timeColor = isDark
        ? (isNew ? AppColors.midLight : AppColors.light)
        : AppColors.tertiary;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: borderColor, width: 1.w),
        boxShadow: isNew
            ? [
                BoxShadow(
                  color: const Color(0x0F2A2A2A),
                  blurRadius: 20.r,
                  offset: Offset(0, 4.h),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.r),
        child: Padding(
          padding: EdgeInsets.all(20.w),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48.w,
                height: 48.w,
                decoration: BoxDecoration(
                  color: containerBgColor,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: item.isMirroredIcon
                    ? Transform.scale(
                        scaleX: -1,
                        child: Icon(item.icon, color: iconColor, size: 20.w),
                      )
                    : Icon(item.icon, color: iconColor, size: 20.w),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                              height: 20 / 16,
                              color: titleColor,
                            ),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          AppDateFormatter.notificationTime(
                            item.date,
                            l10n: AppLocalizations.of(context),
                          ),
                          style: GoogleFonts.inter(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w500,
                            height: 18 / 13,
                            color: timeColor,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 2.75.h),
                    Text(
                      item.description,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w400,
                        height: 20 / 14,
                        color: descriptionColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
