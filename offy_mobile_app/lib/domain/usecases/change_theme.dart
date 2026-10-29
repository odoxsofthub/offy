import '../repositories/theme_repository.dart';

class ChangeTheme {
  final ThemeRepository repository;

  ChangeTheme(this.repository);

  Future<void> call(bool isDarkMode) async {
    return await repository.saveThemeMode(isDarkMode);
  }
}
