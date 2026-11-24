import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';

enum PdfDownloadState { idle, loading, success, error }

class PayslipTabBarWidget extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback? onPdfDownloadTap;
  final bool isPdfReady;
  final PdfDownloadState downloadState;

  const PayslipTabBarWidget({
    super.key,
    required this.selectedIndex,
    required this.onTabSelected,
    this.onPdfDownloadTap,
    this.isPdfReady = false,
    this.downloadState = PdfDownloadState.idle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      height: 84.h,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.darkNav : AppColors.shade,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Frame 2609826: Preview & Log Tab Buttons Row
          Row(
            children: [
              // Frame 50: Preview Tab Button
              _buildTabButton(
                context: context,
                index: 0,
                label: AppLocalizations.of(context)?.preview ?? 'Preview',
                icon: null,
                isSelected: selectedIndex == 0,
                isDark: isDark,
              ),
              SizedBox(width: 8.w),
              // Frame 49: Log Tab Button
              _buildTabButton(
                context: context,
                index: 1,
                label: AppLocalizations.of(context)?.log ?? 'Log',
                icon: Icons.article_outlined,
                isSelected: selectedIndex == 1,
                isDark: isDark,
              ),
            ],
          ),

          // Frame 12: PDF Download Button — only visible on the Preview tab after PDF is loaded
          if (selectedIndex == 0 && isPdfReady)
            GestureDetector(
              onTap: onPdfDownloadTap,
              behavior: HitTestBehavior.opaque,
              child: Container(
                height: 48.h,
                padding: EdgeInsets.symmetric(horizontal: 12.w),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(78.r),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'PDF',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        height: 20 / 14,
                        color: AppColors.secondary,
                      ),
                    ),
                    SizedBox(width: 6.w),
                    SizedBox(
                      width: 20.r,
                      height: 20.r,
                      child: switch (downloadState) {
                        PdfDownloadState.loading => CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.secondary,
                          ),
                        PdfDownloadState.success => Icon(
                            Icons.check_rounded,
                            size: 20.r,
                            color: AppColors.secondary,
                          ),
                        PdfDownloadState.error => Icon(
                            Icons.close_rounded,
                            size: 20.r,
                            color: AppColors.red,
                          ),
                        PdfDownloadState.idle => SvgPicture.asset(
                            AppAssets.importIcon,
                            width: 20.r,
                            height: 20.r,
                            colorFilter: ColorFilter.mode(
                              AppColors.secondary,
                              BlendMode.srcIn,
                            ),
                          ),
                      },
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required BuildContext context,
    required int index,
    required String label,
    required IconData? icon,
    required bool isSelected,
    required bool isDark,
  }) {
    final activeBg = isDark ? AppColors.white : AppColors.black;
    final activeTextColor = isDark ? AppColors.black : AppColors.white;
    final inactiveBg = isDark ? AppColors.darkTopCard : const Color(0x4DCAC3C0);
    final inactiveTextColor = isDark ? AppColors.white : AppColors.black;

    return GestureDetector(
      onTap: () => onTabSelected(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 112.w,
        height: 48.h,
        decoration: BoxDecoration(
          color: isSelected ? activeBg : inactiveBg,
          borderRadius: BorderRadius.circular(78.r),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 15.r,
                color: isSelected ? activeTextColor : inactiveTextColor,
              ),
              SizedBox(width: 7.w),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                height: 20 / 14,
                color: isSelected ? activeTextColor : inactiveTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
