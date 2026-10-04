import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/cozy_theme.dart';
import 'audio/game_audio.dart';
import 'controllers/game_controller.dart';
import 'persistence/game_persistence.dart';
import 'widgets/floating_gain.dart';
import 'widgets/meadow_space.dart';
import 'widgets/meadow_background.dart';
import 'widgets/screen/game_hud.dart';
import 'widgets/screen/game_messages.dart';
import 'widgets/screen/game_overlays.dart';
import 'widgets/screen/meadow_layer.dart';
import 'widgets/tip_overlay.dart';

/// Live game screen: auto progress, flowers, herd, merge, mud, berries, zoom.
///
/// Layers: HUD bars (`game_hud.dart`), the meadow (`meadow_layer.dart`),
/// messages (`game_messages.dart`), sheets and overlays
/// (`game_overlays.dart`). Each part listens to the slice it shows; the
/// screen itself rebuilds only on big changes (spec 002, Т6).
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

class _GameScreenState extends State<GameScreen>
    with GameMessagesMixin, GameOverlaysMixin {
  late final GameController _controller;
  late final bool _ownsController;
  late final GameAudio _audio;
  late final bool _ownsAudio;

  /// Save on the way out, pause in background, greet on return.
  late final AppLifecycleListener _lifecycle;

  /// Floating «+N%» / «×2» popups (their own layer, not a screen rebuild).
  final ValueNotifier<List<FloatingGainEvent>> _floats = ValueNotifier(
    const [],
  );
  int _floatSeq = 0;

  /// Screen ↔ meadow, shared by the meadow and the «+капи» label.
  final MeadowSpace _meadowSpace = MeadowSpace();

  /// What the whole screen is built from: loaded, which meadow, which land.
  late (bool, String, int) _frame;

  @override
  GameController get game => _controller;

  @override
  GameAudio get audio => _audio;

  (bool, String, int) _frameOf() => (
    _controller.isReady,
    _controller.state.activeMeadowId,
    _controller.state.landChapter,
  );

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller =
        widget.controller ??
        GameController(persistence: widget.persistence, now: widget.now);
    _ownsAudio = widget.audio == null;
    _audio = widget.audio ?? GameAudio();
    _frame = _frameOf();
    _controller.addListener(_onControllerChanged);
    listenToGameEvents();
    _controller.init();
    // Shared sound is already up: init runs once per GameAudio.
    _audio.init();
    _lifecycle = AppLifecycleListener(
      onInactive: () => unawaited(_controller.flushSave()),
      onHide: _onAppHidden,
      onShow: _onAppShown,
      onDetach: () => unawaited(_controller.flushSave()),
      onExitRequested: _onExitRequested,
    );
  }

  /// Swiped away, tab hidden, window minimized: write now, stop the clock.
  void _onAppHidden() {
    unawaited(_controller.suspend());
    // The app silences shared sound itself; only own audio is ours to pause.
    if (_ownsAudio) unawaited(_audio.setInBackground(true));
  }

  void _onAppShown() {
    _controller.resumeFromBackground();
    if (_ownsAudio) unawaited(_audio.setInBackground(false));
  }

  /// Desktop window close: the exit waits for the save.
  Future<AppExitResponse> _onExitRequested() async {
    await _controller.flushSave();
    return AppExitResponse.exit;
  }

  /// Ticks do not rebuild the screen: only loading, a meadow or a land swap.
  void _onControllerChanged() {
    if (!mounted) return;
    final next = _frameOf();
    if (next == _frame) return;
    setState(() => _frame = next);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    stopGameEvents();
    _controller.removeListener(_onControllerChanged);
    _floats.dispose();
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
    _floats.value = [
      ..._floats.value,
      FloatingGainEvent(
        id: id,
        label: label,
        globalAnchor: globalAnchor,
        color: color ?? const Color(0xFF5A9A48),
      ),
    ];
  }

  /// «+капи» over the newcomer (a new capy joins the end of the family).
  void _floatOverNewCapy() {
    final herd = _controller.state.herd;
    if (herd.isEmpty) return;
    final at = _meadowSpace.toGlobal(herd.last.position);
    if (at != null) _spawnFloat('+капи', at);
  }

  void _floatFinished(int id) {
    _floats.value = [
      for (final e in _floats.value)
        if (e.id != id) e,
    ];
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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: CozyTheme.systemOverlay,
      child: Scaffold(
        backgroundColor: CozyTheme.cream,
        body: MeadowBackground(
          meadowId: _controller.state.activeMeadowId,
          child: Stack(
            children: [
              Column(
                children: [
                  if (chromeHidden)
                    const SizedBox.shrink()
                  else
                    GameTopBar(
                      controller: _controller,
                      audio: _audio,
                      onBackToMenu: widget.onBackToMenu,
                    ),
                  Expanded(
                    child: MeadowLayer(
                      controller: _controller,
                      audio: _audio,
                      onFloat: _spawnFloat,
                      space: _meadowSpace,
                    ),
                  ),
                  if (chromeHidden)
                    const SizedBox.shrink()
                  else
                    GameBottomBar(
                      controller: _controller,
                      audio: _audio,
                      onForest: openForestMap,
                      onCapyCalled: _floatOverNewCapy,
                    ),
                ],
              ),
              Positioned.fill(
                child: RepaintBoundary(
                  child: ValueListenableBuilder<List<FloatingGainEvent>>(
                    valueListenable: _floats,
                    builder: (context, floats, _) => FloatingGainLayer(
                      events: floats,
                      onFinished: _floatFinished,
                    ),
                  ),
                ),
              ),
              const Positioned.fill(child: FirstLaunchTipOverlay()),
              ...buildOverlays(),
            ],
          ),
        ),
      ),
    );
  }
}
