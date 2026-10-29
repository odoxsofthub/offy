import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_colors.dart';

class TimeOffLogOutgoingBubbleWidget extends StatelessWidget {
  final String message;
  final String timestamp;

  const TimeOffLogOutgoingBubbleWidget({
    super.key,
    required this.message,
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          padding: EdgeInsets.all(10.r),
          constraints: BoxConstraints(minWidth: 198.w, maxWidth: 275.w),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : const Color(0xFFF8F8F8),
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Text(
            message,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w400,
              height: 20 / 14,
              color: isDark ? AppColors.white : AppColors.black,
            ),
          ),
        ),
        SizedBox(height: 4.h),
        // Timestamp text below outgoing bubble
        Padding(
          padding: EdgeInsets.only(right: 10.w),
          child: Text(
            timestamp,
            textAlign: TextAlign.right,
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
