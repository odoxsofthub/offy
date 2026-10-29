import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../common/frame_metrics.dart';

/// Segmented step bar shown at the top of the onboarding flow.
/// Segments up to and including [currentIndex] are highlighted.
class OnboardingProgressIndicator extends StatelessWidget {
  const OnboardingProgressIndicator({
    super.key,
    required this.stepCount,
    required this.currentIndex,
  });

  final int stepCount;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    final m = FrameMetrics.of(context);
    return Semantics(
      label: 'Step ${currentIndex + 1} of $stepCount',
      child: Row(
        children: List.generate(stepCount * 2 - 1, (i) {
          if (i.isOdd) return SizedBox(width: m(12));
          final isActive = i ~/ 2 <= currentIndex;
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: m(3),
              decoration: BoxDecoration(
                color: isActive ? AppColors.secondary : AppColors.shade,
                borderRadius: BorderRadius.circular(m(3)),
              ),
            ),
          );
        }),
      ),
    );
  }
}
