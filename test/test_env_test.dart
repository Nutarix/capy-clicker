import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  test('google_fonts never fetches over the network in tests', () {
    // Set once for the whole run in test/flutter_test_config.dart.
    expect(GoogleFonts.config.allowRuntimeFetching, isFalse);
  });
}
