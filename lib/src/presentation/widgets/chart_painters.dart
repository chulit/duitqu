import 'package:flutter/material.dart';

/// Painters untuk chart Insight — dipakai di tab Tren & halaman detail kategori.

/// Format singkat untuk sumbu Y: 6jt, 300rb.
String shortAxis(int value) {
  if (value >= 1000000) {
    final jt = value / 1000000;
    return '${jt.toStringAsFixed(jt.truncateToDouble() == jt ? 0 : 1)}jt';
  }
  if (value >= 1000) {
    final rb = value / 1000;
    return '${rb.toStringAsFixed(rb.truncateToDouble() == rb ? 0 : 1)}rb';
  }
  return '$value';
}

/// Bulatkan max ke angka "cantik" agar label Y rapi (kelipatan 1/2/2.5/5 x 10^n).
/// Memastikan max/3 juga cantik untuk 4 garis grid.
int niceCeiling(int value) {
  if (value <= 0) return 1;
  int magnitude = 1;
  int v = value;
  while (v >= 10) {
    v ~/= 10;
    magnitude *= 10;
  }
  // Coba kelipatan cantik dari kecil ke besar.
  const steps = [1.0, 2.0, 2.5, 5.0, 10.0];
  for (final s in steps) {
    final candidate = (s * magnitude).round();
    if (candidate < value) continue;
    // Pastikan candidate/3 juga "cantik" (tidak desimal aneh).
    final third = candidate / 3;
    final thirdNormalized = third / magnitude;
    // third cantik jika kelipatan 1, 2, 2.5, 5, 10 (toleransi kecil).
    const niceThirds = [1.0, 2.0, 2.5, 5.0, 10.0];
    final isNice = niceThirds.any(
      (n) => (thirdNormalized - n).abs() < 0.01,
    );
    if (isNice) return candidate;
  }
  return 10 * magnitude;
}

/// Gambar label teks di canvas.
void paintLabel(
  Canvas canvas,
  String text,
  Offset offset,
  Color color, {
  double fontSize = 11,
}) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(color: color, fontSize: fontSize),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, offset);
}

/// Gambar grid horizontal + label Y (0..max, 4 garis) dengan angka cantik.
void paintYGrid(
  Canvas canvas,
  Size size,
  int maxVal,
  Color textColor, {
  double leftPad = 36,
  double topPad = 8,
  double bottomPad = 24,
}) {
  final niceMax = niceCeiling(maxVal);
  final chartH = size.height - bottomPad - topPad;
  final gridPaint = Paint()
    ..color = textColor.withValues(alpha: 0.12)
    ..strokeWidth = 1;
  for (var i = 0; i <= 3; i++) {
    final y = topPad + chartH - (chartH * i / 3);
    canvas.drawLine(
      Offset(leftPad, y),
      Offset(size.width, y),
      gridPaint,
    );
    final label = shortAxis((niceMax * i / 3).round());
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(color: textColor, fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(leftPad - tp.width - 6, y - tp.height / 2));
  }
}

/// Gambar grid vertikal tipis (untuk line chart ala mockup).
void paintVerticalGrid(
  Canvas canvas,
  Size size,
  int count,
  Color textColor, {
  double leftPad = 36,
  double topPad = 8,
  double bottomPad = 24,
}) {
  if (count <= 1) return;
  final chartW = size.width - leftPad;
  final chartH = size.height - bottomPad - topPad;
  final gridPaint = Paint()
    ..color = textColor.withValues(alpha: 0.08)
    ..strokeWidth = 1;
  for (var i = 0; i < count; i++) {
    final x = leftPad + chartW * i / (count - 1);
    canvas.drawLine(
      Offset(x, topPad),
      Offset(x, topPad + chartH),
      gridPaint,
    );
  }
}

/// Grouped bar chart: dua bar per grup dengan warna konfigurabel.
class GroupedBarsPainter extends CustomPainter {
  final List<int> first;
  final List<int> second;
  final List<String> labels;
  final Color textColor;
  final Color firstColor;
  final Color secondColor;

  GroupedBarsPainter({
    required this.first,
    required this.second,
    required this.labels,
    required this.textColor,
    this.firstColor = const Color(0xFF27AE60),
    this.secondColor = const Color(0xFFF08080),
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (first.isEmpty) return;
    final maxVal =
        [...first, ...second].fold<int>(0, (a, b) => a > b ? a : b);
    if (maxVal <= 0) return;

    const leftPad = 44.0;
    const bottomPad = 24.0;
    const topPad = 8.0;
    final chartW = size.width - leftPad;
    final chartH = size.height - bottomPad - topPad;
    final niceMax = niceCeiling(maxVal);

    paintYGrid(canvas, size, maxVal, textColor,
        leftPad: leftPad, topPad: topPad, bottomPad: bottomPad);

    final n = first.length;
    final groupW = chartW / n;
    final barW = (groupW * 0.42).clamp(12.0, 36.0);
    final firstPaint = Paint()..color = firstColor;
    final secondPaint = Paint()..color = secondColor;
    for (var i = 0; i < n; i++) {
      final cx = leftPad + groupW * i + groupW / 2;
      final fh = chartH * first[i] / niceMax;
      if (fh > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(cx - barW - 2, topPad + chartH - fh, barW, fh),
            const Radius.circular(6),
          ),
          firstPaint,
        );
      }
      final sh = chartH * second[i] / niceMax;
      if (sh > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(cx + 2, topPad + chartH - sh, barW, sh),
            const Radius.circular(6),
          ),
          secondPaint,
        );
      }
      if (i < labels.length) {
        final tp = TextPainter(
          text: TextSpan(
            text: labels[i],
            style: TextStyle(color: textColor, fontSize: 11),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: groupW);
        tp.paint(
          canvas,
          Offset(cx - tp.width / 2, size.height - bottomPad + 6),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant GroupedBarsPainter old) =>
      old.first != first || old.second != second;
}

/// Line chart dengan area fill + dot.
class LineChartPainter extends CustomPainter {
  final List<int> values;
  final List<String> labels;
  final Color textColor;
  final Color lineColor;

  LineChartPainter({
    required this.values,
    required this.labels,
    required this.textColor,
    this.lineColor = const Color(0xFFEB5757),
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxVal = values.fold<int>(0, (a, b) => a > b ? a : b);
    if (maxVal <= 0) return;
    final niceMax = niceCeiling(maxVal);

    const leftPad = 44.0;
    const bottomPad = 24.0;
    const topPad = 8.0;
    final chartW = size.width - leftPad;
    final chartH = size.height - bottomPad - topPad;

    paintYGrid(canvas, size, maxVal, textColor,
        leftPad: leftPad, topPad: topPad, bottomPad: bottomPad);
    paintVerticalGrid(canvas, size, values.length, textColor,
        leftPad: leftPad, topPad: topPad, bottomPad: bottomPad);

    final n = values.length;
    final pts = <Offset>[];
    for (var i = 0; i < n; i++) {
      final x =
          n == 1 ? leftPad + chartW / 2 : leftPad + chartW * i / (n - 1);
      final y = topPad + chartH - (chartH * values[i] / niceMax);
      pts.add(Offset(x, y));
    }

    // Area fill.
    final areaPath = Path()..moveTo(pts.first.dx, topPad + chartH);
    for (final p in pts) {
      areaPath.lineTo(p.dx, p.dy);
    }
    areaPath.lineTo(pts.last.dx, topPad + chartH);
    areaPath.close();
    canvas.drawPath(
      areaPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            lineColor.withValues(alpha: 0.25),
            lineColor.withValues(alpha: 0.02),
          ],
        ).createShader(
          Rect.fromLTWH(leftPad, topPad, chartW, chartH),
        ),
    );

    // Garis.
    final linePath = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      linePath.lineTo(pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = lineColor
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Dot.
    final dotFill = Paint()..color = Colors.white;
    final dotStroke = Paint()
      ..color = lineColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    for (final p in pts) {
      canvas.drawCircle(p, 4, dotFill);
      canvas.drawCircle(p, 4, dotStroke);
    }

    // Label.
    for (var i = 0; i < n && i < labels.length; i++) {
      final tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(color: textColor, fontSize: 11),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(pts[i].dx - tp.width / 2, size.height - bottomPad + 6),
      );
    }
  }

  @override
  bool shouldRepaint(covariant LineChartPainter old) =>
      old.values != values;
}

/// Bar chart harian: 1..N bar tipis.
class DailyBarsPainter extends CustomPainter {
  final List<int> values;
  final Color textColor;
  final Color barColor;

  DailyBarsPainter({
    required this.values,
    required this.textColor,
    this.barColor = const Color(0xFFF4A6A6),
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxVal = values.fold<int>(0, (a, b) => a > b ? a : b);
    if (maxVal <= 0) return;

    const leftPad = 40.0;
    const bottomPad = 24.0;
    const topPad = 8.0;
    final chartW = size.width - leftPad;
    final chartH = size.height - bottomPad - topPad;

    paintYGrid(
      canvas,
      size,
      maxVal,
      textColor,
      leftPad: leftPad,
    );

    final n = values.length;
    final slotW = chartW / n;
    final barW = (slotW * 0.6).clamp(3.0, 12.0);
    final barPaint = Paint()..color = barColor;
    for (var i = 0; i < n; i++) {
      final h = chartH * values[i] / maxVal;
      if (h <= 0) continue;
      final x = leftPad + slotW * i + (slotW - barW) / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, topPad + chartH - h, barW, h),
          const Radius.circular(2),
        ),
        barPaint,
      );
    }

    // Label tanggal sparse: 1, 5, 10, 15, 20, 25, N.
    final showDays = {1, 5, 10, 15, 20, 25, n};
    for (var d = 1; d <= n; d++) {
      if (!showDays.contains(d)) continue;
      final x = leftPad + slotW * (d - 1) + slotW / 2;
      paintLabel(
        canvas,
        '$d',
        Offset(x - 8, size.height - bottomPad + 6),
        textColor,
      );
    }
  }

  @override
  bool shouldRepaint(covariant DailyBarsPainter old) =>
      old.values != values;
}

/// Mini bar chart untuk banner (ilustrasi tren naik).
class MiniBarsPainter extends CustomPainter {
  final Color barColor;

  MiniBarsPainter({this.barColor = const Color(0xFFF4A6A6)});

  @override
  void paint(Canvas canvas, Size size) {
    // 4 bar menanjak + panah.
    final paint = Paint()..color = barColor;
    final heights = [0.35, 0.5, 0.65, 1.0];
    final barW = size.width / (heights.length * 2);
    for (var i = 0; i < heights.length; i++) {
      final h = size.height * heights[i];
      final x = barW * 0.5 + i * barW * 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, size.height - h, barW, h),
          const Radius.circular(3),
        ),
        paint,
      );
    }
    // Panah naik.
    final arrowPaint = Paint()
      ..color = const Color(0xFFEB5757)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final arrowPath = Path()
      ..moveTo(4, size.height * 0.35)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.1,
        size.width - 8,
        8,
      );
    canvas.drawPath(arrowPath, arrowPaint);
    // Kepala panah.
    canvas.drawPath(
      Path()
        ..moveTo(size.width - 8, 8)
        ..lineTo(size.width - 18, 10)
        ..moveTo(size.width - 8, 8)
        ..lineTo(size.width - 10, 18),
      arrowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant MiniBarsPainter old) => false;
}
