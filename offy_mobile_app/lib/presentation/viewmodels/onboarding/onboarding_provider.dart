import 'package:flutter/foundation.dart';
import '../../../domain/repositories/onboarding_repository.dart';

class OnboardingProvider extends ChangeNotifier {
  OnboardingProvider({required this.onboardingRepository});

  final OnboardingRepository onboardingRepository;

  int _currentIndex = 0;
  int get currentIndex => _currentIndex;

  bool _isCompleting = false;
  bool get isCompleting => _isCompleting;

  void setCurrentIndex(int index) {
    if (index == _currentIndex) return;
    _currentIndex = index;
    notifyListeners();
  }

  /// Persists the "seen" flag so onboarding shows once; a storage failure is logged and never blocks login.
  Future<void> completeOnboarding() async {
    if (_isCompleting) return;
    _isCompleting = true;
    notifyListeners();
    try {
      await onboardingRepository.markOnboardingCompleted();
    } catch (e) {
      debugPrint('OnboardingProvider: Failed to persist completion: $e');
    }
  }
}
