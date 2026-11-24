import 'package:flutter/foundation.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../../domain/repositories/onboarding_repository.dart';

class SplashProvider extends ChangeNotifier {
  SplashProvider({
    required this.authRepository,
    required this.onboardingRepository,
  });

  final AuthRepository authRepository;
  final OnboardingRepository onboardingRepository;

  bool _isFinished = false;
  bool get isFinished => _isFinished;

  bool _isAuthenticated = false;
  bool get isAuthenticated => _isAuthenticated;

  /// First launch only. A signed-in user (e.g. an iOS reinstall that kept its
  /// keychain token) goes straight home instead.
  bool get shouldShowOnboarding =>
      !_isAuthenticated && !onboardingRepository.isOnboardingCompleted();

  bool _hasError = false;
  bool get hasError => _hasError;

  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  Future<void>? _splashFuture;

  Future<void> startSplash() => _splashFuture ??= _performStartSplash();

  Future<void> _performStartSplash() async {
    try {
      _hasError = false;
      final minSplashDuration = Future.delayed(
        const Duration(milliseconds: 600),
      );
      final results = await authRepository.refreshToken();
      await minSplashDuration;

      if (_isDisposed) return;

      _isAuthenticated = results;
      _isFinished = true;
      notifyListeners();
    } catch (e) {
      if (_isDisposed) return;
      _hasError = true;
      _splashFuture = null;
      // Server/network exceptions are handled by NetworkInterceptor overlay;
      // do not navigate to login.
      debugPrint('SplashProvider: Token refresh failed during splash: $e');
      notifyListeners();
    }
  }
}
