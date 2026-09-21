import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'audio/game_audio.dart';
import 'controllers/game_controller.dart';
import 'models/balance.dart';
import 'models/world_zones.dart';
import 'widgets/berry_basket.dart';
import 'widgets/draggable_capybara.dart';
import 'widgets/flower_dot.dart';
import 'widgets/floating_gain.dart';
import 'widgets/meadow_background.dart';
import 'widgets/meadow_decor.dart';
import 'widgets/mud_puddle.dart';
import 'widgets/progress_bar.dart';
import 'widgets/morning_cozy_sheet.dart';
import 'widgets/tip_overlay.dart';

/// Live game screen: auto progress, flowers, herd, merge, mud, berries, zoom.
class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    this.controller,
    this.audio,
    this.onBackToMenu,
  });

  /// Optional injected controller (tests / DI).
  final GameController? controller;

  /// Optional audio (pass [GameAudio.silent] / `silent: true` in tests).
  final GameAudio? audio;

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

  /// Bumps CreamProgressBar pulse on explicit gains.
  int _progressPulseToken = 0;

  /// Soft first-appearance hint on berry basket (session).
  bool _berryHintSeen = false;

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
    _controller = widget.controller ?? GameController();
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
  }

  void _maybeShowGladeUnlock() {
    final msg = _controller.gladeUnlockToast;
    if (msg == null || msg.isEmpty) return;
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
            'Пока тебя не было… стадо подросло ($timeLabel → $barsLabel)',
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
      _progressPulseToken++;
    });
  }

  void _onFlowerTap(Offset globalAnchor) {
    HapticFeedback.lightImpact();
    unawaited(_audio.noteUserGesture());
    _audio.playFlower();
    final gain = _controller.onFlowerTap();
    final pct = (gain * 100).round().clamp(1, 99);
    _spawnFloat('+$pct%', globalAnchor);
  }

  void _onBerryTap(Offset globalAnchor) {
    HapticFeedback.mediumImpact();
    unawaited(_audio.noteUserGesture());
    _audio.playBerry();
    final gain = _controller.onBerryTap();
    if (gain == null) return;
    _berryHintSeen = true;
    final pct = (gain * 100).round().clamp(1, 99);
    _spawnFloat('+$pct%', globalAnchor, color: const Color(0xFFE03A5C));
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
        final local = Offset(
          BalanceV0.mudCenterX * box.size.width,
          BalanceV0.mudCenterY * box.size.height,
        );
        _spawnFloat(
          '×2',
          box.localToGlobal(local),
          color: const Color(0xFFB8860B),
        );
      } else {
        setState(() => _progressPulseToken++);
      }
    }
    return ok;
  }

  Offset _meadowOriginGlobal() {
    final box = _meadowKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return Offset.zero;
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

    return Scaffold(
      body: MeadowBackground(
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8EDD8).withValues(alpha: 0.82),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xFFE2CFA8).withValues(alpha: 0.9),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            CreamProgressBar(
                              value: state.herdProgress,
                              boostActive: boost,
                              boostSeconds:
                                  _controller.mudBoostRemainingSeconds,
                              autoRatePerSecond: _controller.autoRatePerSecond,
                              pulseToken: _progressPulseToken,
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                _HerdSizeChip(count: state.herdCount),
                                _SunnyGladeChip(
                                  nameRu: _controller.currentGlade.nameRu,
                                ),
                                _MuteChip(
                                  muted: _audio.isMuted,
                                  onToggle: () {
                                    unawaited(_audio.noteUserGesture());
                                    unawaited(_audio.toggleMute());
                                  },
                                ),
                                if (widget.onBackToMenu != null)
                                  _MenuBackChip(
                                    onPressed: () {
                                      unawaited(_audio.noteUserGesture());
                                      HapticFeedback.lightImpact();
                                      widget.onBackToMenu!();
                                    },
                                  ),
                              ],
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
                                  // Mud puddle (behind capys)
                                  Positioned(
                                    left: BalanceV0.mudCenterX * w - 55,
                                    top: BalanceV0.mudCenterY * h - 43,
                                    child: MudPuddle(
                                      isWallowing:
                                          _controller.wallowingCapyId != null,
                                      boostActive: boost,
                                    ),
                                  ),
                                  ...List.generate(
                                    WorldZones.flowerPositions.length,
                                    (i) {
                                      final (fx, fy) =
                                          WorldZones.flowerPositions[i];
                                      return Positioned(
                                        left: fx * w - FlowerDot.hitSize / 2,
                                        top: fy * h - FlowerDot.hitSize / 2,
                                        child: FlowerDot(
                                          color: _flowerColors[
                                              i % _flowerColors.length],
                                          onTap: _onFlowerTap,
                                        ),
                                      );
                                    },
                                  ),
                                  if (_controller.isBerryVisible)
                                    Positioned(
                                      left: BalanceV0.berryPosX * w - 32,
                                      top: BalanceV0.berryPosY * h - 37,
                                      child: BerryBasket(
                                        onTap: _onBerryTap,
                                        showHint: !_berryHintSeen,
                                      ),
                                    ),
                                  ...state.herd.map((capy) {
                                    final promote =
                                        _badgePromoted.contains(capy.id) ||
                                        _controller.mergeFlashId == capy.id ||
                                        _magnetAttractedId == capy.id;
                                    return MeadowDraggableCapybara(
                                      key: ValueKey(capy.id),
                                      capybara: capy,
                                      herd: state.herd,
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
                                      magnetAttractedId: _magnetAttractedId,
                                      promoteLevelBadge: promote,
                                      onDragBadge: () =>
                                          _promoteBadge(capy.id),
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
                  Padding(
                    padding: const EdgeInsets.only(
                      bottom: 12,
                      left: 16,
                      right: 16,
                    ),
                    child: Text(
                      'Цветы · ягоды · лужа (×2) · слияние одинакового уровня',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.brown.shade900.withValues(alpha: 0.55),
                        fontSize: 11,
                      ),
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
                            border: Border.all(
                              color: const Color(0xFFE2CFA8),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('🎁', style: TextStyle(fontSize: 16)),
                                SizedBox(width: 6),
                                Text(
                                  'Уют',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF5C3D1E),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}


/// Explicit herd size — never paired as «Glade N/12» progress.
class _HerdSizeChip extends StatelessWidget {
  const _HerdSizeChip({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8EC).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2CFA8)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          'стадо $count/${BalanceV0.maxHerdSize}',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF5C3D1E),
          ),
        ),
      ),
    );
  }
}

/// Soft label for the active «Солнечные поляны» circle (name only — not N/12).
class _SunnyGladeChip extends StatelessWidget {
  const _SunnyGladeChip({required this.nameRu});

  final String nameRu;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8EC).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2CFA8)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🌿', style: TextStyle(fontSize: 12)),
            const SizedBox(width: 5),
            Text(
              'поляна: $nameRu',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF5C3D1E),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact mute / unmute control for BGM + SFX.
class _MuteChip extends StatelessWidget {
  const _MuteChip({required this.muted, required this.onToggle});

  final bool muted;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8EC).withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2CFA8)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  size: 16,
                  color: const Color(0xFF5C3D1E),
                ),
                const SizedBox(width: 4),
                Text(
                  muted ? 'звук выкл' : 'звук',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF5C3D1E),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


/// Compact return-to-menu control (does not wipe save).
class _MenuBackChip extends StatelessWidget {
  const _MenuBackChip({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8EC).withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2CFA8)),
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.pause_rounded,
                  size: 16,
                  color: Color(0xFF5C3D1E),
                ),
                SizedBox(width: 4),
                Text(
                  'меню',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF5C3D1E),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
