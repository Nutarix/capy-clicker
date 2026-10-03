import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:capy_clicker/theme/cozy_theme.dart';

/// Every font [CozyTheme] asks for must ship in `assets/google_fonts/`:
/// release builds have no internet permission, and runtime fetching is off.
void main() {
  /// All styles the theme hands out, so each requested weight gets loaded.
  List<TextStyle?> themeStyles() {
    final theme = CozyTheme.build();
    final t = theme.textTheme;
    final elevated = theme.elevatedButtonTheme.style?.textStyle;
    final text = theme.textButtonTheme.style?.textStyle;
    return [
      t.displayLarge,
      t.displayMedium,
      t.displaySmall,
      t.headlineLarge,
      t.headlineMedium,
      t.headlineSmall,
      t.titleLarge,
      t.titleMedium,
      t.titleSmall,
      t.bodyLarge,
      t.bodyMedium,
      t.bodySmall,
      t.labelLarge,
      t.labelMedium,
      t.labelSmall,
      theme.appBarTheme.titleTextStyle,
      theme.dialogTheme.titleTextStyle,
      theme.dialogTheme.contentTextStyle,
      elevated?.resolve(const {}),
      text?.resolve(const {}),
      CozyTheme.menuTitleStyle(),
      CozyTheme.menuPrimaryCtaStyle(),
      CozyTheme.primaryButtonStyle(),
      CozyTheme.secondaryButtonStyle(),
      CozyTheme.hudChipStyle(),
      CozyTheme.hudChipMutedStyle(),
    ];
  }

  double widthOf(String text, String family) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontFamily: family, fontSize: 40),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  testWidgets('theme fonts load from bundled assets, never the network', (
    tester,
  ) async {
    expect(GoogleFonts.config.allowRuntimeFetching, isFalse);

    final families = <String>{};
    await tester.runAsync(() async {
      for (final style in themeStyles()) {
        expect(style?.fontFamily, isNotNull);
        families.add(style!.fontFamily!);
      }
      // Throws if any requested weight is missing from the assets.
      await GoogleFonts.pendingFonts();
    });

    expect(
      families,
      containsAll(<String>[
        'Nunito_regular',
        'Nunito_600',
        'Nunito_700',
        'Nunito_800',
        'PixelifySans_700',
      ]),
    );

    // The test font draws every glyph the same width; a real font does not.
    for (final family in families) {
      expect(
        widthOf('iiii', family),
        lessThan(widthOf('MMMM', family) * 0.7),
        reason: '$family renders with the real font, not the test fallback',
      );
    }
  });
}
