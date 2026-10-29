import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../viewmodels/home/home_navigation_provider.dart';
import '../common/custom_back_button.dart';
import '../../../../l10n/app_localizations.dart';


class ProfileErrorView extends StatelessWidget {
  final String? errorMessage;
  final VoidCallback onRetry;

  const ProfileErrorView({
    super.key,
    this.errorMessage,
    required this.onRetry,
  });

  void _handleBack(BuildContext context) {
    try {
      context.read<HomeNavigationProvider>().goBackToPreviousTab();
    } catch (_) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: Column(
        children: [
          // Top Back Navigation Row
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            child: Row(
              children: [
                CustomBackButton(
                  onTap: () => _handleBack(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 48.w,
                      color: const Color(0xFFFD5223),
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      errorMessage ?? AppLocalizations.of(context)?.failedToLoadProfileDetails ?? 'Failed to load profile details.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppColors.white : AppColors.black,
                      ),
                    ),
                    SizedBox(height: 20.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: onRetry,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.main,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              horizontal: 20.w,
                              vertical: 10.h,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                          ),
                          icon: Icon(Icons.refresh_rounded, size: 18.w),
                          label: Text(
                            AppLocalizations.of(context)?.retry ?? 'Retry',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        OutlinedButton(
                          onPressed: () => _handleBack(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isDark ? AppColors.white : AppColors.black,
                            side: BorderSide(
                              color: isDark
                                  ? AppColors.white.withValues(alpha: 0.3)
                                  : AppColors.black.withValues(alpha: 0.3),
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: 16.w,
                              vertical: 10.h,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                          ),
                          child: Text(
                            AppLocalizations.of(context)?.goBack ?? 'Go Back',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
