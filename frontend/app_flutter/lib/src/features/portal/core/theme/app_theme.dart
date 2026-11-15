import 'package:flutter/material.dart';
import 'app_colors.dart';

class CreoTheme {
  static TextStyle _font(
    double size, {
    FontWeight weight = FontWeight.normal,
    Color? color,
    double? letterSpacing,
  }) => TextStyle(
    fontFamily: 'Inter',
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
  );

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      brightness: Brightness.dark,
      scaffoldBackgroundColor: CreoColors.obsidian,
      primaryColor: CreoColors.amber,
      colorScheme: const ColorScheme.dark(
        primary: CreoColors.amber,
        onPrimary: CreoColors.onAmber,
        surface: CreoColors.bentoCard,
        onSurface: CreoColors.ivory,
        error: CreoColors.terracotta,
      ),
      dividerColor: CreoColors.lineSoft,
      cardTheme: CardThemeData(
        color: CreoColors.bentoCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: CreoColors.lineSoft, width: 1),
        ),
      ),
      textTheme: TextTheme(
        displayLarge: _font(
          32,
          weight: FontWeight.w800,
          color: CreoColors.ivory,
          letterSpacing: -1.0,
        ),
        headlineLarge: _font(
          24,
          weight: FontWeight.w700,
          color: CreoColors.ivory,
          letterSpacing: -0.5,
        ),
        headlineMedium: _font(
          20,
          weight: FontWeight.w600,
          color: CreoColors.ivory,
          letterSpacing: -0.3,
        ),
        titleLarge: _font(17, weight: FontWeight.w600, color: CreoColors.ivory),
        titleMedium: _font(
          15,
          weight: FontWeight.w500,
          color: CreoColors.ivory,
        ),
        bodyLarge: _font(
          14,
          weight: FontWeight.normal,
          color: CreoColors.ivory,
        ),
        bodyMedium: _font(
          13,
          weight: FontWeight.normal,
          color: CreoColors.mist,
        ),
        labelSmall: _font(
          11,
          weight: FontWeight.w600,
          color: CreoColors.mist,
          letterSpacing: 0.8,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: CreoColors.voidBg,
        selectedItemColor: CreoColors.amber,
        unselectedItemColor: CreoColors.mist,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      brightness: Brightness.light,
      scaffoldBackgroundColor: CreoColors.lightBase,
      primaryColor: const Color(0xFF8A5A2B),
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF8A5A2B),
        onPrimary: Colors.white,
        surface: CreoColors.lightCard,
        onSurface: CreoColors.lightEspresso,
        error: Color(0xFF9A3E2F),
      ),
      dividerColor: CreoColors.lightLine,
      cardTheme: CardThemeData(
        color: CreoColors.lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: CreoColors.lightLine, width: 1),
        ),
      ),
      textTheme: TextTheme(
        displayLarge: _font(
          32,
          weight: FontWeight.w800,
          color: CreoColors.lightEspresso,
          letterSpacing: -1.0,
        ),
        headlineLarge: _font(
          24,
          weight: FontWeight.w700,
          color: CreoColors.lightEspresso,
          letterSpacing: -0.5,
        ),
        headlineMedium: _font(
          20,
          weight: FontWeight.w600,
          color: CreoColors.lightEspresso,
          letterSpacing: -0.3,
        ),
        titleLarge: _font(
          17,
          weight: FontWeight.w600,
          color: CreoColors.lightEspresso,
        ),
        bodyMedium: _font(
          13,
          weight: FontWeight.normal,
          color: CreoColors.lightMist,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: CreoColors.lightCard,
        selectedItemColor: CreoColors.amber,
        unselectedItemColor: CreoColors.lightMist,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }
}
