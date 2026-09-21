import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/audio/game_audio.dart';
import '../game/persistence/game_persistence.dart';
import '../game/widgets/meadow_background.dart';
import '../../theme/cozy_theme.dart';
import '../../widgets/portrait_menu_stage.dart';

/// Soft cozy title screen shown before [GameScreen].
///
/// True portrait presentation: on desktop/web the UI lives in a full-height
/// 9:16 column (forest blur gutters, no phone chrome). Hierarchy: large title
/// top, compact CTA close under title, large capybara hero dominating the
/// lower half. Soft scrims behind title and under capy for readability.
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
            'Текущее сохранение стада будет стёрто. Это нельзя отменить.',
            style: CozyTheme.hudChipMutedStyle(fontSize: 14).copyWith(
              height: 1.35,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'Отмена',
                style: CozyTheme.hudChipMutedStyle().copyWith(
                  color: CozyTheme.softBrown,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                'Заново',
                style: CozyTheme.secondaryButtonStyle().copyWith(
                  fontWeight: FontWeight.w800,
                  color: CozyTheme.buttonGreen,
                ),
              ),
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
                    // Hero capy — dominates lower half, not a tiny footer mascot.
                    final capySize = (h * 0.38).clamp(220.0, 300.0);

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
                        // Soft scrim behind title — readability, not heavy vignette.
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          height: h * 0.32,
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
                        // Soft ground scrim behind/under capy — ground anchor.
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          height: h * 0.48,
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
                        // Vertical stack: title top → CTA tight under → hero capy.
                        SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              children: [
                                const SizedBox(height: 36),
                                // Title — TOP
                                Text(
                                  'Grow! Capy!',
                                  textAlign: TextAlign.center,
                                  style: CozyTheme.menuTitleStyle(
                                    fontSize: titleSize,
                                  ),
                                ),
                                // Tight gap — CTA close under title (no empty mid).
                                const SizedBox(height: 18),
                                _CozyPrimaryButton(
                                  label: _hasSave ? 'Продолжить' : 'Играть',
                                  onPressed: _onPrimary,
                                ),
                                if (_hasSave) ...[
                                  const SizedBox(height: 10),
                                  _CozySecondaryButton(
                                    label: 'Заново',
                                    onPressed: _confirmNewGame,
                                  ),
                                ],
                                // Remaining space → large capy dominates lower half.
                                const Spacer(),
                                Image.asset(
                                  'assets/images/capy_lv1.png',
                                  width: capySize,
                                  height: capySize,
                                  filterQuality: FilterQuality.none,
                                  errorBuilder: (_, _, _) => Text(
                                    '🦫',
                                    style: TextStyle(fontSize: capySize * 0.57),
                                  ),
                                ),
                                const SizedBox(height: 28),
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

/// Compact cozy pill — Pixelify label, soft sage (not Material billboard).
class _CozyPrimaryButton extends StatelessWidget {
  const _CozyPrimaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 200),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            decoration: BoxDecoration(
              color: CozyTheme.softSage,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: CozyTheme.softSageEdge, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: CozyTheme.menuPrimaryCtaStyle(fontSize: 16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CozySecondaryButton extends StatelessWidget {
  const _CozySecondaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 180),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8EC).withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2CFA8), width: 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: CozyTheme.secondaryButtonStyle(fontSize: 13),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Icon-only mute control (no cream chip, no «звук» label).
class _MenuMuteIcon extends StatelessWidget {
  const _MenuMuteIcon({required this.muted, required this.onToggle});

  final bool muted;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: muted ? 'Включить звук' : 'Выключить звук',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onToggle,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(
              muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              size: 22,
              color: CozyTheme.cream.withValues(alpha: 0.92),
              shadows: const [
                Shadow(
                  offset: Offset(0, 1),
                  blurRadius: 4,
                  color: Color(0x66000000),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
