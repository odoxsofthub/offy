import 'package:flutter/foundation.dart';
import '../../domain/usecases/logout_usecase.dart';
import '../../injection_container.dart' as di;
import '../navigation/app_router.dart';
import '../../presentation/widgets/common/custom_snackbar.dart';
import 'session_reset_service.dart';
import 'token_storage.dart';

class SessionManager {
  final SessionResetService sessionResetService;
  final TokenStorage tokenStorage;
  bool _isTerminating = false;

  SessionManager({
    required this.sessionResetService,
    required this.tokenStorage,
  });

  /// Navigates to login immediately, then revokes the remote session (ignoring network errors)
  /// and clears local credentials and provider state.
  Future<void> logout() async {
    // 1. Immediately navigate back to login
    AppRouter.navigatorKey.currentState?.pushNamedAndRemoveUntil(
      AppRouter.login,
      (route) => false,
    );

    // 2. Best-effort remote session revocation
    try {
      if (di.sl.isRegistered<LogoutUseCase>()) {
        await di.sl<LogoutUseCase>()();
      }
    } on Exception catch (e) {
      debugPrint('SessionManager: Remote logout API ignored/failed (possibly offline): $e');
    } catch (e) {
      debugPrint('SessionManager: Unexpected error during remote logout: $e');
    }

    // 3. Local state and token cleanup
    try {
      sessionResetService.resetAll();
      await tokenStorage.clear();
    } catch (e, stack) {
      debugPrint('SessionManager: Error during local session cleanup: $e\n$stack');
    }
  }

  /// Handles complete session cleanup (resets providers & clears tokens)
  /// and navigates to the login screen.
  Future<void> terminateSession({bool isExpired = true}) async {
    if (_isTerminating) return;
    _isTerminating = true;

    try {
      if (isExpired) {
        CustomSnackbar.suppressExceptSessionExpired();
      }

      // 1. Immediately navigate back to login screen clearing all routes
      AppRouter.navigatorKey.currentState?.pushNamedAndRemoveUntil(
        AppRouter.login,
        (route) => false,
      );

      // 2. Clear persisted tokens and session credentials
      await tokenStorage.clear();

      // 3. Reset all registered session-scoped providers AFTER navigation
      sessionResetService.resetAll();

      // 4. Render session expiration feedback if applicable
      if (isExpired) {
        final context = AppRouter.navigatorKey.currentContext;
        if (context != null && context.mounted) {
          CustomSnackbar.show(
            context,
            message: CustomSnackbar.sessionExpiredMessage,
          );
        }
      }
    } finally {
      Future.delayed(const Duration(seconds: 4), () {
        _isTerminating = false;
      });
    }
  }
}
