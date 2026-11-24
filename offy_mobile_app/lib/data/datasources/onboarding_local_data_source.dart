import 'package:shared_preferences/shared_preferences.dart';

abstract class OnboardingLocalDataSource {
  Future<void> cacheOnboardingCompleted();
  bool isOnboardingCompleted();
}

const onboardingCompletedKey = 'ONBOARDING_COMPLETED';

class OnboardingLocalDataSourceImpl implements OnboardingLocalDataSource {
  final SharedPreferences sharedPreferences;

  OnboardingLocalDataSourceImpl({required this.sharedPreferences});

  @override
  Future<void> cacheOnboardingCompleted() {
    return sharedPreferences.setBool(onboardingCompletedKey, true);
  }

  @override
  bool isOnboardingCompleted() {
    return sharedPreferences.getBool(onboardingCompletedKey) ?? false;
  }
}
