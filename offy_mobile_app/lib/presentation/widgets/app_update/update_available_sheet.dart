import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/services/app_update_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import 'update_parts.dart';

/// Normal (optional) update: a bottom sheet with "Update now" and "Maybe later".
class UpdateAvailableSheet extends StatelessWidget {
  const UpdateAvailableSheet({
    super.key,
    required this.info,
    required this.onUpdate,
  });

  final AppUpdateInfo info;
  final Future<bool> Function() onUpdate;

  static Future<void> show(
    BuildContext context, {
    required AppUpdateInfo info,
    required Future<bool> Function() onUpdate,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 560),
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => UpdateAvailableSheet(info: info, onUpdate: onUpdate),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxHeight = MediaQuery.of(context).size.height * 0.85;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.onboardingBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 12.h),
              Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkNav : AppColors.shade,
                  borderRadius: BorderRadius.circular(4.r),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(24.w, 12.h, 24.w, 8.h),
                  child: Column(
                    children: [
                      const UpdateIconBadge(size: 68),
                      SizedBox(height: 12.h),
                      Semantics(
                        header: true,
                        child: Text(
                          l10n?.updateAvailableTitle ?? 'A new version is ready',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24.sp,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                            color: isDark ? AppColors.white : AppColors.black,
                          ),
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        l10n?.updateAvailableMessage ??
                            'Update OFFY to get the latest features and fixes.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16.sp,
                          height: 1.5,
                          color: isDark
                              ? AppColors.light.withValues(alpha: 0.8)
                              : AppColors.onboardingText,
                        ),
                      ),
                      SizedBox(height: 14.h),
                      UpdateVersionChip(
                        label:
                            l10n?.updateNewVersion(info.latestVersion) ??
                            'Version ${info.latestVersion}',
                      ),
                      SizedBox(height: 20.h),
                      UpdateReleaseNotes(
                        title: l10n?.updateWhatsNew ?? "What's new",
                        notes: info.releaseNotes,
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(24.w, 8.h, 24.w, 8.h),
                child: Column(
                  children: [
                    UpdateNowButton(
                      label: l10n?.updateNow ?? 'Update now',
                      onPressed: () async {
                        final opened = await onUpdate();
                        if (opened && context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                    SizedBox(height: 4.h),
                    SizedBox(
                      width: double.infinity,
                      height: 48.h,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          foregroundColor: isDark
                              ? AppColors.light
                              : AppColors.tertiary,
                          shape: const StadiumBorder(),
                        ),
                        child: Text(
                          l10n?.updateLater ?? 'Maybe later',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
