import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Flutter getters that only answer in a debug build. In profile / release
/// they return a fixed value (`debugIsActive` is always false), so game logic
/// that reads them behaves differently on a phone (spec 003, Т1, Т15).
const _debugOnly = <String>[
  'debugIsActive',
  'debugIsDefunct',
  'debugIsMounted',
  'debugDisposed',
  'debugNeedsLayout',
  'debugNeedsPaint',
  'debugNeedsCompositingBitUpdate',
  'debugDoingThisLayout',
  'debugDoingThisPaint',
  'debugDoingThisResize',
  'debugDoingLayout',
  'debugDoingPaint',
  'debugCanParentUseSize',
  'debugLayer',
  'debugCreator',
  'debugIsSerializableForRestoration',
];

void main() {
  test('lib/ reads no debug-only Flutter getters (Т15)', () {
    final pattern = RegExp('\\b(${_debugOnly.join('|')})\\b');
    final hits = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    for (final file in files) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final code = line.split('//').first;
        if (pattern.hasMatch(code)) {
          hits.add('${file.path}:${i + 1}: ${line.trim()}');
        }
      }
    }
    expect(hits, isEmpty, reason: hits.join('\n'));
  });
}
