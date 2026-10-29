abstract class ThemeRepository {
  Future<void> saveThemeMode(bool isDarkMode);
  bool? getThemeMode();
}
