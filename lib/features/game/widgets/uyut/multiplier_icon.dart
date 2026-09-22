import 'package:flutter/material.dart';

/// Soft-pixel multiplier icon with transparent background.
class MultiplierIcon extends StatelessWidget {
  const MultiplierIcon({
    super.key,
    required this.assetPath,
    this.size = 28,
    this.opacity = 1,
  });

  final String assetPath;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    Widget img = Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.none,
      errorBuilder: (context, error, stackTrace) {
        return SizedBox(
          width: size,
          height: size,
          child: Icon(Icons.image_not_supported_outlined, size: size * 0.7),
        );
      },
    );
    if (opacity < 1) {
      img = Opacity(opacity: opacity, child: img);
    }
    return img;
  }
}
