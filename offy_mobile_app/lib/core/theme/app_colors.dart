import 'package:flutter/material.dart';

class AppColors {
  // Primary
  static const Color main = Color(0xFFFD5223);
  static const Color secondary = Color(0xFF9F4122);
  static const Color light = Color(0xFFF3E9E0);

  // Error / Validation
  static const Color red = Color(0xFFFF383C);
  static const Color green = Color(0xFF34C759);

  // Others
  static const Color white = Color(0xFFFFFFFF);
  static const Color midLight = Color(0xFFEAE1D8);
  static const Color black = Color(0xFF1B1C1C);
  static const Color shade = Color(0xFFCAC3C0);
  static const Color navColor = Color(0xFFA49D95);
  static const Color tertiary = Color(0xFF5B4039);
  static const Color grey = Color(0XFF8E8E93);
  static const Color searchPill = Color(0xFFFFF5EB);

  // Onboarding
  static const Color onboardingBg = Color(0xFFFFF7EF);
  static const Color onboardingText = Color(0xFF585858);
  static const Color mainGlow = Color(0xFFFF5D31);
  static const Color onboardingConnectTop = Color(0xFF250728);
  static const Color onboardingConnectBottom = Color(0xFF0D0814);

  // Login (shade = disabled button, navColor = hint text)
  static const Color loginHeaderBottom = Color(0xFFB65539);
  static const Color loginFieldBorder = Color(0xFFC7CED5);
  static const Color loginFieldLabel = Color(0xFF5D5B59);
  static const Color loginButtonStart = Color(0xFFFF5722);
  static const Color loginButtonEnd = Color(0xFFFF8A65);

  // Accents
  static const Color teal = Color(0xFF00C3D0);
  static const Color yellow = Color(0xFFE5A50E);
  static const Color darkYellow = Color(0xFFFFCC00);
  static const Color darkGreen = Color(0xFF15803D);
  static const Color pink = Color(0xFFFF2D55);

  // Dark Mode Colors
  static const Color darkBg = Color(0xFF120901);
  static const Color darkTertiary = Color(0xFF351E09);
  static const Color darkTopCard = Color(0xFF2A1605);
  static const Color darkCard = Color(0xFF1E1004);
  static const Color darkNav = Color(0xFF7B5C38);

  static Color shimmerBase(bool isDark) => isDark ? darkCard : midLight;

  static Color shimmerHighlight(bool isDark) => isDark ? darkNav : white;
}
