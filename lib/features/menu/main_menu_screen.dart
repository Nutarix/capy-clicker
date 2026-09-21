import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/audio/game_audio.dart';
import '../game/persistence/game_persistence.dart';
import '../game/widgets/meadow_background.dart';

/// Soft cozy title screen shown before [GameScreen].
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
          title: const Text(
            'Начать заново?',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF5C3D1E),
            ),
          ),
          content: const Text(
            'Текущее сохранение стада будет стёрто. Это нельзя отменить.',
            style: TextStyle(color: Color(0xFF5C3D1E), height: 1.35),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text(
                'Отмена',
                style: TextStyle(color: Color(0xFF8A6A45)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text(
                'Заново',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF5A9A48),
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
        child: SafeArea(
          child: !_ready
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF5A9A48)),
                )
              : Stack(
                  children: [
                    // Soft cream wash so title reads on forest.
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              const Color(0xFFF8EDD8).withValues(alpha: 0.28),
                              Colors.transparent,
                              const Color(0xFFF8EDD8).withValues(alpha: 0.35),
                            ],
                            stops: const [0.0, 0.45, 1.0],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 20,
                      ),
                      child: Column(
                        children: [
                          Align(
                            alignment: Alignment.topRight,
                            child: _MenuMuteChip(
                              muted: _audio.isMuted,
                              onToggle: () {
                                unawaited(_audio.noteUserGesture());
                                unawaited(_audio.toggleMute());
                              },
                            ),
                          ),
                          const Spacer(flex: 2),
                          Image.asset(
                            'assets/images/capy_lv1.png',
                            width: 128,
                            height: 128,
                            filterQuality: FilterQuality.none,
                            errorBuilder: (_, _, _) => const Text(
                              '🦫',
                              style: TextStyle(fontSize: 72),
                            ),
                          ),
                          const SizedBox(height: 18),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8EDD8)
                                  .withValues(alpha: 0.88),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: const Color(0xFFE2CFA8)
                                    .withValues(alpha: 0.95),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.12),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 22,
                                vertical: 14,
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    'Капи-кликер',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF5C3D1E),
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Capy Clicker',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF8A6A45),
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
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
                          const Spacer(flex: 3),
                          Text(
                            'сделано с теплом · Nutarix',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.brown.shade900
                                  .withValues(alpha: 0.45),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ],
                ),
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
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            decoration: BoxDecoration(
              color: const Color(0xFF5A9A48),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF4A823C), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFFFF8EC),
                  letterSpacing: 0.3,
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
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8EC).withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2CFA8), width: 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF5C3D1E),
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
            color: const Color(0xFFFFF8EC).withValues(alpha: 0.95),
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
