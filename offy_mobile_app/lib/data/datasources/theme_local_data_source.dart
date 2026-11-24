import 'package:shared_preferences/shared_preferences.dart';

abstract class ThemeLocalDataSource {
  Future<void> cacheThemeMode(bool isDarkMode);
  bool? getCachedThemeMode();
}

const cachedThemeModeKey = 'CACHED_THEME_MODE';

class ThemeLocalDataSourceImpl implements ThemeLocalDataSource {
  final SharedPreferences sharedPreferences;

  ThemeLocalDataSourceImpl({required this.sharedPreferences});

  @override
  Future<void> cacheThemeMode(bool isDarkMode) {
    return sharedPreferences.setBool(cachedThemeModeKey, isDarkMode);
  }

  @override
  bool? getCachedThemeMode() {
    return sharedPreferences.getBool(cachedThemeModeKey);
  }
}
