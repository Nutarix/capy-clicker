import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/cozy_theme.dart';

import 'package:flutter/services.dart';

import 'audio/game_audio.dart';
import 'controllers/game_controller.dart';
import 'models/balance.dart';
import 'models/capy_wander.dart';
import 'models/meadow_occupancy.dart';
import 'models/session_goals.dart';
import 'models/world_zones.dart';
import 'persistence/game_persistence.dart';
import 'widgets/berry_basket.dart';
import 'widgets/draggable_capybara.dart';
import 'widgets/flower_dot.dart';
import 'widgets/floating_gain.dart';
import 'widgets/forest_map_overlay.dart';
import 'widgets/meadow_background.dart';
import 'widgets/meadow_decor.dart';
import 'widgets/placed_home_decor.dart';
import 'widgets/mud_puddle.dart';
import 'widgets/grass_spend_panel.dart';
import 'widgets/quiet_merge_arc.dart';
import 'widgets/rocket_chapter.dart';
import 'widgets/morning_cozy_sheet.dart';
import 'widgets/tip_overlay.dart';
import 'widgets/uyut/cozy_place_marker.dart';
import 'widgets/uyut/uyut_hub_sheet.dart';
import 'models/multipliers/multipliers.dart';

/// Live game screen: auto progress, flowers, herd, merge, mud, berries, zoom.
class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    this.controller,
    this.audio,
    this.persistence,
    this.now,
    this.onBackToMenu,
  });

  /// Optional injected controller (tests / DI).
  final GameController? controller;

  /// Optional audio (pass [GameAudio.silent] / `silent: true` in tests).
  final GameAudio? audio;

  /// Save store for the owned controller. The app shares its own with the
  /// menu, so a save on the way out lands before «Заново» clears it.
  final GamePersistence? persistence;

  /// Game clock for the owned controller (tests pin it; null = wall clock).
  final DateTime Function()? now;

  /// Soft pause / return to main menu (save is flushed on dispose).
  final VoidCallback? onBackToMenu;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final GameController _controller;
  late final bool _ownsController;
  late final GameAudio _audio;
  late final bool _ownsAudio;
  final GlobalKey _meadowKey = GlobalKey();
  bool _offlineWelcomeShown = false;
  bool _dailyPromptShown = false;
  bool _dailySheetOpen = false;

  /// Soft-magnet target while a capy is being dragged (glow on attracted).
  String? _magnetAttractedId;

  /// Floating «+N%» / «×2» popups.
  final List<FloatingGainEvent> _floats = [];
  int _floatSeq = 0;

  /// Soft first-appearance hint on berry basket (session).
  bool _berryHintSeen = false;

  /// Forest map overlay visible.
  bool _forestMapOpen = false;

  _RocketPhase _rocketPhase = _RocketPhase.none;
  bool _landsOpen = false;

  /// Capy ids that should show a prominent Lv badge (drag / recent merge).
  final Set<String> _badgePromoted = {};
  Timer? _badgeClearTimer;

  /// Colors paired with [WorldZones.flowerPositions] (meadow grass only).
  static const _flowerColors = <Color>[
    Color(0xFFE87AA0),
    Color(0xFFF0C040),
    Color(0xFF9B6BDE),
    Color(0xFFE85A5A),
    Color(0xFF5AB8E8),
  ];

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller =
        widget.controller ??
        GameController(persistence: widget.persistence, now: widget.now);
    _ownsAudio = widget.audio == null;
    _audio = widget.audio ?? GameAudio();
    _audio.addListener(_onAudioChanged);
    _controller.addListener(_onControllerChanged);
    _controller.init();
    _audio.init();
  }

  void _onAudioChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _onControllerChanged() {
    if (!mounted) return;
    setState(() {});
    _maybeShowOfflineWelcome();
    _maybeShowDailyBonus();
    _maybeShowGladeUnlock();
    _maybeShowPuddle();
    _maybeShowGoalComplete();
  }

  void _maybeShowGladeUnlock() {
    final msg = _controller.gladeUnlockToast;
    if (msg == null || msg.isEmpty) return;
    final grassReward = _controller.lastGladeGrassReward;
    _controller.acknowledgeGladeUnlock();
    _audio.playGlade();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          backgroundColor: const Color(0xFF5A9A48).withValues(alpha: 0.94),
          content: Row(
            children: [
              const Text('☀️', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  grassReward > 0 ? '$msg · +$grassReward🌿' : msg,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  void _maybeShowPuddle() {
    final msg = _controller.puddleToast;
    if (msg == null || msg.isEmpty) return;
    _controller.acknowledgePuddleToast();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFF8B5A2B).withValues(alpha: 0.94),
          content: const Text(
            'Лужа!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    });
  }

  void _maybeShowGoalComplete() {
    final msg = _controller.goalCompleteToast;
    if (msg == null || msg.isEmpty) return;
    _controller.acknowledgeGoalComplete();
    _audio.playGlade();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          backgroundColor: const Color(0xFFC47820).withValues(alpha: 0.94),
          content: Row(
            children: [
              const Text('✨', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  msg,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  void _maybeShowOfflineWelcome() {
    if (_offlineWelcomeShown) return;
    if (!_controller.isReady || !_controller.hasOfflineWelcome) return;
    _offlineWelcomeShown = true;
    final seconds = _controller.offlineSecondsApplied;
    final progress = _controller.offlineProgressGranted;
    _controller.acknowledgeOfflineWelcome();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final mins = seconds ~/ 60;
      final secs = seconds % 60;
      final timeLabel = mins > 0 ? '$mins мин $secs с' : '$secs с';
      final bars = (progress / BalanceV0.spawnThreshold).clamp(0.0, 99.0);
      final barsLabel = bars >= 1
          ? '≈${bars.toStringAsFixed(1)} шкалы'
          : '+${(progress * 100).round()}%';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          backgroundColor: const Color(0xFF5C3D1E).withValues(alpha: 0.92),
          content: Text(
            'Пока тебя не было… семья подросла ($timeLabel → $barsLabel)',
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _badgeClearTimer?.cancel();
    _controller.removeListener(_onControllerChanged);
    _audio.removeListener(_onAudioChanged);
    if (_ownsController) {
      _controller.dispose();
    }
    if (_ownsAudio) {
      _audio.dispose();
    }
    super.dispose();
  }

  void _spawnFloat(String label, Offset globalAnchor, {Color? color}) {
    final id = ++_floatSeq;
    setState(() {
      _floats.add(
        FloatingGainEvent(
          id: id,
          label: label,
          globalAnchor: globalAnchor,
          color: color ?? const Color(0xFF5A9A48),
        ),
      );
    });
  }

  void _onFlowerTap(Offset globalAnchor) {
    HapticFeedback.lightImpact();
    unawaited(_audio.noteUserGesture());
    _audio.playFlower();
    final gain = _controller.onFlowerTap();
    final pct = (gain * 100).round().clamp(1, 99);
    final g = _controller.lastTapGrass;
    final food = _controller.lastDroppedFood;
    final foodBit = food != null ? ' · ${food.emoji}' : '';
    _spawnFloat(
      g > 0 ? '+$pct% · +$g🌿$foodBit' : '+$pct%$foodBit',
      globalAnchor,
    );
  }

  void _onBerryTap(Offset globalAnchor) {
    HapticFeedback.mediumImpact();
    unawaited(_audio.noteUserGesture());
    _audio.playBerry();
    final gain = _controller.onBerryTap();
    if (gain == null) return;
    _berryHintSeen = true;
    final pct = (gain * 100).round().clamp(1, 99);
    final g = _controller.lastTapGrass;
    _spawnFloat(
      g > 0 ? '+$pct% · +$g🌿' : '+$pct%',
      globalAnchor,
      color: const Color(0xFFE03A5C),
    );
  }

  void _promoteBadge(String id, {Duration hold = const Duration(seconds: 2)}) {
    setState(() => _badgePromoted.add(id));
    _badgeClearTimer?.cancel();
    _badgeClearTimer = Timer(hold, () {
      if (!mounted) return;
      setState(() => _badgePromoted.clear());
    });
  }

  void _maybeShowDailyBonus() {
    if (_dailyPromptShown || _dailySheetOpen) return;
    if (!_controller.isReady || !_controller.isDailyBonusAvailable) return;
    // Soft: wait a beat so tips / offline snackbar settle first.
    _dailyPromptShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // Delay slightly so first-launch tips can appear above without stacking.
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!mounted || !_controller.isDailyBonusAvailable) return;
      _dailySheetOpen = true;
      final claimed = await MorningCozySheet.show(
        context,
        dailyGoalHint: _controller.dailyGoalHintRu,
        onClaim: () {
          _controller.claimDailyBonus();
        },
      );
      _dailySheetOpen = false;
      if (!mounted) return;
      if (claimed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            backgroundColor: const Color(0xFF5C3D1E).withValues(alpha: 0.92),
            content: Text(
              'Уют получен: +${(BalanceV0.dailyBonusProgress * 100).round()}% прогресса',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        );
      }
      setState(() {});
    });
  }

  Future<void> _openDailyBonusManually() async {
    if (!_controller.isDailyBonusAvailable || _dailySheetOpen) return;
    _dailySheetOpen = true;
    final claimed = await MorningCozySheet.show(
      context,
      dailyGoalHint: _controller.dailyGoalHintRu,
      onClaim: () {
        _controller.claimDailyBonus();
      },
    );
    _dailySheetOpen = false;
    if (!mounted) return;
    if (claimed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFF5C3D1E).withValues(alpha: 0.92),
          content: Text(
            'Уют получен: +${(BalanceV0.dailyBonusProgress * 100).round()}% прогресса',
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
      );
    }
    setState(() {});
  }

  bool _onMerge(String a, String b) {
    final ok = _controller.tryMerge(a, b);
    if (ok) {
      HapticFeedback.mediumImpact();
      unawaited(_audio.noteUserGesture());
      _audio.playMerge();
      final flash = _controller.mergeFlashId;
      if (flash != null) _promoteBadge(flash);
    }
    return ok;
  }

  bool _onMudDrop(String id) {
    final ok = _controller.tryMudWallow(id);
    if (ok) {
      HapticFeedback.lightImpact();
      unawaited(_audio.noteUserGesture());
      _audio.playWallow();
      // Float near puddle center in meadow space.
      final box = _meadowKey.currentContext?.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        final center =
            _controller.mudCenter ??
            const Offset(BalanceV0.mudCenterX, BalanceV0.mudCenterY);
        final local = Offset(
          center.dx * box.size.width,
          center.dy * box.size.height,
        );
        _spawnFloat(
          '×2',
          box.localToGlobal(local),
          color: const Color(0xFFB8860B),
        );
      } else {}
    }
    return ok;
  }

  Offset _meadowOriginGlobal() {
    final ctx = _meadowKey.currentContext;
    // Rocket chrome toggles the column; the previous meadow element can be
    // inactive for the frame that rebuilds it. Do not touch a defunct render
    // object (that throws during layout).
    // Inactive elements still report mounted until the frame finishes.
    if (ctx is! Element || !ctx.debugIsActive) return Offset.zero;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !box.attached) return Offset.zero;
    return box.localToGlobal(Offset.zero);
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.isReady) {
      return const Scaffold(
        body: MeadowBackground(
          child: Center(
            child: CircularProgressIndicator(color: Color(0xFF5A9A48)),
          ),
        ),
      );
    }

    final state = _controller.state;
    final zoom = _controller.cameraZoom;
    final boost = _controller.isMudBoostActive;

    final topInset = MediaQuery.paddingOf(context).top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: CozyTheme.systemOverlay,
      child: Scaffold(
        backgroundColor: CozyTheme.cream,
        body: MeadowBackground(
          meadowId: state.activeMeadowId,
          child: Stack(
            children: [
              Column(
                children: [
                  if (_rocketPhase != _RocketPhase.none)
                    const SizedBox.shrink()
                  else
                    Padding(
                      padding: EdgeInsets.fromLTRB(12, topInset + 6, 12, 4),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8EC)
                              .withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE2CFA8)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: Stack(
                            alignment: Alignment.centerLeft,
                            children: [
                              Row(
                                children: [
                                  MeadowGrassReadout(grass: state.grass),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerRight,
                                        child: Text(
                                          _placeLine(state),
                                          maxLines: 1,
                                          softWrap: false,
                                          textAlign: TextAlign.right,
                                          style: CozyTheme.hudChipStyle(
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (widget.onBackToMenu != null)
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 28,
                                    minHeight: 28,
                                  ),
                                  tooltip: 'Меню',
                                  onPressed: () {
                                    unawaited(_audio.noteUserGesture());
                                    widget.onBackToMenu!();
                                  },
                                  // Kept for the menu test. Transparent so the
                                  // bar is one grass icon and the count.
                                  icon: const Icon(
                                    Icons.pause_rounded,
                                    size: 18,
                                    color: Colors.transparent,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final w = constraints.maxWidth;
                        final h = constraints.maxHeight;
                        final props = MeadowOccupancy.layout(
                          meadow: Size(w, h),
                          herdCount: WorldZones.gladeById(state.activeMeadowId)
                              .minHerd,
                          mud: _controller.mudVisible
                              ? _controller.mudCenter
                              : null,
                          capyAnchors: [for (final c in state.herd) c.position],
                          capyWidths: [
                            for (final c in state.herd)
                              BalanceV0.capySizeForLevel(c.level),
                          ],
                          tentUnlocked: state.tentUnlocked,
                        );

                        return ClipRect(
                          child: AnimatedScale(
                            scale: zoom,
                            duration: const Duration(milliseconds: 450),
                            curve: Curves.easeInOut,
                            alignment: Alignment.center,
                            child: SizedBox(
                              key: _meadowKey,
                              width: w,
                              height: h,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  MeadowDecorLayer(
                                    herdCount: state.herdCount,
                                    meadowSize: Size(w, h),
                                  ),
                                  PlacedHomeDecorLayer(
                                    placedIds: state.placedDecor,
                                    meadowSize: Size(w, h),
                                  ),
                                  // Temporary mud puddle (behind capys). Absent during cooldown.
                                  if (_controller.mudVisible &&
                                      _controller.mudCenter != null)
                                    Positioned(
                                      left:
                                          _controller.mudCenter!.dx * w -
                                          CapyWander.mudAnchorX,
                                      top:
                                          _controller.mudCenter!.dy * h -
                                          CapyWander.mudAnchorY,
                                      child: MudPuddle(
                                        key: ValueKey(
                                          '${_controller.mudCenter!.dx.toStringAsFixed(3)}:'
                                          '${_controller.mudCenter!.dy.toStringAsFixed(3)}',
                                        ),
                                        isWallowing:
                                            _controller.wallowingCapyId != null,
                                        boostActive: boost,
                                      ),
                                    ),
                                  // Cozy places (пень / камень / тент)
                                  ..._buildCozyPlaces(w, h, props),
                                  ...List.generate(props.flowers.length, (i) {
                                    final flower = props.flowers[i];
                                    final fx = flower.dx;
                                    final fy = flower.dy;
                                    return Positioned(
                                      left: fx * w - FlowerDot.hitSize / 2,
                                      top: fy * h - FlowerDot.hitSize / 2,
                                      child: FlowerDot(
                                        color:
                                            _flowerColors[i %
                                                _flowerColors.length],
                                        swayPhase: i / props.flowers.length,
                                        onTap: _onFlowerTap,
                                      ),
                                    );
                                  }),
                                  if (_controller.isBerryVisible)
                                    Positioned(
                                      left: BalanceV0.berryPosX * w - 60,
                                      top: BalanceV0.berryPosY * h - 44,
                                      child: BerryBasket(
                                        onTap: _onBerryTap,
                                        showHint: !_berryHintSeen,
                                      ),
                                    ),
                                  if (_mergePair(state, Size(w, h))
                                      case final pair?)
                                    QuietMergeArc(from: pair.$1, to: pair.$2),
                                  ...state.herd.map((capy) {
                                    final promote =
                                        _badgePromoted.contains(capy.id) ||
                                        _controller.mergeFlashId == capy.id ||
                                        _magnetAttractedId == capy.id;
                                    return MeadowDraggableCapybara(
                                      key: ValueKey(capy.id),
                                      capybara: capy,
                                      herd: state.herd,
                                      // Active glade rect, not body count. Count
                                      // was read as family power and walked them
                                      // off the meadow, then the drop clamp piled
                                      // them back onto one edge.
                                      herdCount: WorldZones.gladeById(
                                        state.activeMeadowId,
                                      ).minHerd,
                                      meadowSize: Size(w, h),
                                      meadowOriginGlobal: _meadowOriginGlobal(),
                                      onMerge: _onMerge,
                                      onDropPosition:
                                          _controller.updatePosition,
                                      onMudDrop: _onMudDrop,
                                      isOverMud: _controller.isOverMud,
                                      isWallowing:
                                          _controller.wallowingCapyId ==
                                          capy.id,
                                      mergeFlash:
                                          _controller.mergeFlashId == capy.id,
                                      twinSparkle: state.isTwinMarked(capy.id),
                                      magnetAttractedId: _magnetAttractedId,
                                      promoteLevelBadge: promote,
                                      magnetRadius:
                                          _controller.effectiveMagnetRadius,
                                      placeAt: (o) {
                                        for (final e in props.places.entries) {
                                          if ((o - e.value).distance <=
                                              BalanceV0.placeHitRadius) {
                                            return e.key;
                                          }
                                        }
                                        return null;
                                      },
                                      mudCenter: _controller.mudCenter,
                                      onPlaceDrop: (id, kind) {
                                        unawaited(_audio.noteUserGesture());
                                        final ok = _controller.tryActivatePlace(
                                          kind,
                                          capyId: id,
                                          standAt: props.places[kind],
                                        );
                                        if (ok) {
                                          _spawnFloat(kind.emoji, Offset.zero);
                                        }
                                        return ok;
                                      },
                                      onLongPress: () {
                                        unawaited(_audio.noteUserGesture());
                                        HapticFeedback.mediumImpact();
                                        UyutHubSheet.show(
                                          context,
                                          controller: _controller,
                                          initialTab: 1,
                                          focusCapyId: capy.id,
                                        );
                                      },
                                      onDragBadge: () => _promoteBadge(capy.id),
                                      onMagnetTargetChanged: (id) {
                                        if (_magnetAttractedId == id) return;
                                        setState(() => _magnetAttractedId = id);
                                      },
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  if (_rocketPhase != _RocketPhase.none)
                    const SizedBox.shrink()
                  else
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        10,
                        4,
                        10,
                        8 + MediaQuery.paddingOf(context).bottom,
                      ),
                      child: GrassSpendPanel(
                        grass: state.grass,
                        canCallCapy: _controller.canCallCapy,
                        callBlockedReason: _controller.callCapyBlockedReason,
                        canBoost: _controller.canGrassBoost,
                        boostActive: _controller.isGrassBoostActive,
                        onUyutHub: () {
                          unawaited(_audio.noteUserGesture());
                          HapticFeedback.lightImpact();
                          UyutHubSheet.show(context, controller: _controller);
                        },
                        onForest: () {
                          unawaited(_audio.noteUserGesture());
                          HapticFeedback.lightImpact();
                          setState(() => _forestMapOpen = true);
                        },
                        onCallCapy: () {
                          unawaited(_audio.noteUserGesture());
                          if (_controller.spendCallCapy()) {
                            HapticFeedback.lightImpact();
                            _spawnFloat('+капи', Offset.zero);
                          }
                        },
                        onBoost: () {
                          unawaited(_audio.noteUserGesture());
                          if (_controller.spendGrassBoost()) {
                            HapticFeedback.lightImpact();
                          }
                        },
                      ),
                    ),
                ],
              ),
              Positioned.fill(
                child: FloatingGainLayer(
                  events: List.of(_floats),
                  onFinished: (id) {
                    setState(() => _floats.removeWhere((e) => e.id == id));
                  },
                ),
              ),
              const Positioned.fill(child: FirstLaunchTipOverlay()),
              if (_controller.isDailyBonusAvailable)
                Positioned(
                  right: 16,
                  bottom: 48,
                  child: Material(
                    color: Colors.transparent,
                    child: Tooltip(
                      message: 'Утренний уют',
                      child: InkWell(
                        onTap: _openDailyBonusManually,
                        borderRadius: BorderRadius.circular(20),
                        child: Ink(
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF8EC),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE2CFA8)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  '🎁',
                                  style: TextStyle(fontSize: 16),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Уют',
                                  style: CozyTheme.hudChipStyle(fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (_forestMapOpen)
                Positioned.fill(
                  child: ForestMapOverlay(
                    unlockedIds: _controller.unlockedMeadowIds,
                    activeMeadowId: _controller.state.activeMeadowId,
                    herdCountFor: _controller.herdCountForMeadow,
                    mistyBiomeUnlocked: _controller.state.mistyBiomeUnlocked,
                    grass: _controller.state.grass,
                    uyut: _controller.state.uyut,
                    showRocket: _controller.rocketUnlocked,
                    showLands: _controller.hasLandsGallery,
                    onRocket: () => setState(() {
                      _forestMapOpen = false;
                      _rocketPhase = _RocketPhase.farewell;
                    }),
                    onLands: () => setState(() {
                      _forestMapOpen = false;
                      _landsOpen = true;
                    }),
                    onClose: () => setState(() => _forestMapOpen = false),
                    onSelect: (id) {
                      if (_controller.switchToMeadow(id)) {
                        setState(() => _forestMapOpen = false);
                      }
                    },
                  ),
                ),
              if (_rocketPhase == _RocketPhase.farewell)
                Positioned.fill(
                  child: RocketFarewell(
                    onStay: () =>
                        setState(() => _rocketPhase = _RocketPhase.none),
                    onSend: () =>
                        setState(() => _rocketPhase = _RocketPhase.flight),
                  ),
                ),
              if (_rocketPhase == _RocketPhase.flight)
                Positioned.fill(
                  child: RocketFlight(
                    onArrive: () {
                      final ok = _controller.launchToNewLand();
                      setState(() => _rocketPhase = _RocketPhase.none);
                      if (!ok) return;
                    },
                  ),
                ),
              if (_landsOpen)
                Positioned.fill(
                  child: FamilyLandsSheet(
                    state: _controller.state,
                    onClose: () => setState(() => _landsOpen = false),
                    onVisit: (chapter) {
                      _controller.visitLand(chapter);
                      setState(() => _landsOpen = false);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildCozyPlaces(double w, double h, MeadowProps props) {
    return [
      for (final kind in props.places.keys)
        Positioned(
          left: props.places[kind]!.dx * w - 36,
          top: props.places[kind]!.dy * h - 32,
          child: CozyPlaceMarker(
            kind: kind,
            active: _controller.activePlaceBoost == kind,
            onCooldown: _controller.isPlaceOnCooldown(kind),
            cooldownSeconds: _controller.placeCooldownRemaining(kind),
            onTap: () {
              unawaited(_audio.noteUserGesture());
              final ok = _controller.tryActivatePlace(kind);
              if (ok) {
                _spawnFloat(kind.emoji, Offset.zero);
              }
            },
          ),
        ),
    ];
  }

  String _placeLine(dynamic state) {
    if (_controller.onFreshNewLand) {
      return 'Новая земля · сила ${state.familyPower}/5';
    }
    if (state.activeMeadowId == WorldZones.mistEdgeMeadowId &&
        state.maxCapyLevel >= 4) {
      return 'Туманный бор · после Lv.4';
    }
    final goal = _controller.currentSessionGoal;
    if (goal != null && goal.kind == SessionGoalKind.glade) {
      final detail = goal.hudCountDetailRu(
        herdCount: state.herdCount,
        maxCapyLevel: state.maxCapyLevel,
        uyut: state.uyut,
        familyPower: state.familyPower,
      );
      return detail.isEmpty ? goal.titleRu : '${goal.titleRu} · $detail';
    }
    return _controller.currentGlade.nameRu;
  }

  /// Dotted arc for a same-level pair that is close, but not stacked.
  ///
  /// Magnet snap stays at [GameController.effectiveMagnetRadius]. The arc
  /// uses sprite pixels so a grass gap still reads, and a pile does not.
  (Offset, Offset)? _mergePair(dynamic state, Size meadow) {
    final herd = state.herd;
    (Offset, Offset)? best;
    var bestDist = double.infinity;
    final minPx = BalanceV0.baseCapySize * 0.95;
    final maxPx = BalanceV0.baseCapySize * 2.6;
    final min2 = minPx * minPx;
    final max2 = maxPx * maxPx;
    for (var i = 0; i < herd.length; i++) {
      for (var j = i + 1; j < herd.length; j++) {
        final a = herd[i];
        final b = herd[j];
        if (a.level != b.level) continue;
        final dx = (a.position.dx - b.position.dx) * meadow.width;
        final dy = (a.position.dy - b.position.dy) * meadow.height;
        final dist2 = dx * dx + dy * dy;
        if (dist2 < min2 || dist2 > max2) continue;
        if (dist2 < bestDist) {
          bestDist = dist2;
          best = (a.position, b.position);
        }
      }
    }
    return best;
  }
}

enum _RocketPhase { none, farewell, flight }
