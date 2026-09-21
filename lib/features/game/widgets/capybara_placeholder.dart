import 'package:flutter/material.dart';

/// Brown rounded placeholder standing in for a capybara sprite.
class CapybaraPlaceholder extends StatelessWidget {
  const CapybaraPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 140,
          height: 100,
          decoration: BoxDecoration(
            color: const Color(0xFF8B6914),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: const Color(0xFF6B4E10),
              width: 2,
            ),
          ),
          child: const Center(
            child: Text(
              '🦫',
              style: TextStyle(fontSize: 48),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'капибара',
          style: TextStyle(
            color: Colors.brown.shade900.withValues(alpha: 0.7),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
