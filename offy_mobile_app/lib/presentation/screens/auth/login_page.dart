import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/auth/login_form.dart';
import '../../widgets/common/frame_metrics.dart';

/// Login (Figma frames 2840:5834 / 2840:5993): orange header + white sheet with [LoginForm].
/// Always light; sized via [FrameMetrics], y positions measured from the safe-area top.
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  /// Same cap as onboarding.
  static const double _maxTextScale = 1.3;

  /// Figma status bar height the frame positions include.
  static const double _figmaStatusBar = 62;

  @override
  Widget build(BuildContext context) {
    final m = FrameMetrics.of(context);
    final media = MediaQuery.of(context);
    final safeTop = media.viewPadding.top;
    final bottomInset = math.max(media.viewPadding.bottom, m(16));
    double figmaY(double y) => safeTop + m(y - _figmaStatusBar);
    // Centres the form in a [FrameMetrics.contentWidth] column on tablets.
    final sideInset = (media.size.width - m.contentWidth) / 2 + m(21);

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
        child: GestureDetector(
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.main, AppColors.loginHeaderBottom],
                stops: [0, 0.53],
              ),
            ),
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: MediaQuery.withClampedTextScaling(
                maxScaleFactor: _maxTextScale,
                child: CustomScrollView(
                  physics: const ClampingScrollPhysics(),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  slivers: [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Stack(
                        children: [
                          // Oversized "O" from the logo, 80% over the gradient.
                          Positioned(
                            top: figmaY(-173),
                            left:
                                media.size.width / 2 +
                                m(-52.4 - FrameMetrics.frameWidth / 2),
                            width: m(546.5),
                            height: m(382.8),
                            child: IgnorePointer(
                              child: SvgPicture.asset(
                                AppAssets.loginHeaderShape,
                                colorFilter: ColorFilter.mode(
                                  AppColors.main.withValues(alpha: 0.8),
                                  BlendMode.srcIn,
                                ),
                              ),
                            ),
                          ),
                          Column(
                            children: [
                              SizedBox(height: figmaY(152)),
                              SvgPicture.asset(
                                AppAssets.offyLogo,
                                width: m(144.4),
                                height: m(30),
                                colorFilter: const ColorFilter.mode(
                                  AppColors.white,
                                  BlendMode.srcIn,
                                ),
                                semanticsLabel: 'OFFY',
                              ),
                              SizedBox(height: m(277 - 152 - 30)),
                              Expanded(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: AppColors.white,
                                    borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(m(40)),
                                    ),
                                  ),
                                  // Padding, not Center + SizedBox: keeps the intrinsic
                                  // height correct for SliverFillRemaining (iPad overflow).
                                  child: Padding(
                                    padding: EdgeInsets.fromLTRB(
                                      sideInset,
                                      0,
                                      sideInset,
                                      bottomInset + m(27),
                                    ),
                                    child: const LoginForm(),
                                  ),
                                ),
                              ),
                            ],
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
