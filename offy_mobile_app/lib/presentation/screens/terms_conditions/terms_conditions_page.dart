import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../viewmodels/terms_conditions/terms_conditions_provider.dart';
import '../../widgets/common/app_html_content_viewer.dart';
import '../../widgets/common/custom_screen_header.dart';

class TermsConditionsPage extends StatefulWidget {
  const TermsConditionsPage({super.key});

  @override
  State<TermsConditionsPage> createState() => _TermsConditionsPageState();
}

class _TermsConditionsPageState extends State<TermsConditionsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<TermsConditionsProvider>().fetchTermsConditions();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<TermsConditionsProvider>();

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
        backgroundColor: isDark ? AppColors.darkBg : AppColors.white,
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              CustomScreenHeader(
                title: AppLocalizations.of(context)?.termsOfService ??
                    'Terms of service',
                onBackTap: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: _buildBody(context, provider, isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    TermsConditionsProvider provider,
    bool isDark,
  ) {
    if (provider.isLoading) {
      return _buildShimmer(isDark);
    }

    if (provider.error != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                provider.error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: isDark ? AppColors.white : AppColors.black,
                ),
              ),
              SizedBox(height: 16.h),
              ElevatedButton(
                onPressed: () {
                  context
                      .read<TermsConditionsProvider>()
                      .fetchTermsConditions();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.main,
                  foregroundColor: Colors.white,
                ),
                child: Text(AppLocalizations.of(context)?.retry ?? 'Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final terms = provider.termsConditions;
    final htmlContent = terms?.content ?? '';

    if (htmlContent.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppLocalizations.of(context)?.noTermsAvailable ??
                    'No Terms available',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28.sp,
                  fontWeight: FontWeight.w700,
                  height: 28 / 28,
                  color: AppColors.secondary,
                ),
              ),
              SizedBox(height: 12.h),
              Text(
                AppLocalizations.of(context)?.noTermsAvailableSubtitle ??
                    'No terms of service content is available at the moment.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w300,
                  height: 24 / 18,
                  color: isDark ? AppColors.white : AppColors.black,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
      child: AppHtmlContentViewer(
        htmlContent: htmlContent,
      ),
    );
  }

  Widget _buildShimmer(bool isDark) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
      child: Shimmer.fromColors(
        baseColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE0E0E0),
        highlightColor:
            isDark ? const Color(0xFF3A3A3C) : const Color(0xFFF5F5F5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(6, (index) {
            return Padding(
              padding: EdgeInsets.only(bottom: 16.h),
              child: Container(
                width: index % 2 == 0 ? double.infinity : 220.w,
                height: 16.h,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4.r),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
