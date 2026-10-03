import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app.dart';
import 'theme/cozy_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Fonts ship in assets/google_fonts/; the release build has no internet.
  GoogleFonts.config.allowRuntimeFetching = false;
  LicenseRegistry.addLicense(_fontLicenses);

  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Edge-to-edge: meadow paints under status/nav; HUD uses SafeArea padding.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(CozyTheme.systemOverlay);

  runApp(const CapyClickerApp());
}

Stream<LicenseEntry> _fontLicenses() async* {
  for (final (package, file) in const [
    ('Nunito', 'assets/google_fonts/Nunito-OFL.txt'),
    ('Pixelify Sans', 'assets/google_fonts/PixelifySans-OFL.txt'),
  ]) {
    yield LicenseEntryWithLineBreaks([
      package,
    ], await rootBundle.loadString(file));
  }
}
