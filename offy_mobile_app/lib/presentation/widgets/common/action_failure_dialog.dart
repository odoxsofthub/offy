import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';

class ActionFailureDialog extends StatelessWidget {
  final String? title;
  final String? errorMessage;

  const ActionFailureDialog({super.key, this.title, this.errorMessage});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final String displayMessage =
        (errorMessage != null && errorMessage!.isNotEmpty)
            ? errorMessage!
            : (AppLocalizations.of(context)?.actionFailureDefaultDesc ??
                'We encountered an unexpected error while processing your request. Please check your connection and try again.');

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Dialog(
        backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(horizontal: 30.w),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.5.w, vertical: 32.h),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Error Icon Section
            Stack(
              alignment: Alignment.center,
              children: [
                // Overlay + Blur Glow
                Container(
                  width: 80.w,
                  height: 80.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.main.withValues(alpha: 0.2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.main.withValues(alpha: 0.25),
                        blurRadius: 20.r,
                        spreadRadius: 10.r,
                      ),
                    ],
                  ),
                ),
                // Background Gradient Circle Badge
                Container(
                  width: 80.w,
                  height: 80.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFB02F00), Color(0xFFFD8863)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x1A000000),
                        offset: Offset(0, 20),
                        blurRadius: 25.r,
                        spreadRadius: -5.r,
                      ),
                      BoxShadow(
                        color: Color(0x1A000000),
                        offset: Offset(0, 8),
                        blurRadius: 10.r,
                        spreadRadius: -6.r,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: 40.w,
                      height: 40.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3.33.w),
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 24.sp,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 24.h),
            // Text Content Section
            Column(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 50.w),
                  child: Text(
                    title ??
                        (AppLocalizations.of(context)?.oopsSomethingWentWrong ??
                            'Oops! Something went wrong'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w600,
                      height: 30 / 24,
                      letterSpacing: -0.24,
                      color: isDark ? AppColors.white : AppColors.black,
                    ),
                  ),
                ),
                SizedBox(height: 8.h),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.w),
                  child: Text(
                    displayMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w300,
                      height: 22 / 16,
                      letterSpacing: 0,
                      color: isDark
                          ? AppColors.navColor
                          : const Color(0xFF5B4039),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 40.h),
            // Dismiss Action Button
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.of(context).pop(),
                borderRadius: BorderRadius.circular(12.r),
                child: Container(
                  width: double.infinity,
                  height: 56.h,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: isDark
                          ? AppColors.darkTertiary
                          : const Color(0xFFE4BEB4),
                      width: 1.w,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      AppLocalizations.of(context)?.dismiss ?? 'Dismiss',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w400,
                        height: 24 / 16,
                        letterSpacing: 0,
                        color: isDark
                            ? AppColors.white
                            : const Color(0xFF5B4039),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
}
