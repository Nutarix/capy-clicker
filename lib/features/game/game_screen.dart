import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'controllers/game_controller.dart';
import 'models/balance.dart';
import 'widgets/berry_basket.dart';
import 'widgets/draggable_capybara.dart';
import 'widgets/flower_dot.dart';
import 'widgets/meadow_background.dart';
import 'widgets/meadow_decor.dart';
import 'widgets/mud_puddle.dart';
import 'widgets/progress_bar.dart';
import 'widgets/morning_cozy_sheet.dart';
import 'widgets/tip_overlay.dart';

/// Live game screen: auto progress, flowers, herd, merge, mud, berries, zoom.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key, this.controller});

  /// Optional injected controller (tests / DI).
  final GameController? controller;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final GameController _controller;
  late final bool _ownsController;
  final GlobalKey _meadowKey = GlobalKey();
  bool _offlineWelcomeShown = false;
  bool _dailyPromptShown = false;
  bool _dailySheetOpen = false;

  static const _flowerLayouts = <({double left, double top, Color color})>[
    (left: 0.18, top: 0.42, color: Color(0xFFE87AA0)),
    (left: 0.72, top: 0.38, color: Color(0xFFF0C040)),
    (left: 0.28, top: 0.58, color: Color(0xFF9B6BDE)),
    (left: 0.78, top: 0.55, color: Color(0xFFE85A5A)),
    (left: 0.48, top: 0.48, color: Color(0xFF5AB8E8)),
  ];

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? GameController();
    _controller.addListener(_onControllerChanged);
    _controller.init();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    setState(() {});
    _maybeShowOfflineWelcome();
    _maybeShowDailyBonus();
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
    _controller.removeListener(_onControllerChanged);
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _onFlowerTap() {
    HapticFeedback.lightImpact();
    _controller.onFlowerTap();
  }

  void _onBerryTap() {
    HapticFeedback.mediumImpact();
    _controller.onBerryTap();
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
    }
    return ok;
  }

  bool _onMudDrop(String id) {
    final ok = _controller.tryMudWallow(id);
    if (ok) {
      HapticFeedback.lightImpact();
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
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                    child: CreamProgressBar(
                      value: state.herdProgress,
                      herdCount: state.herdCount,
                      boostActive: boost,
                      boostSeconds: _controller.mudBoostRemainingSeconds,
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
                                  ..._flowerLayouts.map((f) {
                                    return Positioned(
                                      left: f.left * w - 22,
                                      top: f.top * h - 22,
                                      child: FlowerDot(
                                        color: f.color,
                                        onTap: _onFlowerTap,
                                      ),
                                    );
                                  }),
                                  if (_controller.isBerryVisible)
                                    Positioned(
                                      left: BalanceV0.berryPosX * w - 32,
                                      top: BalanceV0.berryPosY * h - 37,
                                      child: BerryBasket(onTap: _onBerryTap),
                                    ),
                                  ...state.herd.map((capy) {
                                    return MeadowDraggableCapybara(
                                      key: ValueKey(capy.id),
                                      capybara: capy,
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
