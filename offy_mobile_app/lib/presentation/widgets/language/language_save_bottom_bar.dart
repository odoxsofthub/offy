import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';

class LanguageSaveBottomBar extends StatelessWidget {
  final VoidCallback onSave;

  const LanguageSaveBottomBar({
    super.key,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      color: isDark ? AppColors.darkCard : AppColors.midLight,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 16.h),
          child: InkWell(
            onTap: onSave,
            borderRadius: BorderRadius.circular(8.r),
            child: Container(
              width: double.infinity,
              height: 56.h,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xFFFF5722),
                    Color(0xFFFF8A65),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF5722).withValues(alpha: 0.25),
                    offset: const Offset(0, 8),
                    blurRadius: 15.r,
                  ),
                ],
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Center(
                child: Text(
                  AppLocalizations.of(context)?.saveChanges ?? 'Save Changes',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
