import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../common/frame_metrics.dart';
import 'onboarding_shrinkable_height.dart';

class OnboardingSlideData {
  const OnboardingSlideData({
    required this.image,
    required this.title,
    required this.highlight,
    required this.description,
    required this.buttonLabel,
    this.illustrationWidth = FrameMetrics.frameWidth,
    this.header,
  });

  final String image;
  final String title;
  final String highlight;
  final String description;
  final String buttonLabel;

  /// Illustration width in the 402pt Figma frame. Wider than the frame means
  /// it bleeds past the screen edges, as in the design.
  final double illustrationWidth;

  /// Optional content shown between the progress bar and the illustration.
  final Widget? header;
}

/// One onboarding step: illustration on the cream background, followed by
/// the white bottom card holding the two-tone title and description.
class OnboardingSlideView extends StatelessWidget {
  const OnboardingSlideView({super.key, required this.slide});

  final OnboardingSlideData slide;

  /// Smallest the illustration gets before the slide starts scrolling
  /// (short windows, large accessibility text).
  static const double _minIllustrationHeight = 140;

  @override
  Widget build(BuildContext context) {
    final m = FrameMetrics.of(context);
    // Illustration takes the remaining height; below the minimum the slide scrolls.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(child: _buildContent(m)),
        ),
      ),
    );
  }

  Widget _buildContent(FrameMetrics m) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (slide.header != null) ...[SizedBox(height: m(32)), slide.header!],
        Expanded(
          child: OnboardingShrinkableHeight(
            minHeight: m(_minIllustrationHeight),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: m(16)),
              child: OverflowBox(
                // Figma places the illustrations slightly below centre.
                alignment: const Alignment(0, 0.15),
                minWidth: 0,
                maxWidth:
                    m.contentWidth *
                    slide.illustrationWidth /
                    FrameMetrics.frameWidth,
                child: Image.asset(
                  slide.image,
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                ),
              ),
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(m(30))),
          ),
          child: Center(
            heightFactor: 1,
            child: SizedBox(
              width: m.contentWidth,
              child: Padding(
                padding: EdgeInsets.fromLTRB(m(43), m(43), m(43), m(33)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: '${slide.title}\n'),
                          TextSpan(
                            text: slide.highlight,
                            style: const TextStyle(color: AppColors.main),
                          ),
                        ],
                      ),
                      style: TextStyle(
                        fontSize: m(36),
                        fontWeight: FontWeight.w600,
                        height: 38 / 36,
                        letterSpacing: m(-0.5),
                        color: AppColors.black,
                      ),
                    ),
                    SizedBox(height: m(10)),
                    Text(
                      slide.description,
                      style: TextStyle(
                        fontSize: m(16),
                        fontWeight: FontWeight.w400,
                        height: 20 / 16,
                        color: AppColors.onboardingText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
