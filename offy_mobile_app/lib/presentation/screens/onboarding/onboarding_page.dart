import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/navigation/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../viewmodels/onboarding/onboarding_provider.dart';
import '../../widgets/common/custom_back_button.dart';
import '../../widgets/common/frame_metrics.dart';
import '../../widgets/onboarding/onboarding_button.dart';
import '../../widgets/onboarding/onboarding_progress_indicator.dart';
import '../../widgets/onboarding/onboarding_slide_view.dart';

/// First-launch introduction, shown once before login. Always light (no dark Figma
/// variant); sized via [FrameMetrics], not ScreenUtil.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  static const Duration _pageDuration = Duration(milliseconds: 300);

  /// Beyond this the fixed text card and button would squeeze out the
  /// illustration on short phones.
  static const double _maxTextScale = 1.3;

  final PageController _pageController = PageController();

  /// Stops a double tap on the last slide from pushing the page twice.
  bool _isOpeningConnect = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<OnboardingSlideData> _buildSlides(AppLocalizations? l10n) {
    final next = l10n?.next ?? 'Next';
    return [
      OnboardingSlideData(
        image: AppAssets.onboardingWelcome,
        illustrationWidth: 429,
        header: const _WelcomeHeader(),
        title: l10n?.onboardingWelcomeTitle ?? 'Your workday',
        highlight: l10n?.onboardingWelcomeHighlight ?? 'all in one place',
        description:
            l10n?.onboardingWelcomeDescription ??
            'Manage attendance, time off, expenses, payslips and more.',
        buttonLabel: l10n?.getStarted ?? 'Get started',
      ),
      OnboardingSlideData(
        image: AppAssets.onboardingCheckIn,
        illustrationWidth: 414,
        title: l10n?.onboardingCheckInTitle ?? 'Check in',
        highlight: l10n?.onboardingCheckInHighlight ?? 'in seconds',
        description:
            l10n?.onboardingCheckInDescription ??
            'Mark your attendance from the office or on the go, and keep '
                'work hours up to date.',
        buttonLabel: next,
      ),
      OnboardingSlideData(
        image: AppAssets.onboardingTimeOff,
        illustrationWidth: 430,
        title: l10n?.onboardingTimeOffTitle ?? 'Plan your',
        highlight: l10n?.onboardingTimeOffHighlight ?? 'time off easily',
        description:
            l10n?.onboardingTimeOffDescription ??
            'View your leave balance, apply for time off, and track '
                'approvals.',
        buttonLabel: next,
      ),
      OnboardingSlideData(
        image: AppAssets.onboardingExpenses,
        illustrationWidth: 409,
        title: l10n?.onboardingExpensesTitle ?? 'Track expenses',
        highlight: l10n?.onboardingExpensesHighlight ?? 'with clarity',
        description:
            l10n?.onboardingExpensesDescription ??
            'Capture receipts, submit expenses and track approvals.',
        buttonLabel: next,
      ),
    ];
  }

  Future<void> _onPrimaryPressed(int slideCount) async {
    final provider = context.read<OnboardingProvider>();
    if (provider.currentIndex < slideCount - 1) {
      await _pageController.nextPage(
        duration: _pageDuration,
        curve: Curves.easeOut,
      );
      return;
    }
    // Onboarding is marked complete on the connect page, not here.
    if (_isOpeningConnect) return;
    _isOpeningConnect = true;
    await Navigator.pushNamed(context, AppRouter.onboardingConnect);
    _isOpeningConnect = false;
  }

  void _goToPreviousSlide() {
    _pageController.previousPage(
      duration: _pageDuration,
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final slides = _buildSlides(l10n);
    final m = FrameMetrics.of(context);
    final bottomInset = math.max(
      MediaQuery.viewPaddingOf(context).bottom,
      m(16),
    );

    return Theme(
      data: AppTheme.lightTheme,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: AppColors.white,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        child: Consumer<OnboardingProvider>(
          builder: (context, provider, _) {
            final index = provider.currentIndex;
            return PopScope(
              // System back steps through the slides before leaving the app.
              canPop: index == 0,
              onPopInvokedWithResult: (didPop, _) {
                if (!didPop) _goToPreviousSlide();
              },
              child: Scaffold(
                backgroundColor: AppColors.onboardingBg,
                body: MediaQuery.withClampedTextScaling(
                  maxScaleFactor: _maxTextScale,
                  child: Column(
                    children: [
                      SafeArea(
                        bottom: false,
                        child: _OnboardingTopBar(
                          stepCount: slides.length,
                          currentIndex: index,
                          onBack: _goToPreviousSlide,
                        ),
                      ),
                      Expanded(
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: slides.length,
                          onPageChanged: provider.setCurrentIndex,
                          itemBuilder: (_, i) =>
                              OnboardingSlideView(slide: slides[i]),
                        ),
                      ),
                      ColoredBox(
                        color: AppColors.white,
                        child: Center(
                          heightFactor: 1,
                          child: SizedBox(
                            width: m.contentWidth,
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                m(28),
                                m(30),
                                m(28),
                                bottomInset + m(17),
                              ),
                              child: OnboardingButton(
                                label: slides[index].buttonLabel,
                                onPressed: () =>
                                    _onPrimaryPressed(slides.length),
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
          },
        ),
      ),
    );
  }
}

/// Back button (from slide 2) + step bar, animating between the Figma offsets.
class _OnboardingTopBar extends StatelessWidget {
  const _OnboardingTopBar({
    required this.stepCount,
    required this.currentIndex,
    required this.onBack,
  });

  final int stepCount;
  final int currentIndex;
  final VoidCallback onBack;

  static const Duration _duration = Duration(milliseconds: 250);

  @override
  Widget build(BuildContext context) {
    final m = FrameMetrics.of(context);
    final showBack = currentIndex > 0;
    final backSize = m(41);
    return Center(
      heightFactor: 1,
      child: SizedBox(
        width: m.contentWidth,
        height: backSize,
        child: Padding(
          padding: EdgeInsets.fromLTRB(m(15), 0, m(36), 0),
          child: Row(
            children: [
              AnimatedContainer(
                duration: _duration,
                curve: Curves.easeOut,
                width: showBack ? m(69) : m(25),
                alignment: Alignment.centerLeft,
                child: OverflowBox(
                  alignment: Alignment.centerLeft,
                  minWidth: 0,
                  maxWidth: backSize,
                  child: AnimatedOpacity(
                    duration: _duration,
                    opacity: showBack ? 1 : 0,
                    child: IgnorePointer(
                      ignoring: !showBack,
                      child: ExcludeSemantics(
                        excluding: !showBack,
                        child: Semantics(
                          button: true,
                          label: MaterialLocalizations.of(
                            context,
                          ).backButtonTooltip,
                          child: CustomBackButton(
                            onTap: onBack,
                            size: backSize,
                            iconSize: m(24),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: OnboardingProgressIndicator(
                  stepCount: stepCount,
                  currentIndex: currentIndex,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '${l10n?.onboardingWelcomeTo ?? 'Welcome to'} '),
          TextSpan(
            text: l10n?.onboardingBrandName ?? 'OFFY!',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.secondary,
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: FrameMetrics.of(context)(20),
        fontWeight: FontWeight.w400,
        height: 1,
        color: AppColors.onboardingText,
      ),
    );
  }
}
