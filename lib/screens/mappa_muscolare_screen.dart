import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../theme/app_theme.dart';

const _categorieMappa = ['Petto', 'Spalle', 'Bicipiti', 'Tricipiti', 'Schiena', 'Core', 'Gambe'];

const _coloreRiposo = Color(0xFF2B2B31);
const _coloreNeutro = Color(0xFF222227);
const _coloreBasso = Color(0xFF5E9E2A);
const _coloreOttimale = Color(0xFF39FF14);
const _coloreAlto = Color(0xFFFF5A1F);

Color coloreVolume(int n) {
  if (n <= 0) return _coloreRiposo;
  if (n <= 8) return _coloreBasso;
  if (n <= 18) return _coloreOttimale;
  return _coloreAlto;
}

class MappaMuscolareScreen extends StatefulWidget {
  const MappaMuscolareScreen({super.key});

  @override
  State<MappaMuscolareScreen> createState() => _MappaMuscolareScreenState();
}

class _MappaMuscolareScreenState extends State<MappaMuscolareScreen> {
  bool _retro = false;
  bool _loading = true;
  Map<String, int> _volumi = {};

  @override
  void initState() {
    super.initState();
    _carica();
  }

  Future<void> _carica() async {
    setState(() => _loading = true);
    final volumi = await DatabaseHelper.instance.getVolumePerCategoria(giorni: 7);
    if (!mounted) return;
    setState(() {
      _volumi = volumi;
      _loading = false;
    });
  }

  Widget _legenda() {
    final voci = [
      ('A riposo (0 serie)', _coloreRiposo),
      ('Mantenimento (1-8)', _coloreBasso),
      ('Volume ottimale (9-18)', _coloreOttimale),
      ('Alto volume (oltre 18)', _coloreAlto),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: voci.map((v) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(width: 14, height: 14, decoration: BoxDecoration(color: v.$2, shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Text(v.$1, style: TextStyle(color: Colors.grey.shade500)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _chipMuscolo(String categoria) {
    final n = _volumi[categoria] ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: coloreChip(context),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: coloreVolume(n), shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text('$categoria · $n', style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mappa muscolare')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      'Serie fatte negli ultimi 7 giorni',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                    const SizedBox(height: 16),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: false, label: Text('Fronte')),
                        ButtonSegment(value: true, label: Text('Retro')),
                      ],
                      selected: {_retro},
                      onSelectionChanged: (s) => setState(() => _retro = s.first),
                      style: SegmentedButton.styleFrom(
                        selectedBackgroundColor: AppColors.accento,
                        selectedForegroundColor: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      decoration: BoxDecoration(
                        color: coloreCard(context),
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Center(
                        child: SizedBox(
                          width: 210,
                          height: 441,
                          child: CustomPaint(painter: _CorpoPainter(_volumi, _retro)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _categorieMappa.map(_chipMuscolo).toList(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: coloreCard(context),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Legenda', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          _legenda(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// Disegna il corpo (fronte o retro) in uno spazio 200 x 420 e colora ogni
/// gruppo muscolare in base alle serie fatte negli ultimi giorni.
class _CorpoPainter extends CustomPainter {
  final Map<String, int> volumi;
  final bool retro;
  _CorpoPainter(this.volumi, this.retro);

  @override
  void paint(Canvas canvas, Size size) {
    final scala = size.width / 200 < size.height / 420 ? size.width / 200 : size.height / 420;
    canvas.save();
    canvas.translate((size.width - 200 * scala) / 2, (size.height - 420 * scala) / 2);
    canvas.scale(scala, scala);

    void disegna(String? categoria, Path path) {
      final n = categoria == null ? 0 : (volumi[categoria] ?? 0);
      final colore = categoria == null ? _coloreNeutro : coloreVolume(n);
      if (n > 0) {
        canvas.drawPath(
          path,
          Paint()
            ..color = colore.withOpacity(0.55)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
        );
      }
      canvas.drawPath(path, Paint()..color = colore);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = Colors.black.withOpacity(0.55),
      );
    }

    Path rr(double l, double t, double r, double b, double raggio) =>
        Path()..addRRect(RRect.fromLTRBR(l, t, r, b, Radius.circular(raggio)));
    Path ov(double l, double t, double r, double b) => Path()..addOval(Rect.fromLTRB(l, t, r, b));

    // Parti sempre neutre
    disegna(null, ov(80, 4, 120, 52)); // testa
    disegna(null, rr(91, 50, 109, 70, 6)); // collo
    disegna(null, rr(36, 164, 54, 216, 9)); // avambraccio sx
    disegna(null, rr(146, 164, 164, 216, 9)); // avambraccio dx
    disegna(null, ov(35, 218, 55, 240)); // mano sx
    disegna(null, ov(145, 218, 165, 240)); // mano dx
    disegna(null, ov(73, 398, 99, 416)); // piede sx
    disegna(null, ov(101, 398, 127, 416)); // piede dx

    if (!retro) {
      disegna('Petto', rr(68, 80, 99, 122, 14));
      disegna('Petto', rr(101, 80, 132, 122, 14));
      for (var i = 0; i < 3; i++) {
        final y = 126.0 + i * 24;
        disegna('Core', rr(79, y, 98, y + 21, 6));
        disegna('Core', rr(102, y, 121, y + 21, 6));
      }
      disegna('Spalle', ov(45, 74, 77, 110));
      disegna('Spalle', ov(123, 74, 155, 110));
      disegna('Bicipiti', rr(40, 112, 58, 162, 9));
      disegna('Bicipiti', rr(142, 112, 160, 162, 9));
      disegna('Gambe', rr(72, 206, 99, 302, 14));
      disegna('Gambe', rr(101, 206, 128, 302, 14));
      disegna('Gambe', rr(75, 308, 97, 396, 10));
      disegna('Gambe', rr(103, 308, 125, 396, 10));
    } else {
      disegna(
        'Schiena',
        Path()
          ..moveTo(91, 70)
          ..lineTo(109, 70)
          ..lineTo(128, 86)
          ..lineTo(72, 86)
          ..close(),
      );
      disegna('Schiena', rr(68, 90, 99, 150, 14));
      disegna('Schiena', rr(101, 90, 132, 150, 14));
      disegna('Schiena', rr(80, 153, 120, 194, 10));
      disegna('Spalle', ov(45, 74, 77, 110));
      disegna('Spalle', ov(123, 74, 155, 110));
      disegna('Tricipiti', rr(40, 112, 58, 162, 9));
      disegna('Tricipiti', rr(142, 112, 160, 162, 9));
      disegna('Gambe', rr(74, 198, 99, 236, 16)); // glutei
      disegna('Gambe', rr(101, 198, 126, 236, 16));
      disegna('Gambe', rr(72, 240, 99, 302, 14)); // femorali
      disegna('Gambe', rr(101, 240, 128, 302, 14));
      disegna('Gambe', rr(75, 308, 97, 396, 10)); // polpacci
      disegna('Gambe', rr(103, 308, 125, 396, 10));
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_CorpoPainter old) => old.retro != retro || old.volumi != volumi;
}
