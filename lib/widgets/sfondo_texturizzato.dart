import 'dart:math';
import 'dart:ui' show PointMode;
import 'package:flutter/material.dart';

class SfondoTexturizzato extends StatelessWidget {
  final Widget child;
  final bool scuro;
  const SfondoTexturizzato({super.key, required this.child, required this.scuro});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(painter: _TexturePainter(scuro)),
            ),
          ),
        ),
      ],
    );
  }
}

class _TexturePainter extends CustomPainter {
  final bool scuro;
  _TexturePainter(this.scuro);

  @override
  void paint(Canvas canvas, Size size) {
    final colore = scuro ? Colors.white : Colors.black;
    final linee = Paint()
      ..color = colore.withOpacity(scuro ? 0.035 : 0.03)
      ..strokeWidth = 1;
    for (double x = -size.height; x < size.width; x += 7) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), linee);
    }
    final rnd = Random(7);
    final n = (size.width * size.height / 90).round();
    final punti = List.generate(
      n,
      (_) => Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height),
    );
    canvas.drawPoints(
      PointMode.points,
      punti,
      Paint()
        ..color = colore.withOpacity(scuro ? 0.07 : 0.06)
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(_TexturePainter old) => old.scuro != scuro;
}
