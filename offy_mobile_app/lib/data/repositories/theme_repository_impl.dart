import '../../domain/repositories/theme_repository.dart';
import '../datasources/theme_local_data_source.dart';

class ThemeRepositoryImpl implements ThemeRepository {
  final ThemeLocalDataSource localDataSource;

  ThemeRepositoryImpl({required this.localDataSource});

  @override
  bool? getThemeMode() {
    return localDataSource.getCachedThemeMode();
  }

  @override
  Future<void> saveThemeMode(bool isDarkMode) async {
    return await localDataSource.cacheThemeMode(isDarkMode);
  }
}
