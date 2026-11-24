import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../common/custom_snackbar.dart';

class ProfileContactCardItem {
  final String label;
  final String value;
  final String? rawValue;
  final bool showCopy;
  final bool showConnect;
  final VoidCallback? onConnectTap;

  final int? maxLines;

  const ProfileContactCardItem({
    required this.label,
    required this.value,
    this.rawValue,
    this.showCopy = true,
    this.showConnect = false,
    this.onConnectTap,
    this.maxLines = 3,
  });
}

class ProfileContactCard extends StatelessWidget {
  final List<ProfileContactCardItem> items;

  const ProfileContactCard({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final validItems = items.where((item) {
      if (item.rawValue != null) {
        return item.rawValue!.trim().isNotEmpty;
      }
      return item.value.trim().isNotEmpty && item.value.trim() != 'N/A';
    }).toList();

    if (validItems.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.darkCard.withValues(alpha: 0.3)
              : AppColors.light.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(validItems.length, (index) {
            final item = validItems[index];
            final isFirst = index == 0;
            final isLast = index == validItems.length - 1;
            final bool shouldShowCopy = item.showCopy &&
                (item.rawValue != null ? item.rawValue!.trim().isNotEmpty : true) &&
                item.value.trim().isNotEmpty &&
                item.value.trim() != 'N/A';

            return Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 11.h),
              decoration: BoxDecoration(
                border: isFirst
                    ? null
                    : Border(
                        top: BorderSide(color: AppColors.shade, width: 0.6.w),
                      ),
                borderRadius: BorderRadius.only(
                  topLeft: isFirst ? Radius.circular(12.r) : Radius.zero,
                  topRight: isFirst ? Radius.circular(12.r) : Radius.zero,
                  bottomLeft: isLast ? Radius.circular(10.r) : Radius.zero,
                  bottomRight: isLast ? Radius.circular(10.r) : Radius.zero,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                            height: 18 / 12,
                            color: AppColors.navColor,
                          ),
                        ),
                        SizedBox(height: 1.h),
                        Text(
                          item.value,
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w500,
                            height: 18 / 16,
                            color: isDark ? AppColors.white : AppColors.black,
                          ),
                          maxLines: item.maxLines,
                          overflow: item.maxLines == null
                              ? TextOverflow.clip
                              : TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (shouldShowCopy) ...[
                    SizedBox(width: 15.w),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: item.value));
                        CustomSnackbar.show(
                          context,
                          message: '${item.label} copied to clipboard',
                        );
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: EdgeInsets.all(8.w),
                        child: Opacity(
                          opacity: 0.5,
                          child: SvgPicture.asset(
                            AppAssets.copy,
                            width: 20.w,
                            height: 20.w,
                            colorFilter: ColorFilter.mode(
                              AppColors.navColor,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (item.showConnect) ...[
                    SizedBox(width: 15.w),
                    GestureDetector(
                      onTap: item.onConnectTap,
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkTopCard : Colors.white,
                          borderRadius: BorderRadius.circular(100.r),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 4.r,
                              offset: Offset(0, 2.h),
                            ),
                          ],
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: 9.w,
                          vertical: 4.h,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              AppLocalizations.of(context)?.connect ?? 'Connect',
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w400,
                                color: AppColors.secondary,
                                height: 15 / 12,
                              ),
                            ),
                            SizedBox(width: 4.w),
                            SvgPicture.asset(
                              AppAssets.sms,
                              colorFilter: const ColorFilter.mode(
                                AppColors.secondary,
                                BlendMode.srcIn,
                              ),
                              width: 20.w,
                              height: 20.w,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}
