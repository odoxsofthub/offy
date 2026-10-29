import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/services/app_update_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import 'update_parts.dart';

/// Full-screen force update, drawn above the Navigator so nothing can get past it.
class ForceUpdateScreen extends StatefulWidget {
  const ForceUpdateScreen({super.key, required this.info});

  final AppUpdateInfo info;

  @override
  State<ForceUpdateScreen> createState() => _ForceUpdateScreenState();
}

class _ForceUpdateScreenState extends State<ForceUpdateScreen> {
  bool _opening = false;
  bool _openFailed = false;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _update() async {
    setState(() {
      _opening = true;
      _openFailed = false;
    });
    final opened = await AppUpdateService.instance.openStore(widget.info.storeUrl);
    if (!mounted) return;
    setState(() {
      _opening = false;
      _openFailed = !opened;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final info = widget.info;
    final titleColor = isDark ? AppColors.white : AppColors.black;
    final bodyColor = isDark
        ? AppColors.light.withValues(alpha: 0.8)
        : AppColors.onboardingText;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBg : AppColors.white,
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: isDark
                ? null
                : const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppColors.light, AppColors.white],
                    stops: [0.45, 1.0],
                  ),
          ),
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                // Readable column on tablets; full width on phones.
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.w),
                  child: Column(
                    children: [
                      SizedBox(height: 16.h),
                      SvgPicture.asset(
                        AppAssets.offyLogo,
                        height: 22.h,
                        semanticsLabel: 'OFFY',
                        colorFilter: isDark
                            ? const ColorFilter.mode(
                                AppColors.white,
                                BlendMode.srcIn,
                              )
                            : null,
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.symmetric(vertical: 24.h),
                          child: Column(
                            children: [
                              const UpdateIconBadge(),
                              SizedBox(height: 20.h),
                              Semantics(
                                header: true,
                                child: Text(
                                  l10n?.updateRequiredTitle ?? 'Time to update',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 28.sp,
                                    fontWeight: FontWeight.w700,
                                    height: 1.2,
                                    color: titleColor,
                                  ),
                                ),
                              ),
                              SizedBox(height: 10.h),
                              Text(
                                l10n?.updateRequiredMessage ??
                                    'This version of OFFY is no longer supported. '
                                        'Update to keep using the app.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  height: 1.5,
                                  color: bodyColor,
                                ),
                              ),
                              SizedBox(height: 16.h),
                              UpdateVersionChip(
                                label:
                                    l10n?.updateNewVersion(info.latestVersion) ??
                                    'Version ${info.latestVersion}',
                              ),
                              SizedBox(height: 24.h),
                              UpdateReleaseNotes(
                                title: l10n?.updateWhatsNew ?? "What's new",
                                notes: info.releaseNotes,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_openFailed)
                        Padding(
                          padding: EdgeInsets.only(bottom: 12.h),
                          child: Text(
                            l10n?.updateOpenStoreFailed ??
                                "Couldn't open the store. Please update OFFY "
                                    'from the App Store or Play Store.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14.sp,
                              height: 1.4,
                              color: AppColors.red,
                            ),
                          ),
                        ),
                      UpdateNowButton(
                        label: l10n?.updateNow ?? 'Update now',
                        isLoading: _opening,
                        onPressed: _update,
                      ),
                      SizedBox(height: 12.h),
                      Text(
                        l10n?.updateInstalledVersion(info.installedVersion) ??
                            'You have version ${info.installedVersion}',
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: isDark ? AppColors.navColor : AppColors.grey,
                        ),
                      ),
                      SizedBox(height: 16.h),
                    ],
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
