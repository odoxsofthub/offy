import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_colors.dart';

/// Rocket in the brand gradient with two soft halo rings; scales in once.
class UpdateIconBadge extends StatelessWidget {
  const UpdateIconBadge({super.key, this.size = 88});

  final double size;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final core = size.w;
    return ExcludeSemantics(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: reduceMotion ? 1 : 0.85, end: 1),
        duration: Duration(milliseconds: reduceMotion ? 0 : 420),
        curve: Curves.easeOutBack,
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: Container(
          width: core * 1.6,
          height: core * 1.6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.main.withValues(alpha: 0.06),
          ),
          alignment: Alignment.center,
          child: Container(
            width: core * 1.3,
            height: core * 1.3,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.main.withValues(alpha: 0.10),
            ),
            alignment: Alignment.center,
            child: Container(
              width: core,
              height: core,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.loginButtonEnd, AppColors.main],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.main.withValues(alpha: 0.35),
                    blurRadius: 24.r,
                    offset: Offset(0, 10.h),
                  ),
                ],
              ),
              child: Icon(
                Icons.rocket_launch_rounded,
                color: AppColors.white,
                size: core * 0.45,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pill showing the new version, e.g. "Version 1.0.2 (7)".
class UpdateVersionChip extends StatelessWidget {
  const UpdateVersionChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkTertiary : AppColors.searchPill,
        borderRadius: BorderRadius.circular(100.r),
        border: Border.all(color: AppColors.main.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_rounded, size: 14.sp, color: AppColors.main),
          SizedBox(width: 6.w),
          Text(
            label,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.loginButtonEnd : AppColors.secondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// "What's new" card listing the release notes from the appcast.
class UpdateReleaseNotes extends StatelessWidget {
  const UpdateReleaseNotes({
    super.key,
    required this.title,
    required this.notes,
  });

  final String title;
  final List<String> notes;

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? AppColors.light.withValues(alpha: 0.85)
        : AppColors.onboardingText;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(18.w, 16.h, 18.w, 6.h),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: isDark ? AppColors.darkTertiary : AppColors.midLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.white : AppColors.black,
              ),
            ),
          ),
          SizedBox(height: 12.h),
          for (final note in notes)
            Padding(
              padding: EdgeInsets.only(bottom: 10.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: 1.h),
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 18.sp,
                      color: AppColors.main,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      note,
                      style: TextStyle(
                        fontSize: 15.sp,
                        height: 1.45,
                        color: textColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Primary "Update now" pill in the login button's gradient; spinner while busy.
class UpdateNowButton extends StatelessWidget {
  const UpdateNowButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(58.r);
    return Semantics(
      button: true,
      enabled: !isLoading,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [AppColors.loginButtonStart, AppColors.loginButtonEnd],
          ),
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: AppColors.loginButtonStart.withValues(alpha: 0.25),
              blurRadius: 15.r,
              offset: Offset(0, 8.h),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: isLoading ? null : onPressed,
            borderRadius: radius,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: 56.h),
              child: Center(
                heightFactor: 1,
                child: isLoading
                    ? SizedBox.square(
                        dimension: 24.r,
                        child: const CircularProgressIndicator(
                          color: AppColors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.white,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: AppColors.white,
                            size: 20.sp,
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
