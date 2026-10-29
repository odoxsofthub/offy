import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../common/frame_metrics.dart';

enum OnboardingButtonVariant {
  /// Radial orange fill, white label (the slides).
  primary,

  /// White fill, dark label (Connect with Odoo).
  light,

  /// Thin white outline, white label (Connect with Odoo).
  outline,
}

/// Full-width 60pt pill button used across onboarding.
class OnboardingButton extends StatelessWidget {
  const OnboardingButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = OnboardingButtonVariant.primary,
  });

  final String label;
  final VoidCallback? onPressed;
  final OnboardingButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    final m = FrameMetrics.of(context);
    final borderRadius = BorderRadius.circular(m(50));
    final isLight = variant == OnboardingButtonVariant.light;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isLight ? AppColors.white : null,
          gradient: variant == OnboardingButtonVariant.primary
              ? const RadialGradient(
                  radius: 2.5,
                  colors: [AppColors.main, AppColors.mainGlow],
                )
              : null,
          border: variant == OnboardingButtonVariant.outline
              ? Border.all(color: AppColors.white, width: m(0.6))
              : null,
          borderRadius: borderRadius,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onPressed,
            borderRadius: borderRadius,
            child: ConstrainedBox(
              // Grows with large accessibility text instead of clipping it.
              constraints: BoxConstraints(
                minWidth: double.infinity,
                minHeight: m(60),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: m(16),
                  vertical: m(10),
                ),
                child: Center(
                  widthFactor: 1,
                  heightFactor: 1,
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: m(18),
                      fontWeight: isLight ? FontWeight.w500 : FontWeight.w400,
                      height: 24 / 18,
                      color: isLight ? AppColors.black : AppColors.white,
                    ),
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
