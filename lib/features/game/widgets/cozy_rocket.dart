import 'package:flutter/material.dart';

/// Cozy rocket body for the north-star chapter. The window uses the existing
/// capy sprite — no new character.
class CozyRocket extends StatelessWidget {
  const CozyRocket({super.key, this.height = 280});

  final double height;

  @override
  Widget build(BuildContext context) {
    final width = height * 0.62;
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            bottom: height * 0.02,
            child: Container(
              width: width * 0.55,
              height: height * 0.08,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(40),
              ),
            ),
          ),
          Positioned(
            top: height * 0.02,
            child: Container(
              width: width * 0.42,
              height: height * 0.16,
              decoration: const BoxDecoration(
                color: Color(0xFF7DAB6A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
            ),
          ),
          Positioned(
            top: height * 0.16,
            child: Container(
              width: width * 0.46,
              height: height * 0.58,
              decoration: BoxDecoration(
                color: const Color(0xFFF6E7C8),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF8A6A45), width: 3),
              ),
            ),
          ),
          Positioned(
            top: height * 0.40,
            child: Container(
              width: width * 0.46,
              height: 8,
              color: const Color(0xFFE7A0B4),
            ),
          ),
          Positioned(
            top: height * 0.46,
            child: Container(
              width: width * 0.28,
              height: width * 0.28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF8A6A45),
                border: Border.all(color: const Color(0xFF5C3D1E), width: 3),
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/capy_lv1.png',
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.none,
                ),
              ),
            ),
          ),
          Positioned(
            left: width * 0.08,
            top: height * 0.28,
            child: Container(
              width: 10,
              height: height * 0.36,
              color: const Color(0xFF8A5A32),
            ),
          ),
          Positioned(left: width * 0.02, bottom: height * 0.22, child: _bush()),
          Positioned(
            right: width * 0.02,
            bottom: height * 0.22,
            child: _bush(),
          ),
        ],
      ),
    );
  }

  Widget _bush() {
    return Container(
      width: height * 0.08,
      height: height * 0.08,
      decoration: const BoxDecoration(
        color: Color(0xFF8FBF78),
        shape: BoxShape.circle,
      ),
    );
  }
}
