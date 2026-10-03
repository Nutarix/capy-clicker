import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cozy Stardew-adjacent typography.
///
/// - **Pixelify Sans** — display title («Grow! Capy!») and primary menu CTA.
/// - **Nunito** — dialogs, HUD chips, Cyrillic fallback for tiny accessibility
///   labels (menu mute is icon-only).
class CozyTheme {
  CozyTheme._();

  static const cream = Color(0xFFFFF8EC);
  static const warmGold = Color(0xFFF3E2B8);
  static const warmBrown = Color(0xFF5C3D1E);
  static const softBrown = Color(0xFF8A6A45);
  static const meadowGreen = Color(0xFF6B9B4A);
  static const buttonGreen = Color(0xFF5A9A48);

  /// Soft sage for cozy menu CTA pill (not Material discord green).
  static const softSage = Color(0xFF7AAD68);
  static const softSageEdge = Color(0xFF4F7A42);

  /// Stable overlay. Contrast enforcement OFF — Samsung One UI paints a gray
  /// scrim over a transparent nav bar when it is left on, and reapplies it
  /// when the Flutter view submits a frame after a tap.
  static const systemOverlay = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemStatusBarContrastEnforced: false,
    systemNavigationBarContrastEnforced: false,
  );

  /// One theme per app: text styles inside are font lookups, done once.
  static ThemeData build() => _theme ??= _buildTheme();
  static ThemeData? _theme;

  static ThemeData _buildTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: meadowGreen,
      brightness: Brightness.light,
    );
    final base = ThemeData(colorScheme: colorScheme, useMaterial3: true);
    final nunitoText = GoogleFonts.nunitoTextTheme(base.textTheme)
        .apply(bodyColor: warmBrown, displayColor: warmBrown);
    return base.copyWith(
      scaffoldBackgroundColor: cream,
      canvasColor: cream,
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      textTheme: nunitoText,
      primaryTextTheme: nunitoText,
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: cream,
        systemOverlayStyle: systemOverlay,
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
  /// Sized for top wordmark (Stardew-adjacent dominating logo).
  static TextStyle menuTitleStyle({double fontSize = 52}) =>
      _menuTitle.putIfAbsent(fontSize, () => _menuTitleStyle(fontSize));

  // Font styles are made once per size, not on every rebuild (spec 002, Т9).
  static final _menuTitle = <double, TextStyle>{};
  static final _menuCta = <double, TextStyle>{};
  static final _primaryButton = <double, TextStyle>{};
  static final _secondaryButton = <double, TextStyle>{};
  static final _hudChip = <double, TextStyle>{};
  static final _hudChipMuted = <double, TextStyle>{};

  static TextStyle _menuTitleStyle(double fontSize) {
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

  /// Primary menu CTA — same Pixelify family as title; readable cozy size.
  /// Nunito is listed as fallback for Cyrillic glyphs Pixelify lacks.
  static TextStyle menuPrimaryCtaStyle({double fontSize = 22}) =>
      _menuCta.putIfAbsent(fontSize, () => _menuPrimaryCtaStyle(fontSize));

  static TextStyle _menuPrimaryCtaStyle(double fontSize) {
    final pixel = GoogleFonts.pixelifySans(
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.0,
      height: 1.1,
      color: cream,
    );
    final nunitoFamily = GoogleFonts.nunito().fontFamily;
    return pixel.copyWith(fontFamilyFallback: [?nunitoFamily, 'Nunito']);
  }

  static TextStyle primaryButtonStyle({double fontSize = 20}) {
    return _primaryButton.putIfAbsent(
      fontSize,
      () => GoogleFonts.nunito(
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        color: cream,
        letterSpacing: 0.4,
      ),
    );
  }

  static TextStyle secondaryButtonStyle({double fontSize = 15}) {
    return _secondaryButton.putIfAbsent(
      fontSize,
      () => GoogleFonts.nunito(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        color: warmBrown,
      ),
    );
  }

  static TextStyle hudChipStyle({double fontSize = 12}) {
    return _hudChip.putIfAbsent(
      fontSize,
      () => GoogleFonts.nunito(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        color: warmBrown,
      ),
    );
  }

  static TextStyle hudChipMutedStyle({double fontSize = 11}) {
    return _hudChipMuted.putIfAbsent(
      fontSize,
      () => GoogleFonts.nunito(
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        color: warmBrown,
      ),
    );
  }
}
