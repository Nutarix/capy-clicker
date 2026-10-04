import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:capy_clicker/features/game/controllers/game_controller.dart';
import 'package:capy_clicker/features/game/models/multipliers/cozy_place.dart';
import 'package:capy_clicker/features/game/models/world_zones.dart';

/// Behavior fingerprint (spec 002, Т12).
///
/// Collects the state and the public getters at named steps and compares the
/// lines with `test/fixtures/fingerprint/<name>.jsonl` byte for byte. Taken
/// before the core split; a difference means the game behaves differently.
///
/// Write the files anew only on purpose (balance or rule change):
/// `CAPY_FINGERPRINT_UPDATE=1 flutter test`.
///
/// Spec 004 rewrote them once for the capy name fields only; proof:
/// `python tool/fingerprint_names_diff.py main` (the rest is byte-identical).
/// Spec 006 rewrote them for the pile (rules and balance changed); the
/// expected differences are listed in `specs/006-kuchka/plan.md`, check:
/// `python tool/fingerprint_pile_diff.py main`.
class Fingerprint {
  Fingerprint(this.name);

  final String name;
  final List<String> _lines = [];

  /// Full probe of [c] at [step].
  void mark(
    String step,
    GameController c, {
    Map<String, Object?> extra = const {},
  }) {
    _lines.add(
      jsonEncode({
        'step': step,
        ...probe(c),
        if (extra.isNotEmpty) 'extra': extra,
      }),
    );
  }

  /// Plain data at [step] (prefs blobs, counters).
  void note(String step, Map<String, Object?> data) {
    _lines.add(jsonEncode({'step': step, ...data}));
  }

  void verify() {
    final file = File('test/fixtures/fingerprint/$name.jsonl');
    final actual = '${_lines.join('\n')}\n';
    if (Platform.environment['CAPY_FINGERPRINT_UPDATE'] == '1') {
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(actual);
      return;
    }
    expect(file.existsSync(), isTrue, reason: 'no fingerprint ${file.path}');
    final expected = file.readAsStringSync().replaceAll('\r\n', '\n');
    if (expected == actual) return;
    final want = expected.split('\n');
    final got = actual.split('\n');
    for (var i = 0; i < want.length || i < got.length; i++) {
      final w = i < want.length ? want[i] : '<none>';
      final g = i < got.length ? got[i] : '<none>';
      if (w == g) continue;
      fail(
        'fingerprint $name differs at line ${i + 1}\n'
        'want: ${_clip(w)}\n'
        'got:  ${_clip(g)}\n'
        '${_firstKeyDiff(w, g)}',
      );
    }
  }

  static String _clip(String s) =>
      s.length > 400 ? '${s.substring(0, 400)}…' : s;

  static String _firstKeyDiff(String want, String got) {
    try {
      final w = jsonDecode(want) as Map<String, dynamic>;
      final g = jsonDecode(got) as Map<String, dynamic>;
      final diffs = <String>[];
      for (final k in {...w.keys, ...g.keys}) {
        if (jsonEncode(w[k]) != jsonEncode(g[k])) diffs.add(k);
      }
      return 'keys: $diffs';
    } catch (_) {
      return '';
    }
  }
}

/// Probe points for hit tests (mud). Normalized meadow space.
const _probePoints = <Offset>[
  Offset(0.48, 0.84),
  Offset(0.30, 0.70),
  Offset(0.20, 0.62),
  Offset(0.72, 0.80),
];

List<double>? _offset(Offset? o) => o == null ? null : [o.dx, o.dy];

/// State JSON plus every public getter a player can feel.
///
/// Left out on purpose: `lastRoleToast` / `acknowledgeRoleToast` and the
/// controller's own `placeAt` / `isOverPlace` — read by no screen or test and
/// slated for removal in spec 002 (see plan.md).
Map<String, Object?> probe(GameController c) {
  final s = c.state;
  final meadowIds = <String>{
    ...s.meadows.keys,
    for (final g in WorldZones.glades) g.id,
    WorldZones.mistEdgeMeadowId,
  };
  return {
    'state': s.toJson(),
    'ready': c.isReady,
    'suspended': c.isSuspended,
    'autoRate': c.autoRatePerSecond,
    'zoom': c.cameraZoom,
    'maxHerd': c.effectiveMaxHerdSize,
    'placesUsed': c.placesUsed,
    'magnet': c.effectiveMagnetRadius,
    'mudBoost': [c.isMudBoostActive, c.mudBoostRemainingSeconds],
    'grassBoost': [c.isGrassBoostActive, c.grassBoostRemainingSeconds],
    'foodBoost': [c.isFoodBoostActive, c.foodBoostRemainingSeconds],
    'placeBoost': [
      c.isPlaceBoostActive,
      c.placeBoostRemainingSeconds,
      c.activePlaceBoost?.name,
    ],
    'activeFood': c.activeFoodBoost?.name,
    'places': {
      for (final k in CozyPlaceKind.values)
        k.name: [c.isPlaceOnCooldown(k), c.placeCooldownRemaining(k)],
    },
    'wallowing': c.wallowingCapyId,
    'berry': c.isBerryVisible,
    'flash': c.pileFlashId,
    'mud': [c.mudVisible, _offset(c.mudCenter)],
    'overMud': [for (final p in _probePoints) c.isOverMud(p)],
    'gladeToast': c.gladeUnlockToast,
    'gladeGrass': c.lastGladeGrassReward,
    'goalToast': c.goalCompleteToast,
    'puddleToast': c.puddleToast,
    'offline': [
      c.hasOfflineWelcome,
      c.offlineProgressGranted,
      c.offlineSecondsApplied,
    ],
    'goal': c.currentSessionGoal?.id,
    'goalProgress': c.sessionGoalProgress,
    'dailyHint': c.dailyGoalHintRu,
    'daily': c.isDailyBonusAvailable,
    'glade': c.currentGlade.id,
    'unlocked': c.unlockedMeadowIds,
    'herdCounts': {for (final id in meadowIds) id: c.herdCountForMeadow(id)},
    'roles': c.activeRoleBonusesRu,
    'selectedFood': c.selectedFood.name,
    'canFeed': c.canFeedSelected,
    'canCall': c.canCallCapy,
    'callBlocked': c.callCapyBlockedReason,
    'canBoost': c.canGrassBoost,
    'tapGrass': c.lastTapGrass,
    'droppedFood': c.lastDroppedFood?.name,
    'newestLand': c.playingNewestLand,
    'rocket': c.rocketUnlocked,
    'lands': c.hasLandsGallery,
    'freshLand': c.onFreshNewLand,
  };
}
