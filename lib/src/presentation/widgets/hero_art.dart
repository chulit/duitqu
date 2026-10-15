import 'package:flutter/material.dart';

/// Ilustrasi sederhana untuk kartu saldo: matahari, awan, bukit, rumah.
/// Digambar ulang (bukan aset mockup) dengan gaya flat yang serasi.
class HeroArt extends StatelessWidget {
  const HeroArt({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _HeroArtPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _HeroArtPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Matahari.
    final sunPaint = Paint()..color = const Color(0xFFFFD66B);
    canvas.drawCircle(Offset(w * 0.78, h * 0.28), w * 0.13, sunPaint);
    final sunHalo = Paint()
      ..color = const Color(0xFFFFD66B).withValues(alpha: 0.35);
    canvas.drawCircle(Offset(w * 0.78, h * 0.28), w * 0.18, sunHalo);

    // Awan.
    final cloudPaint = Paint()..color = Colors.white.withValues(alpha: 0.95);
    void cloud(double cx, double cy, double s) {
      canvas.drawCircle(Offset(cx, cy), s, cloudPaint);
      canvas.drawCircle(
        Offset(cx + s * 0.9, cy - s * 0.25),
        s * 0.75,
        cloudPaint,
      );
      canvas.drawCircle(
        Offset(cx - s * 0.9, cy - s * 0.15),
        s * 0.7,
        cloudPaint,
      );
      canvas.drawRRect(
        RRect.fromLTRBR(
          cx - s * 1.2,
          cy - s * 0.1,
          cx + s * 1.2,
          cy + s * 0.55,
          Radius.circular(s * 0.5),
        ),
        cloudPaint,
      );
    }

    cloud(w * 0.32, h * 0.3, w * 0.075);
    cloud(w * 0.62, h * 0.52, w * 0.055);

    // Bukit belakang.
    final hillBack = Paint()..color = const Color(0xFF7BC96F);
    final backPath = Path()
      ..moveTo(w * 0.05, h)
      ..quadraticBezierTo(w * 0.3, h * 0.45, w * 0.62, h * 0.78)
      ..quadraticBezierTo(w * 0.85, h * 0.95, w * 1.05, h * 0.7)
      ..lineTo(w * 1.05, h)
      ..close();
    canvas.drawPath(backPath, hillBack);

    // Rumah.
    final houseX = w * 0.52;
    final houseY = h * 0.62;
    final hw = w * 0.2;
    final hh = h * 0.2;
    final wallPaint = Paint()..color = const Color(0xFFFFF6E8);
    final roofPaint = Paint()..color = const Color(0xFFE8734A);
    // Dinding.
    canvas.drawRRect(
      RRect.fromLTRBR(
        houseX,
        houseY,
        houseX + hw,
        houseY + hh,
        const Radius.circular(2),
      ),
      wallPaint,
    );
    // Atap.
    final roof = Path()
      ..moveTo(houseX - hw * 0.12, houseY + 2)
      ..lineTo(houseX + hw * 0.5, houseY - hh * 0.55)
      ..lineTo(houseX + hw * 1.12, houseY + 2)
      ..close();
    canvas.drawPath(roof, roofPaint);
    // Pintu + jendela.
    final doorPaint = Paint()..color = const Color(0xFF8A5A3B);
    canvas.drawRRect(
      RRect.fromLTRBR(
        houseX + hw * 0.4,
        houseY + hh * 0.45,
        houseX + hw * 0.62,
        houseY + hh,
        const Radius.circular(2),
      ),
      doorPaint,
    );
    final winPaint = Paint()..color = const Color(0xFFBEE3F8);
    canvas.drawRect(
      Rect.fromLTWH(
        houseX + hw * 0.12,
        houseY + hh * 0.25,
        hw * 0.2,
        hh * 0.22,
      ),
      winPaint,
    );

    // Bukit depan.
    final hillFront = Paint()..color = const Color(0xFF5DBB63);
    final frontPath = Path()
      ..moveTo(-w * 0.05, h)
      ..quadraticBezierTo(w * 0.25, h * 0.72, w * 0.55, h * 0.92)
      ..quadraticBezierTo(w * 0.8, h * 1.02, w * 1.05, h * 0.88)
      ..lineTo(w * 1.05, h)
      ..close();
    canvas.drawPath(frontPath, hillFront);

    // Pohon kecil.
    void tree(double x, double y, double s) {
      final trunk = Paint()..color = const Color(0xFF8A5A3B);
      canvas.drawRect(Rect.fromLTWH(x - s * 0.06, y, s * 0.12, s * 0.5), trunk);
      final leaf = Paint()..color = const Color(0xFF3E9B4F);
      canvas.drawCircle(Offset(x, y - s * 0.1), s * 0.28, leaf);
      canvas.drawCircle(Offset(x - s * 0.18, y + s * 0.05), s * 0.2, leaf);
      canvas.drawCircle(Offset(x + s * 0.18, y + s * 0.05), s * 0.2, leaf);
    }

    tree(w * 0.18, h * 0.88, w * 0.09);
    tree(w * 0.88, h * 0.9, w * 0.07);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
