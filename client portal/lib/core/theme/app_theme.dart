import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class CreoTheme {
  static ThemeData get darkTheme {
    final textTheme = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);

    return ThemeData(
      useMaterial3: true,
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
      textTheme: textTheme.copyWith(
        displayLarge: GoogleFonts.plusJakartaSans(
          color: CreoColors.ivory,
          fontSize: 32,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.0,
        ),
        headlineLarge: GoogleFonts.plusJakartaSans(
          color: CreoColors.ivory,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        headlineMedium: GoogleFonts.plusJakartaSans(
          color: CreoColors.ivory,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
        titleLarge: GoogleFonts.inter(
          color: CreoColors.ivory,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: GoogleFonts.inter(
          color: CreoColors.ivory,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: GoogleFonts.inter(
          color: CreoColors.ivory,
          fontSize: 14,
          fontWeight: FontWeight.normal,
        ),
        bodyMedium: GoogleFonts.inter(
          color: CreoColors.mist,
          fontSize: 13,
          fontWeight: FontWeight.normal,
        ),
        labelSmall: GoogleFonts.inter(
          color: CreoColors.mist,
          fontSize: 11,
          fontWeight: FontWeight.w600,
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
    final textTheme = GoogleFonts.interTextTheme(ThemeData.light().textTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: CreoColors.lightBase,
      primaryColor: CreoColors.amber,
      colorScheme: const ColorScheme.light(
        primary: CreoColors.amber,
        onPrimary: Colors.white,
        surface: CreoColors.lightCard,
        onSurface: CreoColors.lightEspresso,
        error: CreoColors.terracotta,
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
      textTheme: textTheme.copyWith(
        displayLarge: GoogleFonts.plusJakartaSans(
          color: CreoColors.lightEspresso,
          fontSize: 32,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.0,
        ),
        headlineLarge: GoogleFonts.plusJakartaSans(
          color: CreoColors.lightEspresso,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        headlineMedium: GoogleFonts.plusJakartaSans(
          color: CreoColors.lightEspresso,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
        titleLarge: GoogleFonts.inter(
          color: CreoColors.lightEspresso,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
        bodyMedium: GoogleFonts.inter(
          color: CreoColors.lightMist,
          fontSize: 13,
          fontWeight: FontWeight.normal,
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

