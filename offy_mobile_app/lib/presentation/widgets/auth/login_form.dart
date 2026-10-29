import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_links.dart';
import '../../../core/navigation/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../viewmodels/auth/login_provider.dart';
import '../common/frame_metrics.dart';
import '../common/inline_error_banner.dart';
import 'login_input_field.dart';

/// White login sheet: heading, URL / email / password fields, install prompt, button.
/// Validation and login flow are the same as the previous login form.
class LoginForm extends StatelessWidget {
  const LoginForm({super.key});

  static final RegExp _urlChars = RegExp(r'[a-zA-Z0-9:/.@\-_~!$&?#=%+,;]');
  static final RegExp _emailChars = RegExp(r'[a-zA-Z0-9@._\-\+]');
  static final RegExp _emoji = RegExp(
    r'(\u00a9|\u00ae|[\u2000-\u3300]|\ud83c[\ud000-\udfff]|\ud83d[\ud000-\udfff]|\ud83e[\ud000-\udfff])',
  );

  Future<void> _submit(BuildContext context) async {
    final provider = context.read<LoginProvider>();
    if (provider.isLoading) return;
    FocusScope.of(context).unfocus();
    final success = await provider.login();
    if (context.mounted && success) {
      Navigator.pushNamedAndRemoveUntil(context, AppRouter.home, (_) => false);
    }
  }

  Future<void> _openInstallLink() async {
    final uri = AppLinks.odooModuleInstall;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String? _validateUrl(BuildContext context, String? value) {
    final l10n = AppLocalizations.of(context);
    final url = value ?? '';
    if (url.isEmpty) {
      return l10n?.enterWorkspaceUrl ?? 'Please enter a workspace URL';
    }
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !uri.hasScheme ||
        !uri.hasAuthority ||
        (!uri.isScheme('http') && !uri.isScheme('https'))) {
      return l10n?.enterValidHttpUrl ?? 'Please enter a valid HTTP/HTTPS URL';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final m = FrameMetrics.of(context);
    final provider = context.watch<LoginProvider>();
    final validateOnChange = provider.isSubmitted;

    return Form(
      key: provider.formKey,
      autovalidateMode: provider.isSubmitted
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      child: AbsorbPointer(
        absorbing: provider.isLoading,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: m(27)),
              Semantics(
                header: true,
                child: Text(
                  provider.isReturningUser
                      ? (l10n?.welcomeBack ?? 'Welcome back')
                      : (l10n?.login ?? 'Login'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: m(30),
                    fontWeight: FontWeight.w500,
                    height: 36 / 30,
                    color: AppColors.black,
                  ),
                ),
              ),
              SizedBox(height: m(1)),
              Text(
                l10n?.loginSubtitle ?? 'Enter your details below',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: m(14),
                  fontWeight: FontWeight.w400,
                  height: 23 / 14,
                  color: AppColors.navColor,
                ),
              ),
              SizedBox(height: m(45)),
              LoginInputField(
                label: l10n?.url ?? 'URL',
                hint: l10n?.loginUrlHint ?? 'Enter your URL',
                icon: AppAssets.link,
                initialValue: provider.url,
                keyboardType: TextInputType.url,
                autofillHints: const [AutofillHints.url],
                textInputAction: TextInputAction.next,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(_urlChars),
                  FilteringTextInputFormatter.deny(RegExp(r'\s')),
                ],
                validator: (v) => _validateUrl(context, v),
                validateOnChange: validateOnChange,
                onChanged: provider.urlChanged,
              ),
              SizedBox(height: m(24)),
              LoginInputField(
                label: l10n?.emailOrUsername ?? 'Email or Username',
                hint: l10n?.loginEmailHint ?? 'Enter your email or username',
                icon: AppAssets.sms,
                initialValue: provider.email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [
                  AutofillHints.username,
                  AutofillHints.email,
                ],
                textInputAction: TextInputAction.next,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(_emailChars),
                ],
                validator: (v) => (v ?? '').isEmpty
                    ? (l10n?.enterEmailOrUsername ??
                          'Please enter an email or username')
                    : null,
                validateOnChange: validateOnChange,
                onChanged: provider.emailChanged,
              ),
              SizedBox(height: m(24)),
              LoginInputField(
                label: l10n?.password ?? 'Password',
                hint: l10n?.loginPasswordHint ?? 'Enter your password',
                icon: AppAssets.lock,
                initialValue: provider.password,
                obscureText: provider.obscurePassword,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(context),
                inputFormatters: [FilteringTextInputFormatter.deny(_emoji)],
                validator: (v) => (v ?? '').isEmpty
                    ? (l10n?.enterPassword ?? 'Please enter your password')
                    : null,
                validateOnChange: validateOnChange,
                onChanged: provider.passwordChanged,
                suffix: IconButton(
                  onPressed: provider.togglePasswordVisibility,
                  icon: Icon(
                    provider.obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: m(22),
                    color: const Color(0xFF907067),
                  ),
                ),
              ),
              if (provider.errorMessage != null) SizedBox(height: m(16)),
              InlineErrorBanner(message: provider.errorMessage),
              SizedBox(height: m(24)),
              const Spacer(),
              _ModuleInstallPrompt(onInstall: _openInstallLink),
              SizedBox(height: m(26)),
              _LoginButton(
                label: l10n?.login ?? 'Login',
                isEnabledLook: provider.hasAllFields,
                isLoading: provider.isLoading,
                onPressed: () => _submit(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModuleInstallPrompt extends StatelessWidget {
  const _ModuleInstallPrompt({required this.onInstall});

  final VoidCallback onInstall;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final m = FrameMetrics.of(context);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text:
                '${l10n?.loginModuleNotInstalled ?? "Our module isn't installed yet."} ',
          ),
          TextSpan(
            text: l10n?.installNow ?? 'Install Now',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.main,
            ),
            recognizer: TapGestureRecognizer()..onTap = onInstall,
          ),
        ],
      ),
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: m(14),
        fontWeight: FontWeight.w400,
        height: 16.8 / 14,
        color: AppColors.black,
      ),
    );
  }
}

/// Pill button: orange gradient once every field has a value, grey before.
/// It stays tappable while grey so the field errors can still be shown.
class _LoginButton extends StatelessWidget {
  const _LoginButton({
    required this.label,
    required this.isEnabledLook,
    required this.isLoading,
    required this.onPressed,
  });

  final String label;
  final bool isEnabledLook;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final m = FrameMetrics.of(context);
    final radius = BorderRadius.circular(m(58));
    return Semantics(
      button: true,
      enabled: !isLoading,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isEnabledLook ? null : AppColors.shade,
          gradient: isEnabledLook
              ? const LinearGradient(
                  // Figma handles (0.2,-1.09) -> (0.8,2.09) on a 363x56 box.
                  begin: Alignment(-0.6, -3.18),
                  end: Alignment(0.6, 3.18),
                  colors: [
                    AppColors.loginButtonStart,
                    AppColors.loginButtonEnd,
                  ],
                )
              : null,
          borderRadius: radius,
          boxShadow: isEnabledLook
              ? [
                  BoxShadow(
                    color: AppColors.loginButtonStart.withValues(alpha: 0.25),
                    blurRadius: m(15),
                    offset: Offset(0, m(8)),
                  ),
                ]
              : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: isLoading ? null : onPressed,
            borderRadius: radius,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: m(56)),
              child: Center(
                heightFactor: 1,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: m(8)),
                  child: isLoading
                      ? SizedBox.square(
                          dimension: m(24),
                          child: const CircularProgressIndicator(
                            color: AppColors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          label,
                          style: TextStyle(
                            fontSize: m(18),
                            fontWeight: FontWeight.w400,
                            height: 24 / 18,
                            color: AppColors.white,
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
