import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../data/rango.dart';

IconData iconaRango(int livello) {
  switch (livello) {
    case 0:
      return Icons.shield_outlined;
    case 1:
    case 2:
      return Icons.shield;
    case 3:
      return Icons.military_tech;
    case 4:
      return Icons.workspace_premium;
    case 5:
      return Icons.diamond;
    default:
      return Icons.auto_awesome;
  }
}

/// Stemma esagonale del rango, colorato in base al livello.
class EmblemaRango extends StatelessWidget {
  final int livello;
  final double dimensione;

  const EmblemaRango({super.key, required this.livello, this.dimensione = 80});

  @override
  Widget build(BuildContext context) {
    final l = livello.clamp(0, livelliRango.length - 1);
    return SizedBox(
      width: dimensione,
      height: dimensione,
      child: CustomPaint(
        painter: _EmblemaPainter(livelliRango[l].colore, l),
        child: Center(
          child: Icon(iconaRango(l), size: dimensione * 0.42, color: Colors.black.withOpacity(0.78)),
        ),
      ),
    );
  }
}

class _EmblemaPainter extends CustomPainter {
  final Color colore;
  final int livello;
  _EmblemaPainter(this.colore, this.livello);

  Path _esagono(Offset c, double r) {
    final p = Path();
    for (var i = 0; i < 6; i++) {
      final a = -math.pi / 2 + i * math.pi / 3;
      final pt = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
      if (i == 0) {
        p.moveTo(pt.dx, pt.dy);
      } else {
        p.lineTo(pt.dx, pt.dy);
      }
    }
    p.close();
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 2;
    final esterno = _esagono(c, r);
    if (livello >= 3) {
      canvas.drawPath(
        esterno,
        Paint()
          ..color = colore.withOpacity(0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }
    final chiaro = Color.lerp(colore, Colors.white, 0.45) ?? colore;
    canvas.drawPath(
      esterno,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [chiaro, colore],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      esterno,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.black.withOpacity(0.35),
    );
    canvas.drawPath(
      _esagono(c, r * 0.78),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = Colors.white.withOpacity(0.55),
    );
  }

  @override
  bool shouldRepaint(_EmblemaPainter old) => old.colore != colore || old.livello != livello;
}
