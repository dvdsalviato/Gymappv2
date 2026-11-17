import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';

const _tinte = [
  Color(0xFFFF0000),
  Color(0xFFFFFF00),
  Color(0xFF00FF00),
  Color(0xFF00FFFF),
  Color(0xFF0000FF),
  Color(0xFFFF00FF),
  Color(0xFFFF0000),
];

/// Apre il cerchio dei colori: scegli tinta (giro) e intensità (distanza
/// dal centro), vedi l'anteprima e applichi.
Future<void> mostraRuotaColori(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _FoglioRuota(),
  );
}

class _FoglioRuota extends StatefulWidget {
  const _FoglioRuota();

  @override
  State<_FoglioRuota> createState() => _FoglioRuotaState();
}

class _FoglioRuotaState extends State<_FoglioRuota> {
  late HSVColor _hsv = HSVColor.fromColor(Color(ThemeController.personalizzato.value));

  void _tocca(Offset punto, double lato) {
    final centro = Offset(lato / 2, lato / 2);
    final d = punto - centro;
    final raggio = lato / 2;
    var angolo = math.atan2(d.dy, d.dx) * 180 / math.pi;
    if (angolo < 0) angolo += 360;
    final distanza = math.min(1.0, d.distance / raggio);
    setState(() => _hsv = HSVColor.fromAHSV(1, angolo, math.max(0.15, distanza), 1));
  }

  @override
  Widget build(BuildContext context) {
    final scuro = Theme.of(context).brightness == Brightness.dark;
    final varianti = coloreDaBase(_hsv.toColor());
    final anteprima = scuro ? varianti.scuro : varianti.chiaro;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Il tuo colore', style: GoogleFonts.oswald(fontSize: 24, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              'Gira per la tinta, verso il centro per un colore più tenue.',
              style: TextStyle(color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            LayoutBuilder(builder: (context, vincoli) {
              final lato = math.min(260.0, vincoli.maxWidth);
              return GestureDetector(
                onPanDown: (d) => _tocca(d.localPosition, lato),
                onPanUpdate: (d) => _tocca(d.localPosition, lato),
                child: SizedBox(
                  width: lato,
                  height: lato,
                  child: CustomPaint(painter: _PittoreRuota(_hsv)),
                ),
              );
            }),
            const SizedBox(height: 18),
            // Anteprima con le varianti già rese leggibili.
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: anteprima, borderRadius: BorderRadius.circular(24)),
                    child: const Text('Pulsante', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: coloreCard(context),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: anteprima),
                    ),
                    child: Text('Testo', style: TextStyle(color: anteprima, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                ThemeController.scegliPersonalizzato(_hsv.toColor().toARGB32(), indiceColorePersonalizzato);
                Navigator.pop(context);
              },
              style: FilledButton.styleFrom(backgroundColor: anteprima),
              child: const Text('Applica'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PittoreRuota extends CustomPainter {
  final HSVColor scelto;
  _PittoreRuota(this.scelto);

  @override
  void paint(Canvas canvas, Size size) {
    final centro = size.center(Offset.zero);
    final raggio = size.shortestSide / 2;
    final cerchio = Rect.fromCircle(center: centro, radius: raggio);
    canvas.drawCircle(centro, raggio, Paint()..shader = const SweepGradient(colors: _tinte).createShader(cerchio));
    // Verso il centro il colore sbiadisce nel bianco.
    canvas.drawCircle(
      centro,
      raggio,
      Paint()
        ..shader = const RadialGradient(colors: [Colors.white, Color(0x00FFFFFF)]).createShader(cerchio),
    );
    // Selettore
    final angolo = scelto.hue * math.pi / 180;
    final punto = centro + Offset(math.cos(angolo), math.sin(angolo)) * (scelto.saturation * raggio);
    canvas.drawCircle(punto, 14, Paint()..color = scelto.toColor());
    canvas.drawCircle(
      punto,
      14,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.white,
    );
    canvas.drawCircle(
      punto,
      16,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.black54,
    );
  }

  @override
  bool shouldRepaint(_PittoreRuota old) => old.scelto != scelto;
}
