import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_colors.dart';
import '../common/cached_image.dart';

class TimeOffLogItemWidget extends StatelessWidget {
  final String avatarUrl;
  final String userName;
  final String timestamp;
  final String message;
  final bool isLast;

  const TimeOffLogItemWidget({
    super.key,
    required this.avatarUrl,
    required this.userName,
    required this.timestamp,
    required this.message,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.symmetric(vertical: 16.h),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                  color: isDark ? AppColors.darkNav : AppColors.navColor,
                  width: 0.5,
                ),
              ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10.r),
                child: CachedImage(
                  imageUrl: avatarUrl,
                  userName: userName,
                  isProfile: true,
                  width: 20.r,
                  height: 20.r,
                  fit: BoxFit.cover,
                ),
              ),
              SizedBox(width: 8.w),
              Text(
                userName,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  height: 20 / 12,
                  color: AppColors.secondary,
                ),
              ),
              SizedBox(width: 10.w),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.access_time_outlined,
                    size: 15.r,
                    color: AppColors.darkNav,
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    timestamp,
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      height: 20 / 12,
                      color: AppColors.darkNav,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 8.h),
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
    );
  }
}
