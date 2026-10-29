import '../repositories/theme_repository.dart';

class GetSavedTheme {
  final ThemeRepository repository;

  GetSavedTheme(this.repository);

  bool? call() {
    return repository.getThemeMode();
  }
}
