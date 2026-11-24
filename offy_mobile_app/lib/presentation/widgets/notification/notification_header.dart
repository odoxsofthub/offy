import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../common/custom_back_button.dart';

class NotificationHeader extends StatelessWidget {
  const NotificationHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20.r),
          bottomRight: Radius.circular(20.r),
        ),
        color: isDark ? AppColors.darkTopCard : AppColors.midLight,
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 12.73.h),
          child: Row(
            children: [
              CustomBackButton(
                onTap: () => Navigator.pop(context),
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: 41.27.w,
                    ), // Balance back button spacing
                    child: Text(
                      AppLocalizations.of(context)?.notification ??
                          'Notification',
                      style: TextStyle(
                        fontSize: 22.sp,
                        fontWeight: FontWeight.w600,
                        height: 20 / 22,
                        letterSpacing: 0,
                        color: isDark ? AppColors.white : AppColors.black,
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
