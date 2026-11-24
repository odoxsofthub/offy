import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/constants/app_assets.dart';

class EmptyStateView extends StatelessWidget {
  final String imagePath;
  final String title;
  final String subtitle;
  final double? imageWidth;
  final double? imageHeight;
  final bool showActionButton;
  final VoidCallback? onActionButtonTap;
  final String? actionButtonText;
  final IconData? actionButtonIcon;

  const EmptyStateView({
    super.key,
    required this.imagePath,
    required this.title,
    required this.subtitle,
    this.imageWidth,
    this.imageHeight,
    this.showActionButton = false,
    this.onActionButtonTap,
    this.actionButtonText,
    this.actionButtonIcon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final resolvedWidth = imageWidth ??
        (imagePath == AppAssets.noNotifications
            ? 107.66.w
            : imagePath == AppAssets.noPayslips
                ? 164.0.w
                : imagePath == AppAssets.noAttendances
                    ? 173.0.w
                    : imagePath == AppAssets.noExpenses
                        ? 116.41.w
                        : imagePath == AppAssets.noNetwork
                            ? 132.10.w
                            : null);

    final resolvedHeight = imageHeight ??
        (imagePath == AppAssets.noNotifications
            ? 107.66.h
            : imagePath == AppAssets.noPayslips
                ? 164.0.h
                : imagePath == AppAssets.noAttendances
                    ? 173.0.h
                    : imagePath == AppAssets.noExpenses
                        ? 101.0.h
                        : imagePath == AppAssets.noNetwork
                            ? 120.0.h
                            : null);

    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // First widget: Container (180x180) containing the illustration
        Container(
          width: 180.w,
          height: 180.w,
          decoration: BoxDecoration(
            color: isDark ? const Color(0x337B5C38) : const Color(0XFFEAE1D8),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Image.asset(
              imagePath,
              width: resolvedWidth,
              height: resolvedHeight,
              fit: BoxFit.contain,
            ),
          ),
        ),
        // Gap of 60.h
        SizedBox(height: 60.h),
        // Second widget: Title and Subtitle Column (no vertical spacing between them)
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 28.sp,
                  height: 28 / 28,
                  color: isDark
                      ? const Color(0xFFFD5223)
                      : const Color(0xFF9F4122),
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w300,
                  fontSize: 18.sp,
                  height: 24 / 18,
                  color: isDark
                      ? const Color(0xFFF3E9E0)
                      : const Color(0xFF1B1C1C),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (showActionButton) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    Expanded(child: Center(child: content)),
                    SafeArea(
                      top: false,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16.w),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8.r),
                              onTap: onActionButtonTap,
                              child: Container(
                                padding: EdgeInsets.symmetric(vertical: 12.h),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8.r),
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFFF5722),
                                      Color(0xFFFF8A65),
                                    ],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0x40FF5722),
                                      offset: const Offset(0, 8),
                                      blurRadius: 15.r,
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Icon(
                                        actionButtonIcon ?? Icons.add,
                                        color: Colors.white,
                                        size: 15.92.w,
                                      ),
                                      SizedBox(width: 12.01.w),
                                      Text(
                                        actionButtonText ?? '',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w400,
                                          fontSize: 16.sp,
                                          height: 24 / 16,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 22.h),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    return Center(child: SafeArea(top: false, child: content));
  }
}
