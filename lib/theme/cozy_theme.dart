import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cozy Stardew-adjacent typography.
///
/// - **Pixelify Sans** — display / Latin title («Grow! Capy!»).
/// - **Nunito** — body, buttons, HUD (soft rounded OFL with solid Cyrillic).
class CozyTheme {
  CozyTheme._();

  static const cream = Color(0xFFFFF8EC);
  static const warmGold = Color(0xFFF3E2B8);
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

  /// Large stylized main-menu title: warm cream/gold fill + soft brown outline.
  /// Sized for top-third wordmark (Stardew-adjacent dominating logo).
  static TextStyle menuTitleStyle({double fontSize = 52}) {
    final outline = warmBrown;
    return GoogleFonts.pixelifySans(
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.8,
      height: 1.02,
      color: warmGold,
      shadows: [
        // Soft brown “outline” via cardinal + diagonal offsets (scaled up).
        Shadow(offset: const Offset(-2.4, 0), color: outline),
        Shadow(offset: const Offset(2.4, 0), color: outline),
        Shadow(offset: const Offset(0, -2.4), color: outline),
        Shadow(offset: const Offset(0, 2.4), color: outline),
        Shadow(offset: const Offset(-1.8, -1.8), color: outline),
        Shadow(offset: const Offset(1.8, -1.8), color: outline),
        Shadow(offset: const Offset(-1.8, 1.8), color: outline),
        Shadow(offset: const Offset(1.8, 1.8), color: outline),
        // Gentle drop shadow (not harsh glow).
        const Shadow(
          offset: Offset(0, 4),
          blurRadius: 8,
          color: Color(0x665C3D1E),
        ),
      ],
    );
  }

  static TextStyle menuTaglineStyle({double fontSize = 15}) {
    return GoogleFonts.nunito(
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      height: 1.25,
      color: cream,
      shadows: const [
        Shadow(offset: Offset(0, 1), blurRadius: 4, color: Color(0x885C3D1E)),
      ],
    );
  }

  static TextStyle primaryButtonStyle({double fontSize = 20}) {
    return GoogleFonts.nunito(
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      color: cream,
      letterSpacing: 0.4,
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
