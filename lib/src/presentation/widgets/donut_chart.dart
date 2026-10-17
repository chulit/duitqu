import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Donut chart sederhana via CustomPainter (tanpa animasi, ramah test).
class DonutChart extends StatelessWidget {
  final List<double> values;
  final List<Color> colors;
  final double strokeWidth;

  const DonutChart({
    super.key,
    required this.values,
    required this.colors,
    this.strokeWidth = 30,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DonutPainter(
        values: values,
        colors: colors,
        strokeWidth: strokeWidth,
        emptyColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  final double strokeWidth;
  final Color emptyColor;

  _DonutPainter({
    required this.values,
    required this.colors,
    required this.strokeWidth,
    required this.emptyColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - strokeWidth / 2;

    final total = values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) {
      final paint = Paint()
        ..color = emptyColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawCircle(center, radius, paint);
      return;
    }

    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / total * math.pi * 2;
      if (sweep <= 0) continue;
      final paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        math.max(sweep, 0.01),
        false,
        paint,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.values != values || old.colors != colors;
}
