import 'dart:math' as math;

import 'package:flutter/material.dart';

class ScoreRing extends StatelessWidget {
  const ScoreRing({
    super.key,
    required this.score,
    this.maxScore = 100,
    this.size = 108,
    this.strokeWidth = 10,
    this.color,
    this.backgroundColor,
    this.label,
  });

  final int score;
  final int maxScore;
  final double size;
  final double strokeWidth;
  final Color? color;
  final Color? backgroundColor;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final clamped = score.clamp(0, maxScore);
    final progress = maxScore <= 0 ? 0.0 : clamped / maxScore;
    final scheme = Theme.of(context).colorScheme;
    final ringColor = color ?? scheme.primary;
    final ringBg = backgroundColor ?? scheme.surfaceContainerHighest;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ScoreRingPainter(
          progress: progress,
          color: ringColor,
          backgroundColor: ringBg,
          strokeWidth: strokeWidth,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$clamped',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              if (label != null) ...[
                const SizedBox(height: 2),
                Text(
                  label!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreRingPainter extends CustomPainter {
  const _ScoreRingPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final Color backgroundColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) / 2) - strokeWidth / 2;

    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    final sweep = 2 * math.pi * progress.clamp(0.0, 1.0);
    const startAngle = -math.pi / 2;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweep,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScoreRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

