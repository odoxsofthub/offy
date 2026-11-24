import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';

class FaqSupportCard extends StatelessWidget {
  final VoidCallback? onContactSupportTap;
  final bool isLoading;

  const FaqSupportCard({
    super.key,
    this.onContactSupportTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkCard
            : Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isDark ? AppColors.darkTertiary : const Color(0xFFF9FAFB),
          width: 1.w,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 42.33.w,
                  height: 48.w,
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkTopCard
                        : const Color(0xFFFFF7ED),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.headphones_outlined,
                      size: 24.sp,
                      color: AppColors.main,
                    ),
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        AppLocalizations.of(context)?.stillNeedHelp ??
                            'Still need help?',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                          height: 24 / 16,
                          letterSpacing: 0,
                          color: isDark
                              ? AppColors.white
                              : const Color(0xFF1A1A1A),
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        AppLocalizations.of(context)?.contactSupportDesc ??
                            "Contact our support team and we'll get back to you.",
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w400,
                          height: 12.5 / 10,
                          letterSpacing: 0,
                          color: isDark
                              ? AppColors.navColor
                              : const Color(0xFF666666),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 12.w),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isLoading ? null : onContactSupportTap,
              borderRadius: BorderRadius.circular(12.r),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 13.5.w,
                  vertical: 15.h,
                ),
                decoration: BoxDecoration(
                  color: AppColors.main,
                  borderRadius: BorderRadius.circular(12.r),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.main.withValues(alpha: 0.2),
                      offset: const Offset(0, 4),
                      blurRadius: 6.r,
                      spreadRadius: -1.r,
                    ),
                    BoxShadow(
                      color: AppColors.main.withValues(alpha: 0.2),
                      offset: const Offset(0, 2),
                      blurRadius: 4.r,
                      spreadRadius: -2.r,
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Opacity(
                      opacity: isLoading ? 0.0 : 1.0,
                      child: Text(
                        AppLocalizations.of(context)?.contactSupport ??
                            'Contact Support',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                          height: 16 / 12,
                          letterSpacing: 0,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (isLoading)
                      SizedBox(
                        width: 16.r,
                        height: 16.r,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
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
