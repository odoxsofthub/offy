import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';

class LogoutConfirmationDialog extends StatelessWidget {
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;

  const LogoutConfirmationDialog({
    super.key,
    this.onConfirm,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(horizontal: 30.w),
      child: Container(
        padding: EdgeInsets.all(32.r),
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
            // Top Circular Icon Badge
            Container(
              width: 64.w,
              height: 64.w,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF4A1A0D)
                    : const Color(0xFFFFDBD1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  Icons.logout_outlined,
                  size: 24.sp,
                  color: const Color(0xFFB02F00),
                ),
              ),
            ),
            SizedBox(height: 24.h),
            // Text Content Section
            Column(
              children: [
                Text(
                  AppLocalizations.of(context)?.confirmLogOut ?? 'Confirm Log Out',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w600,
                    height: 28 / 20,
                    letterSpacing: 0,
                    color: isDark ? AppColors.white : AppColors.black,
                  ),
                ),
                SizedBox(height: 10.75.h),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 23.w),
                  child: Text(
                    AppLocalizations.of(context)?.logOutDesc ?? 'Are you sure you want to log out? You will need to enter your credentials to access your account again.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w400,
                      height: 20 / 14,
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
            // Actions Section
            Column(
              children: [
                // Log Out Button (Primary)
                Container(
                  width: double.infinity,
                  height: 56.h,
                  decoration: BoxDecoration(
                    color: AppColors.main,
                    borderRadius: BorderRadius.circular(12.r),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.main.withValues(alpha: 0.25),
                        offset: const Offset(0, 8),
                        blurRadius: 15.r,
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onConfirm ?? () => Navigator.of(context).pop(true),
                      borderRadius: BorderRadius.circular(12.r),
                      splashColor: Colors.white.withValues(alpha: 0.2),
                      highlightColor: Colors.white.withValues(alpha: 0.1),
                      child: Center(
                        child: Text(
                          AppLocalizations.of(context)?.logout ?? 'Log Out',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w400,
                            height: 24 / 16,
                            letterSpacing: 0,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
                // Cancel Button (Secondary Outlined)
                Container(
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
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onCancel ?? () => Navigator.of(context).pop(false),
                      borderRadius: BorderRadius.circular(12.r),
                      splashColor: (isDark ? Colors.white : AppColors.main)
                          .withValues(alpha: 0.1),
                      highlightColor: (isDark ? Colors.white : AppColors.main)
                          .withValues(alpha: 0.05),
                      child: Center(
                        child: Text(
                          AppLocalizations.of(context)?.cancel ?? 'Cancel',
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
          ],
        ),
      ),
    );
  }
}
