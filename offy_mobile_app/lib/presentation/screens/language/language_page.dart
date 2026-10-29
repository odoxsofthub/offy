import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../widgets/common/custom_screen_header.dart';
import '../../widgets/language/language_item_tile.dart';
import '../../widgets/language/language_save_bottom_bar.dart';
import '../../viewmodels/language/language_provider.dart';

class LanguageOption {
  final String title;
  final String subtitle;
  final String code;

  const LanguageOption({
    required this.title,
    required this.subtitle,
    required this.code,
  });
}

class LanguagePage extends StatefulWidget {
  const LanguagePage({super.key});

  @override
  State<LanguagePage> createState() => _LanguagePageState();
}

class _LanguagePageState extends State<LanguagePage> {
  late String _selectedLanguageCode;

  static const List<LanguageOption> _languages = [
    LanguageOption(
      title: 'English (US)',
      subtitle: 'English US',
      code: 'en_US',
    ),
    LanguageOption(
      title: 'English (UK)',
      subtitle: 'English UK',
      code: 'en_GB',
    ),
    LanguageOption(title: 'Spanish', subtitle: 'Español', code: 'es'),
    LanguageOption(title: 'French', subtitle: 'Français', code: 'fr'),
    LanguageOption(title: 'German', subtitle: 'Deutsch', code: 'de'),
    LanguageOption(title: 'Chinese (Simplified)', subtitle: '简体中文', code: 'zh'),
    LanguageOption(
      title: 'Chinese (Traditional)',
      subtitle: '繁體中文',
      code: 'zh_TW',
    ),
    LanguageOption(title: 'Japanese', subtitle: '日本語', code: 'ja'),
    LanguageOption(title: 'Arabic', subtitle: 'العربية', code: 'ar'),
    LanguageOption(title: 'Hindi', subtitle: 'हिन्दी', code: 'hi'),
    LanguageOption(title: 'Portuguese', subtitle: 'Português', code: 'pt'),
    // Malayalam (ml) translations exist but are not offered in the picker yet.
  ];

  @override
  void initState() {
    super.initState();
    final locale = context.read<LanguageProvider>().currentLocale;
    _selectedLanguageCode = locale.countryCode != null
        ? '${locale.languageCode}_${locale.countryCode}'
        : locale.languageCode;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkTopCard : AppColors.midLight,
        body: Container(
          decoration: isDark
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
                title: AppLocalizations.of(context)?.language ?? 'Language',
                centerTitle: false,
                onBackTap: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: SafeArea(
                  top: false,
                  bottom: false,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 20.h),
                        ..._languages.map((lang) {
                          final isSelected = _selectedLanguageCode == lang.code;
                          return Padding(
                            padding: EdgeInsets.only(bottom: 8.h),
                            child: LanguageItemTile(
                              title: lang.title,
                              subtitle: lang.subtitle,
                              isSelected: isSelected,
                              onTap: () {
                                setState(() {
                                  _selectedLanguageCode = lang.code;
                                });
                              },
                            ),
                          );
                        }),
                        SizedBox(height: 20.h),
                      ],
                    ),
                  ),
                ),
              ),
              LanguageSaveBottomBar(
                onSave: () {
                  final languageProvider = context.read<LanguageProvider>();
                  final selectedLanguageCode = _selectedLanguageCode;
                  Navigator.of(context).pop();
                  languageProvider.changeLanguage(selectedLanguageCode);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
