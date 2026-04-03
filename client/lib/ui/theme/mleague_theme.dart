import 'package:flutter/material.dart';

class MLeagueTheme {
  static const Color bg = Color(0xFF0B0F14);
  static const Color panel = Color(0xFF111824);
  static const Color line = Color(0xFF1E2A3A);
  static const Color accentGreen = Color(0xFF00E676);
  static const Color accentGold = Color(0xFFFFC107);
  static const Color danger = Color(0xFFFF5252);

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: bg,
      colorScheme: base.colorScheme.copyWith(
        surface: panel,
        primary: accentGold,
        secondary: accentGreen,
        error: danger,
      ),
      cardTheme: const CardThemeData(
        color: panel,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      dividerColor: line,
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: panel,
        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  static ThemeData light() {
    return ThemeData.light(useMaterial3: true);
  }
}
