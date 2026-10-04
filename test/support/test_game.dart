import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import 'package:capy_clicker/features/game/controllers/game_controller.dart';
import 'package:capy_clicker/features/game/models/balance.dart';
import 'package:capy_clicker/features/game/models/capy_pile.dart';
import 'package:capy_clicker/features/game/models/capybara.dart';
import 'package:capy_clicker/features/game/models/multipliers/capy_role.dart';
import 'package:capy_clicker/features/game/persistence/game_persistence.dart';

/// Still instant for controller tests: no real clock, no midnight.
final DateTime testNow = DateTime(2026, 9, 21, 12);

/// Controller for unit tests: seeded randomness, still clock, no live tick.
///
/// Drive the game clock with [GameController.debugAdvance]. Tests of the live
/// tick build their own controller under fake time (see game_tick_test.dart).
GameController testController({
  GamePersistence? persistence,
  Random? random,
  int seed = 1,
  DateTime Function()? now,
  bool debugNames = true,
}) {
  return GameController(
    persistence: persistence ?? GamePersistence(),
    random: random ?? Random(seed),
    now: now ?? () => testNow,
    autoTick: false,
    debugNames: debugNames,
  );
}

/// Save key of [GamePersistence].
const testSaveKey = 'capy_clicker_game_state_v1';

/// A save holding [herd] on the starter meadow, written at [testNow] (no
/// offline grant on load). [extra] fields go to the top of the save.
Map<String, Object> herdSave(
  List<Capybara> herd, {
  Map<String, Object?> extra = const {},
  DateTime? savedAt,
}) {
  return {
    testSaveKey: jsonEncode({
      'herdProgress': 0.0,
      'nextId': 100,
      'savedAtMs': (savedAt ?? testNow).millisecondsSinceEpoch,
      'herd': [for (final c in herd) c.toJson()],
      ...extra,
    }),
  };
}

/// Capy for test herds.
Capybara testCapy(
  String id,
  int level, {
  double x = 0.5,
  double y = 0.72,
  String? pile,
  double growth = 0,
  CapyRole? role,
}) => Capybara(
  id: id,
  level: level,
  position: Offset(x, y),
  pileId: pile,
  growth: growth,
  role: role,
);

/// One move of a sensible player (spec 006): the youngest single sits where
/// it will grow — a nursery with an elder above it, else peers of its level,
/// else next to another single. With no singles left and every place taken,
/// a small pile moves into a bigger one (frees a place). True if a move was
/// made.
bool pileStep(GameController c) {
  final herd = c.state.herd;
  final piles = CapyPiles.groups(herd);
  final singles = [
    for (final x in herd)
      if (x.pileId == null) x,
  ]..sort((a, b) => a.level.compareTo(b.level));

  int top(List<Capybara> m) => m.map((x) => x.level).reduce(max);

  String? pileFor(Capybara s, {String? notPile}) {
    final open = [
      for (final e in piles.entries)
        if (e.key != notPile && e.value.length < BalanceV0.pileMaxSize) e,
    ];
    // A nursery: the elder above, the most room first.
    final nursery = open.where((e) => top(e.value) > s.level).toList()
      ..sort((a, b) => a.value.length.compareTo(b.value.length));
    if (nursery.isNotEmpty) return nursery.first.value.first.id;
    final peers = open.where((e) => top(e.value) == s.level).toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));
    if (peers.isNotEmpty) return peers.first.value.first.id;
    return null;
  }

  for (final s in singles) {
    final target = pileFor(s);
    if (target != null) return c.joinPile(s.id, target);
  }
  if (singles.length >= 2) {
    // Two singles start a pile: the youngest with the oldest.
    return c.joinPile(singles.first.id, singles.last.id);
  }
  if (c.placesUsed < c.effectiveMaxHerdSize) return false;
  // Every place taken by piles: the smallest pile's youngest moves on.
  final small = piles.entries
      .where((e) => e.value.length < BalanceV0.pileMaxSize)
      .toList()
    ..sort((a, b) => a.value.length.compareTo(b.value.length));
  for (final e in small) {
    final young = e.value.reduce((a, b) => a.level <= b.level ? a : b);
    final target = pileFor(young, notPile: e.key);
    if (target != null) return c.joinPile(young.id, target);
  }
  // Nothing sensible: any pile with room takes the smallest pile's youngest.
  for (final e in small) {
    final young = e.value.reduce((a, b) => a.level <= b.level ? a : b);
    for (final o in small) {
      if (o.key == e.key) continue;
      if (c.joinPile(young.id, o.value.first.id)) return true;
    }
  }
  return false;
}

/// Spawn, pile and let piles grow until [done] (spec 006: power no longer
/// comes from merges). The game clock runs only while every place is taken.
void growFamily(
  GameController c,
  bool Function() done, {
  int rounds = 4000,
}) {
  for (var i = 0; i < rounds && !done(); i++) {
    if (c.placesUsed < c.effectiveMaxHerdSize) {
      c.addProgress(1.0, fromTap: false);
    } else if (!pileStep(c)) {
      c.debugAdvance(20);
    }
  }
}

/// The marked «хотят посидеть рядом» pair sits together when there is room.
bool sitThePair(GameController c) {
  final a = c.state.twinIdA;
  final b = c.state.twinIdB;
  if (a == null || b == null) return false;
  return c.joinPile(a, b) || c.joinPile(b, a);
}

/// The nanny goes to the pile with the highest eldest (it speeds that pile).
/// Returns true when the nanny moved.
bool nannyToTopPile(GameController c) {
  final piles = CapyPiles.groups(c.state.herd).values.toList();
  if (piles.isEmpty) return false;
  int top(List<Capybara> m) => m.map((x) => x.level).reduce(max);
  piles.sort((x, y) => top(y).compareTo(top(x)));
  final pile = piles.first;
  if (pile.any((x) => x.role == CapyRole.nanya)) return false;
  final eldest = pile.reduce((x, y) => x.level >= y.level ? x : y);
  if (eldest.role != null) return false;
  c.clearRole(CapyRole.nanya);
  return c.assignRole(eldest.id, CapyRole.nanya);
}
