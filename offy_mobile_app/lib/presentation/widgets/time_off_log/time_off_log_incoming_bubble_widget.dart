import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_colors.dart';
import '../common/cached_image.dart';

class TimeOffLogIncomingBubbleWidget extends StatelessWidget {
  final String avatarUrl;
  final String userName;
  final String message;
  final String timestamp;

  const TimeOffLogIncomingBubbleWidget({
    super.key,
    required this.avatarUrl,
    required this.userName,
    required this.message,
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Frame 2609818 - Incoming Speech Bubble
        Container(
          constraints: BoxConstraints(minWidth: 198.w, maxWidth: 275.w),
          padding: EdgeInsets.all(10.r),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkTertiary : const Color(0xFFF6FFE2),
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipOval(
                    child: CachedImage(
                      imageUrl: avatarUrl,
                      userName: userName,
                      isProfile: true,
                      width: 20.r,
                      height: 20.r,
                      fit: BoxFit.cover,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Text(
                    userName,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      height: 20 / 14,
                      color: AppColors.secondary,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              Text(
                message,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w400,
                  height: 20 / 14,
                  color: isDark ? AppColors.white : AppColors.black,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 4.h),
        // Timestamp text below incoming bubble (left: 26px / top: 571px in Figma)
        Padding(
          padding: EdgeInsets.only(left: 10.w),
          child: Text(
            timestamp,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w400,
              height: 20 / 12,
              color: AppColors.darkNav,
            ),
          ),
        ),
      ],
    );
  }
}
