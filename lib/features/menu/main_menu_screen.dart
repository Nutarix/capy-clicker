import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/audio/game_audio.dart';
import '../game/persistence/game_persistence.dart';
import '../game/widgets/meadow_background.dart';
import '../../theme/cozy_theme.dart';
import '../../widgets/cozy_pixel_button.dart';
import '../../widgets/portrait_menu_stage.dart';

/// Soft cozy title screen shown before [GameScreen].
///
/// True portrait presentation: on desktop/web the UI lives in a full-height
/// 9:16 column (forest blur gutters, no phone chrome). Vertical thirds:
/// title (upper), smaller capy + bigger Play at end of middle band (~2/3),
/// empty lower third with soft ground scrim.
class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({
    super.key,
    required this.onPlay,
    required this.onContinue,
    required this.onNewGame,
    this.audio,
    this.persistence,
  });

  /// Fresh start (no save yet) — primary «Играть».
  final VoidCallback onPlay;

  /// Resume existing save — primary «Продолжить».
  final VoidCallback onContinue;

  /// Wipe save and start over (caller clears persistence).
  final Future<void> Function() onNewGame;

  /// Shared audio (mute + soft BGM after first gesture).
  final GameAudio? audio;

  /// Optional persistence for save detection (tests / DI).
  final GamePersistence? persistence;

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  late final GameAudio _audio;
  late final bool _ownsAudio;
  late final GamePersistence _persistence;
  bool _ready = false;
  bool _hasSave = false;

  @override
  void initState() {
    super.initState();
    _ownsAudio = widget.audio == null;
    _audio = widget.audio ?? GameAudio();
    _persistence = widget.persistence ?? GamePersistence();
    _audio.addListener(_onAudioChanged);
    if (_ownsAudio) {
      unawaited(_audio.init());
    }
    unawaited(_loadSaveFlag());
  }

  Future<void> _loadSaveFlag() async {
    final has = await _persistence.hasSave();
    if (!mounted) return;
    setState(() {
      _hasSave = has;
      _ready = true;
    });
  }

  void _onAudioChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _audio.removeListener(_onAudioChanged);
    if (_ownsAudio) {
      _audio.dispose();
    }
    super.dispose();
  }

  Future<void> _confirmNewGame() async {
    unawaited(_audio.noteUserGesture());
    HapticFeedback.lightImpact();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFFF8EC),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFE2CFA8), width: 1.5),
          ),
          title: Text(
            'Начать заново?',
            style: CozyTheme.secondaryButtonStyle(fontSize: 18).copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            'Текущее сохранение семьи будет стёрто. Это нельзя отменить.',
            style: CozyTheme.hudChipMutedStyle(fontSize: 14).copyWith(
              height: 1.35,
            ),
          ),
          actions: [
            CozyPixelButton(
              label: 'Отмена',
              variant: CozyPixelButtonVariant.secondary,
              compact: true,
              onPressed: () => Navigator.of(ctx).pop(false),
            ),
            CozyPixelButton(
              label: 'Заново',
              compact: true,
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ],
        );
      },
    );
    if (ok == true && mounted) {
      await widget.onNewGame();
    }
  }

  void _onPrimary() {
    unawaited(_audio.noteUserGesture());
    HapticFeedback.mediumImpact();
    if (_hasSave) {
      widget.onContinue();
    } else {
      widget.onPlay();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MeadowBackground(
        child: !_ready
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF5A9A48)),
              )
            : PortraitMenuStage(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final h = constraints.maxHeight;
                    final titleSize = (h * 0.072).clamp(44.0, 62.0);
                    // Mid-band mascot — smaller than prior lower-half hero.
                    final capySize = (h * 0.22).clamp(140.0, 190.0);

                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        // Subtle atmospheric wash (kept light).
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  const Color(0xFFF8EDD8).withValues(alpha: 0.18),
                                  Colors.transparent,
                                  const Color(0xFFF8EDD8).withValues(alpha: 0.12),
                                ],
                                stops: const [0.0, 0.4, 1.0],
                              ),
                            ),
                          ),
                        ),
                        // Soft scrim behind title — upper third readability.
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          height: h * 0.34,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.20),
                                  Colors.black.withValues(alpha: 0.08),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.55, 1.0],
                              ),
                            ),
                          ),
                        ),
                        // Soft ground scrim — lower third empty forest/ground.
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          height: h * 0.36,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.26),
                                  Colors.black.withValues(alpha: 0.10),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.45, 1.0],
                              ),
                            ),
                          ),
                        ),
                        // Icon-only mute — top-right of the portrait column.
                        SafeArea(
                          child: Align(
                            alignment: Alignment.topRight,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 8, right: 10),
                              child: _MenuMuteIcon(
                                muted: _audio.isMuted,
                                onToggle: () {
                                  unawaited(_audio.noteUserGesture());
                                  unawaited(_audio.toggleMute());
                                },
                              ),
                            ),
                          ),
                        ),
                        // Vertical thirds: title | capy + Play | empty lower.
                        SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              children: [
                                // —— Upper third: title only ——
                                Expanded(
                                  flex: 1,
                                  child: Align(
                                    alignment: Alignment.center,
                                    child: Text(
                                      'Grow! Capy!',
                                      textAlign: TextAlign.center,
                                      style: CozyTheme.menuTitleStyle(
                                        fontSize: titleSize,
                                      ),
                                    ),
                                  ),
                                ),
                                // —— Middle third: capy above Play at band end ——
                                Expanded(
                                  flex: 1,
                                  child: Column(
                                    children: [
                                      Expanded(
                                        child: FittedBox(
                                          fit: BoxFit.contain,
                                          child: Image.asset(
                                            'assets/images/capy_lv1.png',
                                            width: capySize,
                                            height: capySize,
                                            filterQuality: FilterQuality.none,
                                            errorBuilder: (_, _, _) => Text(
                                              '🦫',
                                              style: TextStyle(
                                                fontSize: capySize * 0.57,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      CozyPixelButton(
                                        label:
                                            _hasSave ? 'Продолжить' : 'Играть',
                                        onPressed: _onPrimary,
                                        expand: true,
                                        maxWidth: 260,
                                        fontSize: 22,
                                      ),
                                      if (_hasSave) ...[
                                        const SizedBox(height: 10),
                                        CozyPixelButton(
                                          label: 'Заново',
                                          variant:
                                              CozyPixelButtonVariant.secondary,
                                          onPressed: _confirmNewGame,
                                          maxWidth: 220,
                                          compact: true,
                                        ),
                                      ],
                                      const SizedBox(height: 4),
                                    ],
                                  ),
                                ),
                                // —— Lower third: empty forest / ground ——
                                const Expanded(flex: 1, child: SizedBox.expand()),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
      ),
    );
  }
}

/// Icon-only mute control in cozy circular pixel frame.
class _MenuMuteIcon extends StatelessWidget {
  const _MenuMuteIcon({required this.muted, required this.onToggle});

  final bool muted;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return CozyPixelIconButton(
      icon: muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
      onPressed: onToggle,
      semanticLabel: muted ? 'Включить звук' : 'Выключить звук',
      size: 38,
      iconSize: 20,
    );
  }
}
