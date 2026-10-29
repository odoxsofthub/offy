import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_links.dart';
import '../../../core/navigation/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../viewmodels/onboarding/onboarding_provider.dart';
import '../../widgets/common/frame_metrics.dart';
import '../../widgets/onboarding/onboarding_button.dart';
import '../../widgets/onboarding/onboarding_shrinkable_height.dart';

/// Last onboarding step (Figma 2795:3548): "Install now" opens [AppLinks.odooModuleInstall];
/// "Already installed" finishes onboarding and opens login.
class OnboardingConnectPage extends StatelessWidget {
  const OnboardingConnectPage({super.key});

  /// Same cap as the slides.
  static const double _maxTextScale = 1.3;

  /// Smallest the ring gets before the page starts scrolling.
  static const double _minRingHeight = 120;

  /// Places the ring and text as in Figma: 124.8pt above them and 135pt
  /// below (plus the 24pt minimum gap) on the 402x874 frame.
  static const Alignment _contentAlignment = Alignment(0, -0.04);

  Future<void> _openInstallLink(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final message =
        AppLocalizations.of(context)?.onboardingInstallLinkError ??
        "Couldn't open the link. Please try again.";
    var launched = false;
    try {
      launched = await launchUrl(
        AppLinks.odooModuleInstall,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint('OnboardingConnectPage: Failed to open install link: $e');
    }
    if (!launched) {
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _finish(BuildContext context) async {
    final navigator = Navigator.of(context);
    await context.read<OnboardingProvider>().completeOnboarding();
    navigator.pushNamedAndRemoveUntil(AppRouter.login, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final m = FrameMetrics.of(context);
    final bottomInset = math.max(
      MediaQuery.viewPaddingOf(context).bottom,
      m(16),
    );
    final isCompleting = context.select<OnboardingProvider, bool>(
      (p) => p.isCompleting,
    );

    return Theme(
      data: AppTheme.lightTheme,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: AppColors.onboardingConnectBottom,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.onboardingConnectTop,
                AppColors.onboardingConnectBottom,
              ],
              stops: [0.487, 0.954],
            ),
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: MediaQuery.withClampedTextScaling(
              maxScaleFactor: _maxTextScale,
              child: Center(
                child: SizedBox(
                  width: m.contentWidth,
                  child: Column(
                    children: [
                      Expanded(
                        child: SafeArea(
                          bottom: false,
                          child: _buildScrollableContent(m, l10n),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          m(28),
                          0,
                          m(28),
                          bottomInset + m(24),
                        ),
                        child: Column(
                          children: [
                            OnboardingButton(
                              label:
                                  l10n?.onboardingInstallNow ?? 'Install now',
                              variant: OnboardingButtonVariant.light,
                              onPressed: () => _openInstallLink(context),
                            ),
                            SizedBox(height: m(12)),
                            OnboardingButton(
                              label:
                                  l10n?.onboardingAlreadyInstalled ??
                                  'Already installed',
                              variant: OnboardingButtonVariant.outline,
                              onPressed: isCompleting
                                  ? null
                                  : () => _finish(context),
                            ),
                          ],
                        ),
                      ),
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

  /// The ring gives way first on short windows; the page scrolls only when
  /// even [_minRingHeight] does not fit.
  Widget _buildScrollableContent(FrameMetrics m, AppLocalizations? l10n) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(
            child: Padding(
              padding: EdgeInsets.only(bottom: m(24)),
              child: Align(
                alignment: _contentAlignment,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: OnboardingShrinkableHeight(
                        minHeight: m(_minRingHeight),
                        child: SizedBox(
                          height: m(231.7),
                          child: Image.asset(
                            AppAssets.onboardingConnectOdoo,
                            fit: BoxFit.contain,
                            excludeFromSemantics: true,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: m(19.5)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: m(28)),
                      child: Column(
                        children: [
                          Semantics(
                            header: true,
                            child: Text(
                              l10n?.onboardingConnectTitle ??
                                  'Connect with Odoo',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: m(32),
                                fontWeight: FontWeight.w600,
                                height: 38 / 32,
                                color: AppColors.white,
                              ),
                            ),
                          ),
                          SizedBox(height: m(7)),
                          Text(
                            l10n?.onboardingConnectDescription ??
                                'Please install our Odoo module\n'
                                    'to get started.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: m(16),
                              fontWeight: FontWeight.w300,
                              height: 21 / 16,
                              color: AppColors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
