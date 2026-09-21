import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/balance.dart';

/// First-launch tip cards: merge + mud. Dismiss once → persisted.
class FirstLaunchTipOverlay extends StatefulWidget {
  const FirstLaunchTipOverlay({super.key});

  @override
  State<FirstLaunchTipOverlay> createState() => _FirstLaunchTipOverlayState();
}

class _FirstLaunchTipOverlayState extends State<FirstLaunchTipOverlay> {
  bool _loading = true;
  bool _show = false;
  int _page = 0;

  static const _tips = <({String title, String body, IconData icon})>[
    (
      title: 'Слияние',
      body: 'Перетащи капибар друг на друга',
      icon: Icons.swipe_rounded,
    ),
    (title: 'Лужа', body: 'Перетащи на лужу', icon: Icons.water_drop_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(BalanceV0.tipsSeenKey) ?? false;
    if (!mounted) return;
    setState(() {
      _loading = false;
      _show = !seen;
    });
  }

  Future<void> _dismiss() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(BalanceV0.tipsSeenKey, true);
    if (!mounted) return;
    setState(() => _show = false);
  }

  void _next() {
    if (_page < _tips.length - 1) {
      setState(() => _page++);
    } else {
      _dismiss();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || !_show) return const SizedBox.shrink();

    final tip = _tips[_page];

    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8EC),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE2CFA8), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(tip.icon, size: 40, color: const Color(0xFF6B9B4A)),
                    const SizedBox(height: 12),
                    Text(
                      tip.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF5C3D1E),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tip.body,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.35,
                        color: Colors.brown.shade800.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_page + 1}/${_tips.length}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.brown.shade600.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        TextButton(
                          onPressed: _dismiss,
                          child: Text(
                            'Пропуск',
                            style: TextStyle(color: Colors.brown.shade600),
                          ),
                        ),
                        const Spacer(),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF6B9B4A),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: _next,
                          child: Text(
                            _page < _tips.length - 1 ? 'Далее' : 'Понятно',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
