import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_colors.dart';

class DaysOfWeekHeader extends StatelessWidget {
  const DaysOfWeekHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final weekdays = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: weekdays.map((day) {
        final isWeekend = day == 'SA' || day == 'SU';
        final textColor = isWeekend
            ? const Color(0xFFB02F00)
            : AppColors.tertiary.withValues(alpha: 0.6);
        return Expanded(
          child: Center(
            child: Text(
              day,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                height: 17 / 12,
                letterSpacing: 0.63.sp,
                color: textColor,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
