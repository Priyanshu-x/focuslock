import 'dart:math' as math;
import 'package:flutter/material.dart';

class ParticlePainter extends CustomPainter {
  final double progress;
  final double animationValue;

  ParticlePainter({
    required this.progress,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random();
    for (int i = 0; i < 20; i++) {
      final particleProgress = (animationValue + i * 0.05) % 1;
      final particleSize = (3 + rng.nextDouble() * 7) * (1 - progress); // Vary size
      final particleColor = Colors.orange.withOpacity(0.4 + rng.nextDouble() * 0.4); // Vary color and opacity

      final paint = Paint()
        ..color = particleColor
        ..style = PaintingStyle.fill;

      final offset = Offset(
        size.width * (0.2 + rng.nextDouble() * 0.6),
        size.height * (0.8 - particleProgress),
      );
      canvas.drawCircle(offset, particleSize, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}