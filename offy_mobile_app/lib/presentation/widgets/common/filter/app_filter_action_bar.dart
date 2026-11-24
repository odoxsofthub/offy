import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';

/// Filter footer (Figma 2528:4175): light "Reset" pill and an orange primary pill.
/// Only the primary action ("Apply" / "Confirm Range") should call the API.
class AppFilterActionBar extends StatelessWidget {
  const AppFilterActionBar({
    super.key,
    required this.onReset,
    required this.onPrimary,
    this.primaryLabel,
    this.isBusy = false,
  });

  final VoidCallback onReset;
  final VoidCallback onPrimary;

  /// Defaults to "Apply".
  final String? primaryLabel;

  /// Disables both buttons and shows a spinner on the primary one.
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 24.h),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkTopCard : AppColors.white,
        border: Border(
          top: BorderSide(
            color: isDark
                ? AppColors.darkNav.withValues(alpha: 0.4)
                : AppColors.midLight,
            width: 1.w,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: _Pill(
                label: l10n?.reset ?? 'Reset',
                onTap: isBusy ? null : onReset,
                background: isDark
                    ? AppColors.darkTertiary
                    : const Color(0xFFF9F6F0),
                foreground: isDark ? AppColors.white : Colors.black,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _Pill(
                label: primaryLabel ?? l10n?.apply ?? 'Apply',
                onTap: isBusy ? null : onPrimary,
                background: AppColors.main,
                foreground: AppColors.white,
                isBusy: isBusy,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.onTap,
    required this.background,
    required this.foreground,
    this.isBusy = false,
  });

  final String label;
  final VoidCallback? onTap;
  final Color background;
  final Color foreground;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(100.r);
    return Semantics(
      button: true,
      enabled: onTap != null,
      child: Material(
        color: background,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: 44.h),
            child: Center(
              child: isBusy
                  ? SizedBox.square(
                      dimension: 18.r,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: foreground,
                      ),
                    )
                  : Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15.sp,
                        height: 18 / 15,
                        color: foreground,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
