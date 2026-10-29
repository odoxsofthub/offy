import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/network/offline_back_handler.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/common/custom_back_button.dart';
import '../../widgets/network/no_network_logout_button.dart';
import '../../widgets/settings/logout_confirmation_dialog.dart';

class NoNetworkScreen extends StatefulWidget {
  const NoNetworkScreen({
    super.key,
    required this.onRetry,
    required this.onCancel,
    this.isChecking = false,
    this.isServerUnreachable = false,
    this.showBackButton = true,
    this.onLogout,
  });

  final VoidCallback onRetry;
  final VoidCallback onCancel;
  final bool isChecking;
  final bool isServerUnreachable;
  final bool showBackButton;
  final VoidCallback? onLogout;

  @override
  State<NoNetworkScreen> createState() => _NoNetworkScreenState();
}

class _NoNetworkScreenState extends State<NoNetworkScreen> {
  bool _showLogoutDialog = false;

  /// System back: closes the logout dialog, else acts as the back button
  /// (when there is one). Android back reaches this via [OfflineBackHandler].
  void _handleBack() {
    if (!mounted) return;
    if (_showLogoutDialog) {
      setState(() => _showLogoutDialog = false);
    } else if (widget.showBackButton) {
      widget.onCancel();
    }
  }

  @override
  void dispose() {
    if (OfflineBackHandler.instance.onBack == _handleBack) {
      OfflineBackHandler.instance.onBack = null;
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    OfflineBackHandler.instance.onBack = _handleBack;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusManager.instance.primaryFocus?.unfocus();
      FocusScope.of(context).unfocus();
      SystemChannels.textInput.invokeMethod('TextInput.hide');
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isChecking = widget.isChecking;
    final isServerUnreachable = widget.isServerUnreachable;
    final showBackButton = widget.showBackButton;
    final onRetry = widget.onRetry;
    final onCancel = widget.onCancel;

    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Circular container containing the offline image
        Container(
          width: 180.w,
          height: 180.w,
          decoration: BoxDecoration(
            color: isDark ? const Color(0x337B5C38) : const Color(0XFFEAE1D8),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Image.asset(
              AppAssets.noNetwork,
              fit: BoxFit.contain,
              width: 132.10.w,
              height: 120.h,
            ),
          ),
        ),
        SizedBox(height: 60.h),
        // Title and Subtitle
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                isServerUnreachable
                    ? (AppLocalizations.of(context)?.serverConnectionError ??
                        'Server Connection Error')
                    : (AppLocalizations.of(context)?.youAreOffline ??
                        'You’re offline!'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 28.sp,
                  height: 28 / 28,
                  color: isDark
                      ? const Color(0xFFFD5223)
                      : const Color(0xFF9F4122),
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                isServerUnreachable
                    ? (AppLocalizations.of(context)?.serverConnectionErrorDesc ??
                        'We’re having trouble connecting to our servers. \nPlease try again shortly.')
                    : (AppLocalizations.of(context)?.checkConnectionAndTryAgain ??
                        'Please check your connection \nand try again.'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w300,
                  fontSize: 18.sp,
                  height: 24 / 18,
                  color: isDark ? AppColors.light : AppColors.black,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
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
        backgroundColor: isDark ? Colors.transparent : Colors.white,
        body: Container(
          width: double.infinity,
          height: double.infinity,
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
          child: Stack(
            children: [
              // Main content column
              Column(
                children: [
                  Expanded(child: Center(child: content)),
                  SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.w),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8.r),
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF5722), Color(0xFFFF8A65)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0x40FF5722),
                                  offset: const Offset(0, 8),
                                  blurRadius: 15.r,
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8.r),
                                onTap: isChecking ? null : onRetry,
                                child: Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.symmetric(vertical: 12.h),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      if (isChecking) ...[
                                        SizedBox(
                                          width: 20.r,
                                          height: 20.r,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.r,
                                            valueColor:
                                                const AlwaysStoppedAnimation<
                                                  Color
                                                >(Colors.white),
                                          ),
                                        ),
                                      ] else ...[
                                        Text(
                                          AppLocalizations.of(context)?.tryAgain ??
                                              'Try again',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w400,
                                            fontSize: 16.sp,
                                            height: 24 / 16,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 22.h),
                      ],
                    ),
                  ),
                ],
              ),
              // Stacked Back Button on top left
              if (showBackButton)
                Positioned(
                  top: 16.h,
                  left: 16.w,
                  child: SafeArea(child: CustomBackButton(onTap: onCancel)),
                ),
              // Stacked Logout Button on top right
              if (widget.onLogout != null)
                Positioned(
                  top: 16.h,
                  right: 16.w,
                  child: SafeArea(
                    child: NoNetworkLogoutButton(
                      onTap: () => setState(() => _showLogoutDialog = true),
                    ),
                  ),
                ),
              // Logout Confirmation Overlay Dialog
              if (_showLogoutDialog)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.5),
                    child: Center(
                      child: LogoutConfirmationDialog(
                        onConfirm: () {
                          setState(() => _showLogoutDialog = false);
                          widget.onLogout?.call();
                        },
                        onCancel: () {
                          setState(() => _showLogoutDialog = false);
                        },
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
}
