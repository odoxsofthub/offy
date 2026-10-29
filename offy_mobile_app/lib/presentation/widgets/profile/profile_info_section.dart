import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:office_app/core/theme/app_colors.dart';

class ProfileInfoSection extends StatelessWidget {
  final String name;
  final String? jobTitle;

  const ProfileInfoSection({
    super.key,
    required this.name,
    this.jobTitle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = jobTitle ?? '';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Name
        Text(
          name,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 22.sp,
            fontWeight: FontWeight.w700,
            height: 32 / 22,
            color: isDark ? AppColors.white : AppColors.black,
          ),
        ),
        // Job Title
        if (title.isNotEmpty)
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w400,
              height: 20 / 14,
              color: AppColors.grey,
            ),
          ),
      ],
    );
  }
}
