import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../core/game_core.dart';
import '../core/game_events.dart';
import '../core/goals.dart';
import '../models/capybara.dart';
import '../models/game_state.dart';
import '../models/multipliers/multipliers.dart';
import '../models/session_goals.dart';
import '../models/world_zones.dart';
import '../persistence/game_persistence.dart';

export '../core/game_events.dart';

/// The one entry point of the game for the screen and tests.
///
/// A facade: the rules live in parts under `core/` (clock, herd, pile,
/// meadows, shop, goals, lands, save…), sharing one [GameCore].
class GameController extends ChangeNotifier {
  GameController({
    GamePersistence? persistence,
    Random? random,
    DateTime Function()? now,
    this.autoTick = true,
    @visibleForTesting bool debugNames = true,
  }) {
    _core = GameCore(
      persistence: persistence ?? GamePersistence(),
      random: random ?? Random(),
      // Separate stream so food/loot drops do not desync core progression RNG.
      lootRandom: Random(0xC4A7F00D),
      now: now ?? DateTime.now,
      autoTick: autoTick,
      onNotify: notifyListeners,
      namesEnabled: debugNames,
    );
  }

  late final GameCore _core;

  /// False: no periodic tick — tests drive the game clock via [debugAdvance].
  final bool autoTick;

  GameState get state => _core.state;
  bool get isReady => _core.ready;

  // --- Rates ---

  /// Live auto fill rate (fraction/sec) — full stack for HUD «+X%/с».
  double get autoRatePerSecond => _core.rates.autoRatePerSecond;
  /// Places on the meadow (spec 006, Т5): a single capy or a pile is one.
  /// Name kept from before the pile.
  int get effectiveMaxHerdSize => _core.rates.effectiveMaxHerdSize;

  /// Places taken on the active meadow.
  int get placesUsed => _core.herd.placesUsed;
  double get effectiveMagnetRadius => _core.rates.effectiveMagnetRadius;

  /// Live RU summary of active role bonuses for Уют / HUD.
  String get activeRoleBonusesRu => _core.rates.activeRoleBonusesRu;

  double get cameraZoom => _core.herd.cameraZoom;

  // --- Temporary boosts ---

  bool get isMudBoostActive => _core.boosts.isMudBoostActive;
  double get mudBoostRemainingSeconds => _core.boosts.mudBoostRemainingSeconds;
  bool get isGrassBoostActive => _core.boosts.isGrassBoostActive;
  double get grassBoostRemainingSeconds =>
      _core.boosts.grassBoostRemainingSeconds;

  bool get isFoodBoostActive => _core.boosts.isFoodBoostActive;
  double get foodBoostRemainingSeconds =>
      _core.boosts.foodBoostRemainingSeconds;
  FamilyFood? get activeFoodBoost => _core.boosts.activeFoodBoost;
  bool get isPlaceBoostActive => _core.boosts.isPlaceBoostActive;
  double get placeBoostRemainingSeconds =>
      _core.boosts.placeBoostRemainingSeconds;
  CozyPlaceKind? get activePlaceBoost => _core.boosts.activePlaceBoost;
  bool isPlaceOnCooldown(CozyPlaceKind kind) =>
      _core.boosts.isPlaceOnCooldown(kind);
  double placeCooldownRemaining(CozyPlaceKind kind) =>
      _core.boosts.placeCooldownRemaining(kind);

  // --- Meadow life: puddle, berries, pile flash ---

  String? get wallowingCapyId => _core.puddle.wallowingCapyId;

  /// Everyone in the bath now: one capy or a pile (spec 006, С8).
  Set<String> get wallowingIds => _core.puddle.wallowingIds;
  bool get isBerryVisible => _core.finds.berryVisible;

  /// Capy that just sat in a pile or grew (flash).
  String? get pileFlashId => _core.pile.flashId;

  /// Live puddle, or null while it is despawned. Not part of [GameState].
  bool get mudVisible => _core.puddle.present;
  Offset? get mudCenter => _core.puddle.present ? _core.puddle.center : null;

  /// Tests: plant a puddle with a known center and lifetime.
  @visibleForTesting
  void debugPlaceMud(Offset center, {double seconds = 3}) =>
      _core.puddle.debugPlace(center, seconds: seconds);

  // --- One-shot messages ---

  /// Puddle, new glade, goal, role, offline welcome, daily gift — once each,
  /// right after the change notice that brought them (see [GameEvent]).
  Stream<GameEvent> get events => _core.messages.events;

  /// Pending «Солнечные поляны» unlock line (e.g. «Открылась Ягодная поляна»).
  String? get gladeUnlockToast => _core.messages.gladeUnlockToast;

  /// Grass granted with the last glade unlock (0 if none).
  int get lastGladeGrassReward => _core.messages.lastGladeGrassReward;

  /// Clear unlock toast after the UI shows it (once).
  void acknowledgeGladeUnlock() => _core.messages.acknowledgeGladeUnlock();

  /// One-shot «Лужа!» when a puddle appears. UI must acknowledge.
  String? get puddleToast => _core.messages.puddleToast;

  void acknowledgePuddleToast() => _core.messages.acknowledgePuddle();

  /// Pending session-goal celebration line.
  String? get goalCompleteToast => _core.messages.goalCompleteToast;

  void acknowledgeGoalComplete() => _core.messages.acknowledgeGoalComplete();

  /// Offline grant from this session's [init] (consume once for UI).
  double get offlineProgressGranted => _core.messages.offlineProgressGranted;
  int get offlineSecondsApplied => _core.messages.offlineSecondsApplied;
  bool get hasOfflineWelcome => _core.messages.hasOfflineWelcome;

  /// Clear the one-shot offline welcome flag after UI shows it.
  void acknowledgeOfflineWelcome() =>
      _core.messages.acknowledgeOfflineWelcome();

  // --- Goals and the daily gift ---

  /// Current session goal, or null when the sequence is finished.
  SessionGoal? get currentSessionGoal => _core.goals.currentSessionGoal;

  /// 0–1 progress toward [currentSessionGoal].
  double get sessionGoalProgress => _core.goals.sessionGoalProgress;

  /// Soft daily tip tied to the active goal.
  String get dailyGoalHintRu => _core.goals.dailyGoalHintRu;

  /// Local calendar day key `YYYY-MM-DD` for [instant].
  static String calendarDayKey(DateTime instant) =>
      GameGoals.calendarDayKey(instant);

  /// Soft daily gift available (once per local calendar day, not claimed yet).
  bool get isDailyBonusAvailable => _core.goals.isDailyBonusAvailable;

  /// Claim today's soft daily. Returns false if already claimed today.
  bool claimDailyBonus() => _core.goals.claimDailyBonus();

  // --- Meadows ---

  /// Active named meadow (fixed Sunny Glade identity — Phase 2 forest map).
  SunnyGlade get currentGlade => _core.meadows.currentGlade;

  /// Meadow ids unlocked so far (forest map chips).
  List<String> get unlockedMeadowIds => _core.meadows.unlockedMeadowIds;

  /// Herd size on a meadow (active uses live fields).
  int herdCountForMeadow(String meadowId) =>
      _core.meadows.herdCountForMeadow(meadowId);

  /// Forest map: switch playable meadow. Shared grass stays; herd restores.
  bool switchToMeadow(String meadowId) =>
      _core.meadows.switchToMeadow(meadowId);

  // --- Session and clock ---

  /// Load save (or bootstrap), grant capped offline progress, start ticker.
  Future<void> init() => _core.init();

  /// True while the app is in background (see [suspend]).
  bool get isSuspended => _core.clock.isSuspended;

  /// Write the save now instead of on the next interval.
  /// Nothing before load finished or after [dispose].
  Future<void> flushSave() => _core.save.flush();

  /// App hidden: stop the game clock and write the save («left at»).
  Future<void> suspend() => _core.clock.suspend();

  /// App back on screen: offline grant, then the live clock resumes.
  void resumeFromBackground() => _core.clock.resumeFromBackground();

  /// Headless tick for progression sims: the live tick body, any [dt].
  @visibleForTesting
  void debugAdvance(double dt) => _core.clock.debugAdvance(dt);

  // --- Family: progress, taps, merge, positions ---

  /// Add progress; may spawn while under herd cap. Overflow carries over.
  void addProgress(double amount, {required bool fromTap}) =>
      _core.herd.addProgress(amount, fromTap: fromTap);

  /// Returns progress fraction granted (for floating «+N%» feedback).
  double onFlowerTap() => _core.finds.onFlowerTap();

  /// Returns progress fraction granted, or null if basket not visible.
  double? onBerryTap() => _core.finds.onBerryTap();

  /// Grass granted by the most recent flower/berry tap (for UI float).
  int get lastTapGrass => _core.finds.lastTapGrass;

  /// Last food granted by flower/buy (UI float); null if none.
  FamilyFood? get lastDroppedFood => _core.finds.lastDroppedFood;

  /// Force berry visible (tests / sims).
  @visibleForTesting
  void debugShowBerry() => _core.finds.debugShowBerry();

  /// Drop a capybara onto the mud puddle → wallow anim + temporary boost.
  bool tryMudWallow(String capyId) => _core.puddle.tryWallow(capyId);

  /// True if [normalized] is inside the mud puddle hit circle.
  bool isOverMud(Offset normalized) => _core.puddle.isOverMud(normalized);

  /// Drop [draggedId] on [targetId] (spec 006, Т1): they sit in a pile.
  /// False when nothing changed, or the target's pile already holds four —
  /// then the dragged capy stands beside it on the grass (С4).
  bool joinPile(String draggedId, String targetId) =>
      _core.pile.join(draggedId, targetId);

  /// Members of [pileId] on the active meadow, in herd order.
  List<Capybara> pileMembers(String pileId) => _core.pile.membersOf(pileId);

  /// Force a «хотят посидеть рядом» pair mark (tests).
  @visibleForTesting
  void debugMarkTwins(String a, String b) => _core.pile.debugMarkTwins(a, b);

  /// Move a capy. One from a pile stands up there (spec 006, С5).
  void updatePosition(String id, Offset normalized) =>
      _core.herd.updatePosition(id, normalized);

  // --- Names (spec 004) ---

  /// The player's own name for a named capy, on any meadow of this land.
  /// Trimmed, up to 16 characters; empty → false, the old name stays.
  bool renameCapy(String capyId, String name) =>
      _core.names.rename(capyId, name);

  // --- Spending ---

  FamilyFood get selectedFood => _core.shop.selectedFood;
  void selectFood(FamilyFood food) => _core.shop.selectFood(food);

  /// Spend grass to spawn a Lv.1 capy if a place is free.
  bool spendCallCapy() => _core.shop.spendCallCapy();

  /// Spend grass for a short auto-progress boost (weaker than mud).
  bool spendGrassBoost() => _core.shop.spendGrassBoost();

  bool get canCallCapy => _core.shop.canCallCapy;

  /// Why «Позвать капи» is gray. Null while the call is available.
  String? get callCapyBlockedReason => _core.shop.callCapyBlockedReason;

  bool get canGrassBoost => _core.shop.canGrassBoost;

  /// Convert grass into one food unit of [food].
  bool buyFood(FamilyFood food) => _core.shop.buyFood(food);

  /// Feed selected / given food to the family (temporary boost).
  bool feedFamily([FamilyFood? food]) => _core.shop.feedFamily(food);

  bool get canFeedSelected => _core.shop.canFeedSelected;

  /// Drag capy onto place OR tap place → activate (with cooldown).
  bool tryActivatePlace(
    CozyPlaceKind kind, {
    String? capyId,
    Offset? standAt,
  }) => _core.shop.tryActivatePlace(kind, capyId: capyId, standAt: standAt);

  /// Buy a decor item if affordable and research-unlocked.
  bool buyDecor(HomeDecor decor) => _core.shop.buyDecor(decor);

  bool togglePlaceDecor(HomeDecor decor) => _core.shop.togglePlaceDecor(decor);

  /// Unlock a research node if prereqs + cost met.
  bool unlockResearch(String nodeId) => _core.shop.unlockResearch(nodeId);

  // --- Roles ---

  /// Assign [role] to capy; respects role slot limit. Null clears.
  bool assignRole(String capyId, CapyRole? role) =>
      _core.roles.assignRole(capyId, role);

  /// Give [role] to the first capy on this meadow who has none.
  bool assignRoleToFreeCapy(CapyRole role) =>
      _core.roles.assignRoleToFreeCapy(role);

  /// Take [role] off whoever holds it, on any meadow of this land.
  bool clearRole(CapyRole role) => _core.roles.clearRole(role);

  // --- Rocket and lands ---

  /// Newest chapter (not a visit back to an older land).
  bool get playingNewestLand => _core.lands.playingNewestLand;

  /// Mist unlocked and visited, a spark, someone stays home.
  bool get rocketUnlocked => _core.lands.rocketUnlocked;

  bool get hasLandsGallery => _core.lands.hasLandsGallery;

  /// Arrival meadow: the newest land, before its own glades open.
  bool get onFreshNewLand => _core.lands.onFreshNewLand;

  /// Who the rocket would take now (the youngest). Null when nobody is home.
  Capybara? get nextTraveler => _core.lands.nextTraveler;

  /// The traveler's name for the rocket chapter; null for a baby (Т10).
  String? get nextTravelerName => nextTraveler?.displayNameRu;

  /// Send the youngest capy on. Grass and sparks stay. Old land is archived.
  bool launchToNewLand() => _core.lands.launchToNewLand();

  /// Swap the live land with an archived one. Nothing is deleted.
  bool visitLand(int chapter) => _core.lands.visitLand(chapter);

  @override
  void dispose() {
    _core.dispose();
    super.dispose();
  }
}
