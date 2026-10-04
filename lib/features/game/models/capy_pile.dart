import 'balance.dart';
import 'capybara.dart';
import 'multipliers/capy_role.dart';

/// How a capy grows in its pile right now (spec 006, Т3).
enum PileGrowKind {
  /// Not growing: on its own, the eldest over babies, or a pair of peers.
  none,

  /// Younger than the eldest: grows toward the eldest's level.
  catchUp,

  /// Three or more at the eldest level: all of them grow up.
  peers,
}

/// The pile rules as pure functions (spec 006). A pile is every capy of one
/// meadow with the same [Capybara.pileId]; it takes one place.
abstract final class CapyPiles {
  /// Places on the meadow: each single capy and each pile take one.
  static int placesOf(Iterable<Capybara> herd) {
    var singles = 0;
    final piles = <String>{};
    for (final c in herd) {
      final p = c.pileId;
      if (p == null) {
        singles++;
      } else {
        piles.add(p);
      }
    }
    return singles + piles.length;
  }

  /// Pile id → members, in herd order (piles in order of first member).
  static Map<String, List<Capybara>> groups(Iterable<Capybara> herd) {
    final out = <String, List<Capybara>>{};
    for (final c in herd) {
      final p = c.pileId;
      if (p != null) out.putIfAbsent(p, () => []).add(c);
    }
    return out;
  }

  static List<Capybara> membersOf(Iterable<Capybara> herd, String pileId) => [
    for (final c in herd)
      if (c.pileId == pileId) c,
  ];

  /// A pile of one dissolves; capys over [BalanceV0.pileMaxSize] stand up
  /// (a damaged save). Nothing to do → the same list comes back.
  static List<Capybara> sanitize(List<Capybara> herd) {
    final counts = <String, int>{};
    for (final c in herd) {
      final p = c.pileId;
      if (p != null) counts[p] = (counts[p] ?? 0) + 1;
    }
    if (counts.values.every((n) => n >= 2 && n <= BalanceV0.pileMaxSize)) {
      return herd;
    }
    final seen = <String, int>{};
    return [
      for (final c in herd)
        if (c.pileId case final p?)
          (counts[p]! < 2 ||
                  (seen[p] = (seen[p] ?? 0) + 1) > BalanceV0.pileMaxSize)
              ? c.copyWith(clearPile: true)
              : c
        else
          c,
    ];
  }

  /// How [capy] grows among [members] (its pile, itself included).
  static PileGrowKind growKind(Capybara capy, List<Capybara> members) {
    if (capy.pileId == null || members.length < 2) return PileGrowKind.none;
    var top = 0;
    for (final m in members) {
      if (m.level > top) top = m.level;
    }
    if (capy.level < top) return PileGrowKind.catchUp;
    var peers = 0;
    for (final m in members) {
      if (m.level == top) peers++;
    }
    return peers >= 3 ? PileGrowKind.peers : PileGrowKind.none;
  }

  /// Seconds for one step of [kind] at [level].
  static double stepSeconds(PileGrowKind kind, int level) => switch (kind) {
    PileGrowKind.catchUp => BalanceV0.pileCatchUpSeconds(level),
    PileGrowKind.peers => BalanceV0.pilePeerSeconds(level),
    PileGrowKind.none => double.infinity,
  };

  /// Speed of a pile: a nanny in it makes everyone grow faster.
  static double speedOf(List<Capybara> members) {
    for (final m in members) {
      if (m.role == CapyRole.nanya) return 1 + BalanceV0.pileNanyaGrowBonus;
    }
    return 1;
  }

  /// True when someone in [herd] would grow now.
  static bool anyGrowing(List<Capybara> herd) {
    for (final members in groups(herd).values) {
      for (final c in members) {
        if (growKind(c, members) != PileGrowKind.none) return true;
      }
    }
    return false;
  }

  /// [dt] seconds of growth for every pile in [herd]. A capy reaching the
  /// next level stops there for this call (one step at a time; the rest of
  /// the step is not carried over). [grown] lists who went up, in herd order.
  /// Nobody grew or gained → the same list comes back.
  static ({List<Capybara> herd, List<String> grown}) grow(
    List<Capybara> herd,
    double dt,
  ) {
    if (dt <= 0) return (herd: herd, grown: const []);
    final piles = groups(herd);
    if (piles.isEmpty) return (herd: herd, grown: const []);
    final changed = <String, Capybara>{};
    final grown = <String>[];
    for (final members in piles.values) {
      final speed = speedOf(members);
      for (final c in members) {
        final kind = growKind(c, members);
        if (kind == PileGrowKind.none) continue;
        final g = c.growth + dt / stepSeconds(kind, c.level) * speed;
        if (g >= 1) {
          changed[c.id] = c.copyWith(level: c.level + 1, growth: 0);
          grown.add(c.id);
        } else {
          changed[c.id] = c.copyWith(growth: g);
        }
      }
    }
    if (changed.isEmpty) return (herd: herd, grown: const []);
    final next = [for (final c in herd) changed[c.id] ?? c];
    // Herd order, not pile order.
    final order = [
      for (final c in herd)
        if (grown.contains(c.id)) c.id,
    ];
    return (herd: next, grown: order);
  }
}
