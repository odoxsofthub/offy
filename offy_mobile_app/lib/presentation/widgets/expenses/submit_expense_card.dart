import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_colors.dart';

class SubmitExpenseCard extends StatelessWidget {
  final VoidCallback onTap;
  const SubmitExpenseCard({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(10.w),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12.r),
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0x33000000)
              : AppColors.white,
          boxShadow: [
            BoxShadow(
              color: const Color(0x1A000000),
              blurRadius: 14.r,
              offset: Offset(0, 4.h),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: -133.h - 10.w,
              left: -154.w - 10.w,
              child: Transform.rotate(
                angle: -0.43 * 3.1415926535897932 / 180,
                child: ImageFiltered(
                  // Figma/CSS blur radius of 54px converts to sigma = radius / 2 in Flutter
                  imageFilter: ImageFilter.blur(sigmaX: 54 / 2, sigmaY: 54 / 2),
                  child: ClipOval(
                    child: Container(
                      width: 405.66513961171495.w,
                      height: 172.53593827459073.h,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFFFF9774).withValues(alpha: 0.53)
                          : const Color(0xFFFF9774).withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 17.h - 10.w,
              left: 155.w - 10.w,
              child: Transform.rotate(
                angle: -9.26 * 3.1415926535897932 / 180,
                child: ImageFiltered(
                  // Figma/CSS blur radius of 51px converts to sigma = radius / 2 in Flutter
                  imageFilter: ImageFilter.blur(sigmaX: 51 / 2, sigmaY: 51 / 2),
                  child: ClipOval(
                    child: Container(
                      width: 271.w,
                      height: 108.h,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFFF8D4AE).withValues(alpha: 0.6)
                          : const Color(0xFFF8D4AE).withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context)?.submitNewExpense ?? 'Submit New Expense',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w600,
                          height: 26 / 18,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : AppColors.black,
                          letterSpacing: 0,
                        ),
                      ),
                      SizedBox(height: 3.h),
                      Text(
                        AppLocalizations.of(context)?.submitExpenseDesc ?? 'Click to upload receipts and log your recent\nbusiness expenditures.',
                        style: TextStyle(
                          fontSize: 10.sp,
                          color: isDark ? Colors.white : AppColors.black,
                          fontWeight: FontWeight.w400,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 16.w),
                Container(
                  width: 48.w,
                  height: 48.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFF5722), Color(0xFFFD8863)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0x40FF5722),
                        blurRadius: 15.r,
                        offset: Offset(0, 8.h),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(Icons.add, color: Colors.white, size: 24.w),
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
