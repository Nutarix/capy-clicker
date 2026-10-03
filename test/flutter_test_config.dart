import 'dart:async';

import 'package:google_fonts/google_fonts.dart';

/// Runs before every test file (Flutter picks it up by name).
///
/// Fonts come from the test font, never from fonts.gstatic.com: the run stays
/// offline and gives the same result twice.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  await testMain();
}
