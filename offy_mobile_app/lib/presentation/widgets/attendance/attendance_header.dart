import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';

class AttendanceHeader extends StatelessWidget {
  const AttendanceHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20.r),
          bottomRight: Radius.circular(20.r),
        ),
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkTopCard
            : AppColors.midLight,
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h),
          child: Center(
            child: Text(
              AppLocalizations.of(context)?.attendance ?? 'Attendance',
              style: TextStyle(
                fontSize: 22.sp,
                fontWeight: FontWeight.w600,
                height: 20 / 22,
                letterSpacing: 0,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.midLight
                    : AppColors.black,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
