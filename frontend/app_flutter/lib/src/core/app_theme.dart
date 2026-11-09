// ─────────────────────────────────────────────────────────────────────────────
// Creo Design Tokens → Flutter
// Source: brand-theme.css + tokens.css
//
// Brand palette (dark, the default):
//   Burnished Amber  #D2965A  → accent fills, focus rings, check boxes
//   Obsidian         #0F0E0C  → page background
//   Ivory            #F5EEE3  → primary text
//   Espresso         #2B1E15  → ink on light
//   Terracotta       #D98A7A  → error / warnings
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

class CreoColors {
  CreoColors._();

  // ── Brand (dark) ────────────────────────────────────────────────────────
  static const Color accent = Color(0xFFD2965A); // burnished amber
  static const Color onAccent = Color(0xFF1A120C); // near-black on amber
  static const Color appVoid = Color(0xFF090807);
  static const Color appBase = Color(0xFF0F0E0C); // obsidian / page bg
  static const Color appSurface = Color(0xFF1B1916);
  static const Color appBento = Color(0xFF171513);
  static const Color appLine = Color(0xFF3A342D);
  static const Color appLineSoft = Color(0xFF2A2622);
  static const Color appMist = Color(0xFFB9AD9C); // muted text
  static const Color appInk = Color(0xFFF5EEE3); // ivory / primary text
  static const Color appWarm = Color(0xFFD98A7A); // terracotta / error

  // ── Site palette (used in auth panel) ───────────────────────────────────
  static const Color siteBg = Color(0xFF0F0E0C);
  static const Color siteSurface = Color(0xFF1F1C19);
  static const Color siteLine = Color(0xFF3A342D);
  static const Color siteMist = Color(0xFFB9AD9C);
  static const Color siteInk = Color(0xFFF5EEE3);
  static const Color siteRose = Color(0xFFD98A7A); // error rose

  // ── Semantic ────────────────────────────────────────────────────────────
  static const Color error = appWarm;
  static const Color errorBg = Color(0x1AD98A7A); // 10% terracotta
  static const Color errorBorder = Color(0x66D98A7A); // 40%
}

// ─────────────────────────────────────────────────────────────────────────────
// ThemeData
// ─────────────────────────────────────────────────────────────────────────────
class CreoPalette extends ThemeExtension<CreoPalette> {
  const CreoPalette({this.lightness = 0});
  final double lightness;
  Color _tone(Color dark, int light) =>
      Color.lerp(dark, Color(light), lightness)!;
  Color get accent => _tone(CreoColors.accent, 0xFF8A5A2B);
  Color get onAccent => _tone(CreoColors.onAccent, 0xFFFBF7F0);
  Color get appVoid => _tone(CreoColors.appVoid, 0xFFEFE4D6);
  Color get appBase => _tone(CreoColors.appBase, 0xFFF5EEE3);
  Color get appSurface => _tone(CreoColors.appSurface, 0xFFFBF7F0);
  Color get appBento => _tone(CreoColors.appBento, 0xFFEEE3D3);
  Color get appLine => _tone(CreoColors.appLine, 0xFFD8C8B2);
  Color get appLineSoft => _tone(CreoColors.appLineSoft, 0xFFE6DAC8);
  Color get appMist => _tone(CreoColors.appMist, 0xFF6E5F50);
  Color get appInk => _tone(CreoColors.appInk, 0xFF2B1E15);
  Color get appWarm => _tone(CreoColors.appWarm, 0xFF9A3F2F);
  Color get siteBg => appBase;
  Color get siteSurface => appSurface;
  Color get siteLine => appLine;
  Color get siteMist => appMist;
  Color get siteInk => appInk;
  Color get siteRose => appWarm;
  Color get error => appWarm;
  Color get errorBg => appWarm.withValues(alpha: .1);
  Color get errorBorder => appWarm.withValues(alpha: .4);
  @override
  CreoPalette copyWith({double? lightness}) =>
      CreoPalette(lightness: lightness ?? this.lightness);
  @override
  CreoPalette lerp(covariant CreoPalette? other, double t) => other == null
      ? this
      : CreoPalette(lightness: lightness + (other.lightness - lightness) * t);
}

extension CreoThemeContext on BuildContext {
  CreoPalette get creo =>
      Theme.of(this).extension<CreoPalette>() ?? const CreoPalette();
}

ThemeData buildCreoTheme({Brightness brightness = Brightness.dark}) {
  final palette = CreoPalette(
    lightness: brightness == Brightness.light ? 1 : 0,
  );
  final accent = palette.accent;

  return ThemeData(
    brightness: brightness,
    extensions: [palette],
    dividerColor: palette.appLine,
    focusColor: palette.accent.withValues(alpha: .18),
    scaffoldBackgroundColor: palette.appBase,
    primaryColor: accent,
    colorScheme: ColorScheme(
      brightness: brightness,
      onSecondary: palette.appBase,
      onSurface: palette.appInk,
      onError: palette.appBase,
      primary: accent,
      onPrimary: palette.onAccent,
      secondary: palette.appMist,
      surface: palette.appSurface,
      error: palette.error,
    ),

    // ── Text theme (Inter-like via system sans-serif) ──────────────────────
    textTheme: TextTheme(
      displayLarge: TextStyle(
        fontFamily: 'Inter',
        fontSize: 48,
        fontWeight: FontWeight.w900,
        letterSpacing: -2.0,
        color: palette.appInk,
      ),
      displayMedium: TextStyle(
        fontFamily: 'Inter',
        fontSize: 36,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.5,
        color: palette.appInk,
      ),
      headlineLarge: TextStyle(
        fontFamily: 'Inter',
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
        color: palette.appInk,
      ),
      titleLarge: TextStyle(
        fontFamily: 'Inter',
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: palette.appInk,
      ),
      titleMedium: TextStyle(
        fontFamily: 'Inter',
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: palette.appInk,
      ),
      bodyLarge: TextStyle(
        fontFamily: 'Inter',
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: palette.appInk,
        height: 1.6,
      ),
      bodyMedium: TextStyle(
        fontFamily: 'Inter',
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: palette.appMist,
        height: 1.6,
      ),
      labelLarge: TextStyle(
        fontFamily: 'Inter',
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: palette.appInk,
      ),
      labelSmall: TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.0,
        color: palette.appMist,
      ),
    ),

    // ── Input decoration ───────────────────────────────────────────────────
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.appSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: palette.appMist), // 3:1 vs page
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: palette.appMist), // 3:1 vs page
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: accent, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: palette.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: palette.error, width: 2),
      ),
      hintStyle: TextStyle(
        fontFamily: 'Inter',
        color: palette.appMist.withValues(alpha: 0.7),
        fontSize: 16,
        fontWeight: FontWeight.w400,
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),

    // ── Elevated button (primary) ──────────────────────────────────────────
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: palette.onAccent,
        disabledBackgroundColor: accent.withValues(alpha: 0.6),
        disabledForegroundColor: palette.onAccent,
        minimumSize: Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: EdgeInsets.symmetric(horizontal: 20),
        textStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        elevation: 0,
      ),
    ),

    // ── Outlined button (Google / secondary) ──────────────────────────────
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.appInk,
        side: BorderSide(color: palette.appLine, width: 1.5),
        minimumSize: Size(48, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        textStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // ── CheckboxTheme ──────────────────────────────────────────────────────
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return accent;
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.all(palette.onAccent),
      side: BorderSide(color: palette.appMist, width: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
    ),
  );
}
