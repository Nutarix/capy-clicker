import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/audio/game_audio.dart';
import '../game/persistence/game_persistence.dart';
import '../game/widgets/meadow_background.dart';
import '../../theme/cozy_theme.dart';

/// Soft cozy title screen shown before [GameScreen].
///
/// Full-bleed forest (no phone letterbox). Hierarchy: large title top third,
/// scannable CTA mid/lower, capybara mascot lower third — Stardew-adjacent.
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
    final size = MediaQuery.sizeOf(context);
    // Scale title for short phones without shrinking the wordmark identity.
    final titleSize = (size.height * 0.075).clamp(44.0, 64.0);

    return Scaffold(
      body: MeadowBackground(
        child: !_ready
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF5A9A48)),
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  // Soft cream wash — atmospheric, low chrome.
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            const Color(0xFFF8EDD8).withValues(alpha: 0.32),
                            Colors.transparent,
                            const Color(0xFFF8EDD8).withValues(alpha: 0.22),
                          ],
                          stops: const [0.0, 0.42, 1.0],
                        ),
                      ),
                    ),
                  ),
                  // Discrete mute — top-right corner, not competing with CTA.
                  SafeArea(
                    child: Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 10, right: 14),
                        child: _MenuMuteChip(
                          muted: _audio.isMuted,
                          onToggle: () {
                            unawaited(_audio.noteUserGesture());
                            unawaited(_audio.toggleMute());
                          },
                        ),
                      ),
                    ),
                  ),
                  // Title / tagline — TOP third (dominating identity).
                  SafeArea(
                    child: Align(
                      alignment: const Alignment(0, -0.72),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Grow! Capy!',
                              textAlign: TextAlign.center,
                              style: CozyTheme.menuTitleStyle(
                                fontSize: titleSize,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'цветы · стадо · уют',
                              textAlign: TextAlign.center,
                              style: CozyTheme.menuTaglineStyle(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Primary CTA — lower-mid, clear pill above mascot.
                  SafeArea(
                    child: Align(
                      alignment: const Alignment(0, 0.28),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _CozyPrimaryButton(
                              label: _hasSave ? 'Продолжить' : 'Играть',
                              onPressed: _onPrimary,
                            ),
                            if (_hasSave) ...[
                              const SizedBox(height: 12),
                              _CozySecondaryButton(
                                label: 'Заново',
                                onPressed: _confirmNewGame,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Capybara mascot — LOWER third, larger.
                  SafeArea(
                    child: Align(
                      alignment: const Alignment(0, 0.82),
                      child: Image.asset(
                        'assets/images/capy_lv1.png',
                        width: 168,
                        height: 168,
                        filterQuality: FilterQuality.none,
                        errorBuilder: (_, _, _) => const Text(
                          '🦫',
                          style: TextStyle(fontSize: 96),
                        ),
                      ),
                    ),
                  ),
                  // Soft credit footer — quiet, bottom edge.
                  SafeArea(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          'сделано с теплом · Nutarix',
                          style: CozyTheme.hudChipMutedStyle(fontSize: 11)
                              .copyWith(
                            color: Colors.brown.shade900
                                .withValues(alpha: 0.42),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _CozyPrimaryButton extends StatelessWidget {
  const _CozyPrimaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: SizedBox(
        width: double.infinity,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(28),
            child: Ink(
              decoration: BoxDecoration(
                color: const Color(0xFF5A9A48),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0xFF3F6F34), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: CozyTheme.primaryButtonStyle(),
                ),
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
      constraints: const BoxConstraints(maxWidth: 280),
      child: SizedBox(
        width: double.infinity,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(22),
            child: Ink(
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8EC).withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE2CFA8), width: 1.5),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 11),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: CozyTheme.secondaryButtonStyle(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuMuteChip extends StatelessWidget {
  const _MenuMuteChip({required this.muted, required this.onToggle});

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
            color: const Color(0xFFFFF8EC).withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2CFA8)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                  style: CozyTheme.hudChipMutedStyle(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
