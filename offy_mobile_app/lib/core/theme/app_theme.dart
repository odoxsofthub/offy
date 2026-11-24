import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      fontFamily: GoogleFonts.urbanist().fontFamily,
      primaryColor: AppColors.main,
      scaffoldBackgroundColor: AppColors.light,
      colorScheme: const ColorScheme.light(
        primary: AppColors.main,
        secondary: AppColors.secondary,
        tertiary: AppColors.tertiary,
        surface: AppColors.white,
        error: AppColors.red,
        onPrimary: AppColors.white,
        onSecondary: AppColors.black,
        onSurface: AppColors.black,
        onError: AppColors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.main,
        foregroundColor: AppColors.white,
        elevation: 0,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: AppColors.navColor,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: AppColors.black),
        bodyMedium: TextStyle(color: AppColors.black),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        constraints: BoxConstraints(
          maxWidth: double.infinity,
        ),
      ),
      extensions: const [
        AppThemeColors(
          bg: AppColors.light,
          tertiary: AppColors.tertiary,
          topCard: AppColors.white,
          card: AppColors.white,
        ),
      ],
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      fontFamily: GoogleFonts.urbanist().fontFamily,
      primaryColor: AppColors.main,
      scaffoldBackgroundColor: AppColors.darkBg,
      cardColor: AppColors.darkCard,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.main,
        secondary: AppColors.secondary,
        tertiary: AppColors.darkTertiary,
        surface: AppColors.darkBg,
        error: AppColors.red,
        onPrimary: AppColors.white,
        onSecondary: AppColors.black,
        onSurface: AppColors.white,
        onError: AppColors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkBg,
        foregroundColor: AppColors.white,
        elevation: 0,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: AppColors.darkBg,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: AppColors.white),
        bodyMedium: TextStyle(color: AppColors.white),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        constraints: BoxConstraints(
          maxWidth: double.infinity,
        ),
      ),
      extensions: const [
        AppThemeColors(
          bg: AppColors.darkBg,
          tertiary: AppColors.darkTertiary,
          topCard: AppColors.darkTopCard,
          card: AppColors.darkCard,
        ),
      ],
    );
  }
}

class AppThemeColors extends ThemeExtension<AppThemeColors> {
  final Color bg;
  final Color tertiary;
  final Color topCard;
  final Color card;

  const AppThemeColors({
    required this.bg,
    required this.tertiary,
    required this.topCard,
    required this.card,
  });

  @override
  AppThemeColors copyWith({
    Color? bg,
    Color? tertiary,
    Color? topCard,
    Color? card,
  }) {
    return AppThemeColors(
      bg: bg ?? this.bg,
      tertiary: tertiary ?? this.tertiary,
      topCard: topCard ?? this.topCard,
      card: card ?? this.card,
    );
  }

  @override
  AppThemeColors lerp(ThemeExtension<AppThemeColors>? other, double t) {
    if (other is! AppThemeColors) {
      return this;
    }
    return AppThemeColors(
      bg: Color.lerp(bg, other.bg, t)!,
      tertiary: Color.lerp(tertiary, other.tertiary, t)!,
      topCard: Color.lerp(topCard, other.topCard, t)!,
      card: Color.lerp(card, other.card, t)!,
    );
  }
}

extension AppThemeColorsExtension on ThemeData {
  AppThemeColors get appColors => extension<AppThemeColors>()!;
}

extension BuildContextThemeColorsExtension on BuildContext {
  AppThemeColors get appColors => Theme.of(this).appColors;
}
