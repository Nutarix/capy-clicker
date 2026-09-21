import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cozy Stardew-adjacent typography.
///
/// - **Pixelify Sans** — display / Latin title («Grow! Capy!»).
/// - **Nunito** — body, buttons, HUD (soft rounded OFL with solid Cyrillic).
class CozyTheme {
  CozyTheme._();

  static const cream = Color(0xFFFFF8EC);
  static const warmBrown = Color(0xFF5C3D1E);
  static const softBrown = Color(0xFF8A6A45);
  static const meadowGreen = Color(0xFF6B9B4A);
  static const buttonGreen = Color(0xFF5A9A48);

  static ThemeData build() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: meadowGreen,
      brightness: Brightness.light,
    );
    final base = ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
    );
    final nunitoText = GoogleFonts.nunitoTextTheme(base.textTheme).apply(
      bodyColor: warmBrown,
      displayColor: warmBrown,
    );
    return base.copyWith(
      textTheme: nunitoText,
      primaryTextTheme: nunitoText,
      appBarTheme: AppBarTheme(
        titleTextStyle: GoogleFonts.nunito(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: warmBrown,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          textStyle: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        titleTextStyle: GoogleFonts.nunito(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: warmBrown,
        ),
        contentTextStyle: GoogleFonts.nunito(
          fontSize: 14,
          height: 1.35,
          color: warmBrown,
        ),
      ),
    );
  }

  /// Large stylized main-menu title: warm cream fill + soft brown outline/shadow.
  static TextStyle menuTitleStyle({double fontSize = 34}) {
    return GoogleFonts.pixelifySans(
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.4,
      height: 1.05,
      color: cream,
      shadows: const [
        // Soft brown “outline” via cardinal offsets.
        Shadow(offset: Offset(-1.6, 0), color: warmBrown),
        Shadow(offset: Offset(1.6, 0), color: warmBrown),
        Shadow(offset: Offset(0, -1.6), color: warmBrown),
        Shadow(offset: Offset(0, 1.6), color: warmBrown),
        Shadow(offset: Offset(-1.2, -1.2), color: warmBrown),
        Shadow(offset: Offset(1.2, -1.2), color: warmBrown),
        Shadow(offset: Offset(-1.2, 1.2), color: warmBrown),
        Shadow(offset: Offset(1.2, 1.2), color: warmBrown),
        // Gentle drop shadow (not harsh).
        Shadow(
          offset: Offset(0, 3),
          blurRadius: 6,
          color: Color(0x665C3D1E),
        ),
      ],
    );
  }

  static TextStyle primaryButtonStyle({double fontSize = 18}) {
    return GoogleFonts.nunito(
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      color: cream,
      letterSpacing: 0.3,
    );
  }

  static TextStyle secondaryButtonStyle({double fontSize = 15}) {
    return GoogleFonts.nunito(
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      color: warmBrown,
    );
  }

  static TextStyle hudChipStyle({double fontSize = 12}) {
    return GoogleFonts.nunito(
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      color: warmBrown,
    );
  }

  static TextStyle hudChipMutedStyle({double fontSize = 11}) {
    return GoogleFonts.nunito(
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      color: warmBrown,
    );
  }
}
