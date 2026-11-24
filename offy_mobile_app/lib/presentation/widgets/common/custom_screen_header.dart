import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_colors.dart';
import 'custom_back_button.dart';

class CustomScreenHeader extends StatelessWidget {
  final bool isSubmitting;
  final VoidCallback? onBackTap;
  final String? title;
  final Widget? titleWidget;
  final Widget? trailing;
  final bool centerTitle;
  final Widget? bottom;
  final bool hasBottomRadius;

  const CustomScreenHeader({
    super.key,
    this.isSubmitting = false,
    this.onBackTap,
    this.title,
    this.titleWidget,
    this.trailing,
    this.centerTitle = true,
    this.bottom,
    this.hasBottomRadius = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: hasBottomRadius
            ? BorderRadius.only(
                bottomLeft: Radius.circular(20.r),
                bottomRight: Radius.circular(20.r),
              )
            : BorderRadius.zero,
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkTopCard
            : AppColors.midLight,
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                16.w,
                8.h,
                16.w,
                bottom != null ? 10.h : 12.73.h,
              ),
              child: Row(
                children: [
                  CustomBackButton(onTap: isSubmitting ? null : onBackTap),
                  SizedBox(width: 12.w),
                  Expanded(
                    child:
                        titleWidget ??
                        (centerTitle
                            ? Center(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    right: trailing != null ? 0 : 41.27.w,
                                  ),
                                  child: Text(
                                    title ?? 'Expenses',
                                    style: TextStyle(
                                      fontSize: 22.sp,
                                      fontWeight: FontWeight.w600,
                                      height: 20 / 22,
                                      letterSpacing: 0,
                                      color:
                                          Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? AppColors.white
                                          : AppColors.black,
                                    ),
                                  ),
                                ),
                              )
                            : Text(
                                title ?? 'Expenses',
                                style: TextStyle(
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.w600,
                                  height: 28 / 18,
                                  letterSpacing: 0,
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? AppColors.white
                                      : AppColors.black,
                                ),
                              )),
                  ),
                  if (trailing != null) ...[SizedBox(width: 8.w), trailing!],
                ],
              ),
            ),
            ?bottom,
          ],
        ),
      ),
    );
  }
}
