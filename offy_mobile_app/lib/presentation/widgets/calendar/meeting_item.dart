import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_colors.dart';

class MeetingItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData? icon;
  final Color accentColor;
  final VoidCallback? onTap;

  const MeetingItem({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon,
    required this.accentColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12.r),
          boxShadow: [
            BoxShadow(
              color: const Color(0x0F2A2A2A),
              blurRadius: 20.r,
              offset: Offset(0, 4.h),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12.r),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.white,
              border: Border(
                left: BorderSide(color: accentColor, width: 4.w),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: subtitle.isNotEmpty
                          ? CrossAxisAlignment.start
                          : CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                            height: 24 / 16,
                            color: isDark ? AppColors.white : AppColors.black,
                          ),
                        ),
                        if (subtitle.isNotEmpty) ...[
                          SizedBox(height: 6.h),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (icon != null) ...[
                                Padding(
                                  padding: EdgeInsets.only(top: 2.h),
                                  child: Icon(
                                    icon,
                                    size: 16.r,
                                    color: const Color(0xFF909090),
                                  ),
                                ),
                                SizedBox(width: 6.w),
                              ],
                              Expanded(
                                child: Text(
                                  subtitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w400,
                                    height: 17 / 14,
                                    color: const Color(0xFF909090),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
