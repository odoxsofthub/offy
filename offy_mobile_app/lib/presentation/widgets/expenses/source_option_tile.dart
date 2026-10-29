import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_colors.dart';

class SourceOptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const SourceOptionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60.w,
            height: 60.w,
            decoration: BoxDecoration(
              color: isDark
                  ? const Color.fromRGBO(246, 243, 242, 0.1)
                  : AppColors.light,
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark
                    ? const Color.fromRGBO(209, 199, 176, 0.1)
                    : AppColors.shade.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Icon(icon, color: AppColors.secondary, size: 28.w),
          ),
          SizedBox(height: 8.h),
          Text(
            label,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
              color: isDark ? const Color(0xFFEAE1D8) : AppColors.tertiary,
            ),
          ),
        ],
      ),
    );
  }
}
