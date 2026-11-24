import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/theme/app_colors.dart';

class SettingsRowItem extends StatelessWidget {
  final String iconAsset;
  final String label;
  final String? trailingLabel;
  final Widget? trailing;
  final bool isFirst;
  final bool isLast;
  final VoidCallback? onTap;

  const SettingsRowItem({
    super.key,
    required this.iconAsset,
    required this.label,
    this.trailingLabel,
    this.trailing,
    this.isFirst = false,
    this.isLast = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.only(
      topLeft: isFirst ? Radius.circular(16.r) : Radius.zero,
      topRight: isFirst ? Radius.circular(16.r) : Radius.zero,
      bottomLeft: isLast ? Radius.circular(16.r) : Radius.zero,
      bottomRight: isLast ? Radius.circular(16.r) : Radius.zero,
    );

    return Material(
      color: Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkCard
          : Colors.white,
      borderRadius: borderRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 20.h),
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            border: !isLast
                ? Border(
                    bottom: BorderSide(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFFCAC3C0).withValues(alpha: 0.2)
                          : AppColors.shade,
                      width: 0.6.h,
                    ),
                  )
                : null,
          ),
          child: Row(
            children: [
              SizedBox(width: 10.w),
              SvgPicture.asset(
                iconAsset,
                width: 24.w,
                height: 24.w,
                colorFilter: ColorFilter.mode(
                  Theme.of(context).brightness == Brightness.dark
                      ? AppColors.navColor
                      : AppColors.navColor,
                  BlendMode.srcIn,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.white
                        : AppColors.black,
                    height: 1.0,
                    letterSpacing: 0,
                  ),
                ),
              ),
            if (trailing != null)
              trailing!
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (trailingLabel != null && trailingLabel!.isNotEmpty) ...[
                    Text(
                      trailingLabel!,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF855D53).withValues(alpha: 0.9)
                            : AppColors.navColor,
                        height: 1.0,
                        letterSpacing: 0,
                      ),
                    ),
                    SizedBox(width: 10.w),
                  ],
                  Padding(
                    padding: EdgeInsets.only(right: 10.w),
                    child: Icon(
                      Icons.chevron_right,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF855D53).withValues(alpha: 0.9)
                          : const Color(0x665B4039),
                      size: 16.r,
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
