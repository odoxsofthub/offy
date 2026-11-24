import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:office_app/core/constants/app_assets.dart';
import 'package:office_app/data/models/profile_response_model.dart';
import 'package:provider/provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/settings/settings_profile_card.dart';

import '../../../core/theme/app_colors.dart';
import '../../viewmodels/profile/profile_provider.dart';
import '../../widgets/common/custom_screen_header.dart';
import '../../widgets/settings/settings_group.dart';
import '../../widgets/settings/settings_row_item.dart';
import '../../widgets/settings/logout_confirmation_dialog.dart';
import '../../../core/navigation/app_router.dart';
import '../../../injection_container.dart' as di;
import '../../viewmodels/theme/theme_provider.dart';
import '../../viewmodels/language/language_provider.dart';
import '../../../core/services/session_manager.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ProfileProvider>().setExpanded(false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<ProfileProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final isDarkMode = themeProvider.isDarkMode;
    final profile = profileProvider.profileData ?? ProfileModel.empty();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    final currentLocale = context.watch<LanguageProvider>().currentLocale;
    final selectedLanguageName = _getLanguageName(currentLocale);

    final bool showFaq = profile.showFaq;
    final bool showTerms = profile.showTermsConditions;
    final bool showPrivacy = profile.showPrivacyPolicy;


    final group2ItemsData = <_PolicyRowData>[
      if (showFaq)
        _PolicyRowData(
          iconAsset: AppAssets.listMenu,
          label: loc?.faq ?? 'FAQ',
          onTap: () {
            Navigator.pushNamed(context, AppRouter.faq);
          },
        ),
      if (showTerms)
        _PolicyRowData(
          iconAsset: AppAssets.terms,
          label: loc?.termsOfService ?? 'Terms of service',
          onTap: () {
            Navigator.pushNamed(context, AppRouter.termsConditions);
          },
        ),
      if (showPrivacy)
        _PolicyRowData(
          iconAsset: AppAssets.userPolicy,
          label: loc?.userPolicy ?? 'User policy',
          onTap: () {
            Navigator.pushNamed(context, AppRouter.userPolicy);
          },
        ),
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: isDark ? AppColors.darkBg : Colors.white,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkTopCard
            : AppColors.midLight,
        body: Container(
          decoration: Theme.of(context).brightness == Brightness.dark
              ? const BoxDecoration(color: AppColors.darkBg)
              : const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFF3E9E0), Colors.white],
                    stops: [0.5375, 1.0],
                  ),
                ),
          child: Column(
            children: [
              CustomScreenHeader(
                isSubmitting: false,
                title: loc?.settings ?? 'Settings',
                centerTitle: false,
                onBackTap: () {
                  Navigator.pop(context);
                },
              ),
              Expanded(
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 23.h),

                        // 1. User Profile summary card
                        SettingsProfileCard(
                          profileProvider: profileProvider,
                          profile: profile,
                        ),
                        SizedBox(height: 24.h),

                        // 3. Settings Group 1 (Dark Mode + Language)
                        SettingsGroup(
                          items: [
                            SettingsRowItem(
                              iconAsset: AppAssets.darkMode,
                              label: loc?.darkMode ?? 'Dark mode',
                              isFirst: true,
                              onTap: () {
                                context.read<ThemeProvider>().toggleTheme();
                              },
                              trailing: Switch(
                                value: isDarkMode,
                                onChanged: (val) {
                                  context.read<ThemeProvider>().toggleTheme();
                                },
                                activeThumbColor: Colors.white,
                                activeTrackColor: AppColors.main,
                                inactiveThumbColor: const Color(0xFFE4E2E1),
                                inactiveTrackColor: Colors.white,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                trackOutlineColor:
                                    WidgetStateProperty.resolveWith<Color?>(
                                      (states) =>
                                          states.contains(WidgetState.selected)
                                          ? Colors.transparent
                                          : const Color(0x4DE4BEB4),
                                    ),
                              ),
                            ),
                            SettingsRowItem(
                              iconAsset: AppAssets.language,
                              label: loc?.language ?? 'Language',
                              trailingLabel: selectedLanguageName,
                              isLast: true,
                              onTap: () {
                                Navigator.pushNamed(
                                  context,
                                  AppRouter.language,
                                );
                              },
                            ),
                          ],
                        ),
                        SizedBox(height: 22.h),

                        // 3. Settings Group 2 (FAQ + Terms + Policy dynamically filtered)
                        if (group2ItemsData.isNotEmpty) ...[
                          SettingsGroup(
                            items: List.generate(group2ItemsData.length, (
                              index,
                            ) {
                              final item = group2ItemsData[index];
                              return SettingsRowItem(
                                iconAsset: item.iconAsset,
                                label: item.label,
                                isFirst: index == 0,
                                isLast: index == group2ItemsData.length - 1,
                                onTap: item.onTap,
                              );
                            }),
                          ),
                          SizedBox(height: 42.h),
                        ],

                        // 4. Logout Button
                        InkWell(
                          onTap: () async {

                            final bool? confirmed = await showDialog<bool>(
                              context: context,
                              builder: (_) => const LogoutConfirmationDialog(),
                            );

                            if (confirmed != true) return;

                            unawaited(di.sl<SessionManager>().logout());
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              vertical: 15.h,
                              horizontal: 10.w,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFE8E8),
                              borderRadius: BorderRadius.circular(12.r),
                              border: Border.all(
                                color: const Color(0xFFFD5223),
                                width: 0.6.w,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0x12000000),
                                  offset: Offset(5.w, 0),
                                  blurRadius: 8.r,
                                  spreadRadius: 0,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 15.w,
                                  height: 15.w,
                                  child: const FittedBox(
                                    fit: BoxFit.fill,
                                    child: Icon(
                                      Icons.logout_outlined,
                                      color: Color(0xFFEC0B0B),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 10.w),
                                Text(
                                  loc?.logout ?? 'Logout',
                                  style: TextStyle(
                                    color: const Color(0xFFEC0B0B),
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w500,
                                    height: 1.0,
                                    letterSpacing: 0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 50.h),
                      ],
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


  String _getLanguageName(Locale locale) {
    final code = locale.countryCode != null && locale.countryCode!.isNotEmpty
        ? '${locale.languageCode}_${locale.countryCode}'
        : locale.languageCode;

    switch (code) {
      case 'en_US':
        return 'English (US)';
      case 'en_GB':
        return 'English (UK)';
      case 'es':
        return 'Spanish';
      case 'fr':
        return 'French';
      case 'de':
        return 'German';
      case 'zh':
        return 'Chinese (Simplified)';
      case 'zh_TW':
        return 'Chinese (Traditional)';
      case 'ja':
        return 'Japanese';
      case 'ar':
        return 'Arabic';
      case 'hi':
        return 'Hindi';
      case 'pt':
        return 'Portuguese';
      default:
        return 'English (US)';
    }
  }
}

class _PolicyRowData {
  final String iconAsset;
  final String label;
  final VoidCallback? onTap;

  const _PolicyRowData({
    required this.iconAsset,
    required this.label,
    this.onTap,
  });
}
