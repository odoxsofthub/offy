import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_colors.dart';

class CompanySwitchingOverlay extends StatefulWidget {
  final String? message;

  const CompanySwitchingOverlay({
    super.key,
    this.message,
  });

  static OverlayEntry? _currentOverlay;
  static _CompanySwitchingOverlayState? _currentState;

  /// Shows the blocking full-screen overlay over the entire application.
  static void show(BuildContext context, {String? message}) {
    if (_currentOverlay != null) return;

    final overlayState = Overlay.of(context, rootOverlay: true);
    _currentOverlay = OverlayEntry(
      builder: (context) => CompanySwitchingOverlay(message: message),
    );
    overlayState.insert(_currentOverlay!);
  }

  /// Transitions overlay to success state (displaying checkmark tick) without hiding immediately.
  static void showSuccess() {
    if (_currentState != null && _currentState!.mounted) {
      _currentState!._showSuccess();
    }
  }

  /// Transitions overlay to success state, waits [duration], then hides.
  static Future<void> showSuccessAndHide({
    Duration duration = const Duration(milliseconds: 300),
  }) async {
    if (_currentState != null && _currentState!.mounted) {
      _currentState!._showSuccess();
      await Future.delayed(duration);
    }
    hide();
  }

  /// Removes the blocking full-screen overlay immediately.
  static void hide() {
    _currentOverlay?.remove();
    _currentOverlay = null;
    _currentState = null;
  }

  @override
  State<CompanySwitchingOverlay> createState() =>
      _CompanySwitchingOverlayState();
}

class _CompanySwitchingOverlayState extends State<CompanySwitchingOverlay> {
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    CompanySwitchingOverlay._currentState = this;
  }

  @override
  void dispose() {
    if (CompanySwitchingOverlay._currentState == this) {
      CompanySwitchingOverlay._currentState = null;
    }
    super.dispose();
  }

  void _showSuccess() {
    if (mounted) {
      setState(() {
        _isSuccess = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.light,
          systemNavigationBarContrastEnforced: false,
        ),
        child: Material(
          color: Colors.transparent,
          child: Stack(
            children: [
              // Darkened backdrop with blur
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.7),
                  ),
                ),
              ),
              // Centered Modal Dialog Card matching app design language
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 30.w),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 24.w,
                      vertical: 36.h,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : Colors.white,
                      borderRadius: BorderRadius.circular(32.r),
                      border: Border.all(
                        color: isDark
                            ? AppColors.darkTertiary
                            : Colors.white.withValues(alpha: 0.5),
                        width: 1.w,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0x1F000000),
                          offset: const Offset(0, 8),
                          blurRadius: 40.r,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Loading Spinner / Success Checkmark Section with Brand Glow
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 80.w,
                              height: 80.w,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.main.withValues(alpha: 0.2),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.main.withValues(
                                      alpha: 0.25,
                                    ),
                                    blurRadius: 20.r,
                                    spreadRadius: 10.r,
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 80.w,
                              height: 80.w,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFFB02F00),
                                    Color(0xFFFD8863),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0x1A000000),
                                    offset: const Offset(0, 20),
                                    blurRadius: 25.r,
                                    spreadRadius: -5.r,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: _isSuccess
                                    ? Icon(
                                        Icons.check_rounded,
                                        color: Colors.white,
                                        size: 36.w,
                                      )
                                    : SizedBox(
                                        width: 32.w,
                                        height: 32.w,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 3.w,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 24.h),
                        Text(
                          _isSuccess ? 'Company Switched' : 'Switching Company',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22.sp,
                            fontWeight: FontWeight.w600,
                            height: 28 / 22,
                            color: isDark ? AppColors.white : AppColors.black,
                          ),
                        ),
                        if (!_isSuccess) ...[
                          SizedBox(height: 8.h),
                          Text(
                            widget.message ??
                                'Please wait while we update your workspace...',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w300,
                              height: 22 / 15,
                              color: isDark
                                  ? AppColors.navColor
                                  : const Color(0xFF5B4039),
                            ),
                          ),
                        ],
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
}
