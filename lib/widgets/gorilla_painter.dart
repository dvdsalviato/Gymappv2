import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../data/pet.dart';

double _lerp(double a, double b, double t) => a + (b - a) * t;

/// Disegna il Gorilla: più è "grasso" più è largo, e l'espressione cambia
/// con l'umore. Lo spazio di disegno è 200 x 230.
class GorillaPainter extends CustomPainter {
  final double grasso; // 0 = scolpito, 1 = molto in carne
  final UmorePet umore;

  const GorillaPainter({required this.grasso, required this.umore});

  @override
  void paint(Canvas canvas, Size size) {
    const w = 200.0;
    const h = 230.0;
    final sc = math.min(size.width / w, size.height / h);
    canvas.save();
    canvas.translate((size.width - w * sc) / 2, (size.height - h * sc) / 2);
    canvas.scale(sc, sc);

    final g = grasso.clamp(0.0, 1.0).toDouble();
    const lime = Color(0xFF39FF14);
    final pelo = Paint()..color = const Color(0xFF2B2B33);
    final peloChiaro = Paint()..color = const Color(0xFF3A3A45);
    final faccia = Paint()..color = const Color(0xFFC08A5B);
    final contorno = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = lime.withOpacity(0.55);

    // Ombra
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(100, 224), width: _lerp(90, 150, g), height: 12),
      Paint()..color = Colors.black.withOpacity(0.35),
    );

    final bw = _lerp(100, 168, g);
    final bh = _lerp(92, 104, g);

    // Gambe
    for (final lato in [-1.0, 1.0]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(100 + lato * bw * 0.22, 210), width: 44, height: 28),
        pelo,
      );
    }

    // Braccia
    for (final lato in [-1.0, 1.0]) {
      canvas.save();
      canvas.translate(100 + lato * (bw / 2 - 4), 156);
      canvas.rotate(-lato * 0.18);
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: _lerp(26, 38, g), height: 84), pelo);
      canvas.drawCircle(Offset(0, 40), _lerp(11, 15, g), peloChiaro);
      canvas.restore();
    }

    // Corpo e pancia
    final corpo = Rect.fromCenter(center: const Offset(100, 158), width: bw, height: bh);
    canvas.drawOval(corpo, pelo);
    canvas.drawOval(corpo, contorno);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(100, 166), width: bw * 0.62, height: bh * 0.72),
      peloChiaro,
    );

    // Muscoli visibili quando è in forma
    if (g < 0.45) {
      final linea = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = lime.withOpacity(0.5);
      final pettorali = Path()
        ..moveTo(78, 146)
        ..quadraticBezierTo(100, 158, 122, 146);
      canvas.drawPath(pettorali, linea);
      canvas.drawLine(const Offset(100, 154), const Offset(100, 192), linea);
      for (final y in [164.0, 175.0, 186.0]) {
        canvas.drawLine(Offset(89, y), Offset(111, y), linea);
      }
    }

    // Testa
    canvas.drawCircle(const Offset(100, 88), 40, pelo);
    canvas.drawCircle(const Offset(100, 88), 40, contorno);
    canvas.drawOval(Rect.fromCenter(center: const Offset(100, 56), width: 44, height: 24), pelo);
    for (final x in [61.0, 139.0]) {
      canvas.drawCircle(Offset(x, 92), 11, pelo);
      canvas.drawCircle(Offset(x, 92), 6, faccia);
    }
    canvas.drawOval(Rect.fromCenter(center: const Offset(100, 98), width: 64, height: 54), faccia);

    // Fascia sulla fronte quando è in forma
    if (g < 0.55) {
      final fascia = Path()
        ..moveTo(62, 70)
        ..quadraticBezierTo(100, 55, 138, 70);
      canvas.drawPath(
        fascia,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round
          ..color = lime,
      );
    }

    // Occhi
    final triste = umore == UmorePet.triste;
    final sclera = Paint()..color = Colors.white;
    final iride = Paint()..color = const Color(0xFF111114);
    for (final x in [86.0, 114.0]) {
      canvas.drawOval(Rect.fromCenter(center: Offset(x, 90), width: 13, height: triste ? 8 : 12), sclera);
      canvas.drawCircle(Offset(x, triste ? 92 : 91), 3.4, iride);
    }

    // Sopracciglia
    final sopr = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF16161A);
    switch (umore) {
      case UmorePet.felice:
        canvas.drawLine(const Offset(79, 81), const Offset(93, 79), sopr);
        canvas.drawLine(const Offset(107, 79), const Offset(121, 81), sopr);
        break;
      case UmorePet.contento:
        canvas.drawLine(const Offset(79, 80), const Offset(93, 80), sopr);
        canvas.drawLine(const Offset(107, 80), const Offset(121, 80), sopr);
        break;
      case UmorePet.affamato:
        canvas.drawLine(const Offset(79, 84), const Offset(93, 79), sopr);
        canvas.drawLine(const Offset(107, 79), const Offset(121, 84), sopr);
        break;
      case UmorePet.triste:
        canvas.drawLine(const Offset(79, 86), const Offset(93, 78), sopr);
        canvas.drawLine(const Offset(107, 78), const Offset(121, 86), sopr);
        break;
    }

    // Naso e bocca
    canvas.drawCircle(const Offset(94, 103), 2, iride);
    canvas.drawCircle(const Offset(106, 103), 2, iride);
    final bocca = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF3B1F14);
    final b = Path();
    switch (umore) {
      case UmorePet.felice:
        b
          ..moveTo(84, 112)
          ..quadraticBezierTo(100, 128, 116, 112);
        break;
      case UmorePet.contento:
        b
          ..moveTo(88, 114)
          ..quadraticBezierTo(100, 122, 112, 114);
        break;
      case UmorePet.affamato:
        b
          ..moveTo(88, 118)
          ..lineTo(112, 118);
        break;
      case UmorePet.triste:
        b
          ..moveTo(86, 121)
          ..quadraticBezierTo(100, 110, 114, 121);
        break;
    }
    canvas.drawPath(b, bocca);

    // Lacrima quando è molto triste
    if (triste) {
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(121, 101), width: 6, height: 10),
        Paint()..color = Colors.lightBlueAccent,
      );
    }

    // Scintille quando è scolpito
    if (g < 0.06) {
      final s = Paint()..color = lime;
      for (final p in const [Offset(34, 52), Offset(168, 48), Offset(28, 118), Offset(176, 120)]) {
        canvas.drawCircle(p, 3, s);
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(GorillaPainter old) => old.grasso != grasso || old.umore != umore;
}
