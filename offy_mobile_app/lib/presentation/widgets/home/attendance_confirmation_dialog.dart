import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';

class AttendanceConfirmationDialog extends StatelessWidget {
  final bool isCheckOut;

  const AttendanceConfirmationDialog({super.key, required this.isCheckOut});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(horizontal: 30.w),
      child: Container(
        constraints: BoxConstraints(maxWidth: 342.w),
        padding: EdgeInsets.all(32.r),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : const Color(0xFFF5EFE5),
          borderRadius: BorderRadius.circular(32.r),
          border: Border.all(
            color: isDark
                ? AppColors.darkTertiary
                : Colors.white.withValues(alpha: 0.5),
            width: 1.w,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0x1F000000),
              offset: const Offset(0, 8),
              blurRadius: 40.r,
            ),
          ],
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Image Illustration
              Image.asset(
                isCheckOut ? AppAssets.checkOutDialog : AppAssets.checkInDialog,
                width: 156.5.w,
                height: 161.3.h,
                fit: BoxFit.contain,
              ),
              SizedBox(height: 25.h),
              // Text Content Section
              Column(
                children: [
                  Text(
                    isCheckOut
                        ? (loc?.checkOutNow ?? 'Check Out Now')
                        : (loc?.checkInNow ?? 'Check In Now'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w600,
                      height: 30 / 24,
                      letterSpacing: -0.24,
                      color: isDark ? AppColors.white : AppColors.black,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    isCheckOut
                        ? (loc?.checkOutConfirmSubtitle ??
                              'Are you ready to end your session?')
                        : (loc?.checkInConfirmSubtitle ??
                              'Confirm your arrival to start your session.'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w300,
                      height: 22 / 14,
                      color: isDark ? AppColors.navColor : AppColors.tertiary,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24.h),
              // Actions Section
              Column(
                children: [
                  // Confirm Action Button (Primary)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(true),
                      borderRadius: BorderRadius.circular(12.r),
                      child: Container(
                        width: double.infinity,
                        height: 56.h,
                        decoration: BoxDecoration(
                          color: isCheckOut ? AppColors.red : AppColors.main,
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Center(
                          child: Text(
                            isCheckOut
                                ? (loc?.checkOutBtn ?? 'Check Out')
                                : (loc?.checkInBtn ?? 'Check In'),
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w400,
                              height: 24 / 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  // Secondary Button (Dismiss / Keep Working)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(false),
                      borderRadius: BorderRadius.circular(12.r),
                      child: Container(
                        width: double.infinity,
                        height: 56.h,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(
                            color: isDark
                                ? AppColors.darkNav
                                : AppColors.navColor,
                            width: 1.w,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            isCheckOut
                                ? (loc?.keepWorking ?? 'Keep Working')
                                : (loc?.dismiss ?? 'Dismiss'),
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w400,
                              height: 24 / 16,
                              color: isDark
                                  ? AppColors.white
                                  : AppColors.tertiary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
