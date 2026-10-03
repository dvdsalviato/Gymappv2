import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/muscoli.dart';
import '../db/database_helper.dart';
import '../theme/app_theme.dart';

const _coloreRiposo = Color(0xFF2E2E35);
const _coloreNeutro = Color(0xFF24242A);
const _coloreBasso = Color(0xFF5E9E2A);
const _coloreOttimale = Color(0xFF39FF14);
const _coloreAlto = Color(0xFFFF5A1F);

Color coloreVolume(int n) {
  if (n <= 0) return _coloreRiposo;
  if (n <= 8) return _coloreBasso;
  if (n <= 18) return _coloreOttimale;
  return _coloreAlto;
}

// ---------------------------------------------------------------------------
// Disegno del corpo (spazio 200 x 420). Ogni muscolo è una forma morbida
// costruita da pochi punti; le forme "a coppia" vengono specchiate.
// ---------------------------------------------------------------------------

class _Regione {
  final String? muscolo; // null = parte neutra (testa, mani, ecc.)
  final Path path;
  const _Regione(this.muscolo, this.path);
}

Offset _medio(Offset a, Offset b) => Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);

Path _forma(List<Offset> p) {
  final path = Path();
  final start = _medio(p.last, p.first);
  path.moveTo(start.dx, start.dy);
  for (var i = 0; i < p.length; i++) {
    final cur = p[i];
    final next = p[(i + 1) % p.length];
    final m = _medio(cur, next);
    path.quadraticBezierTo(cur.dx, cur.dy, m.dx, m.dy);
  }
  path.close();
  return path;
}

List<Offset> _punti(List<double> xy) => [
      for (var i = 0; i < xy.length; i += 2) Offset(xy[i], xy[i + 1]),
    ];

List<Offset> _specchia(List<Offset> p) =>
    p.map((o) => Offset(200 - o.dx, o.dy)).toList().reversed.toList();

void _coppia(List<_Regione> out, String? muscolo, List<double> xy) {
  final sx = _punti(xy);
  out.add(_Regione(muscolo, _forma(sx)));
  out.add(_Regione(muscolo, _forma(_specchia(sx))));
}

Path _rr(double l, double t, double r, double b, double raggio) =>
    Path()..addRRect(RRect.fromLTRBR(l, t, r, b, Radius.circular(raggio)));

List<_Regione> _costruisciRegioni(bool retro) {
  final r = <_Regione>[];

  // Parti neutre
  r.add(_Regione(null, Path()..addOval(const Rect.fromLTRB(80, 4, 120, 52))));
  r.add(_Regione(null, _rr(91, 50, 109, 70, 6)));
  _coppia(r, null, [34, 164, 52, 160, 56, 190, 46, 222, 36, 222, 30, 192]); // avambracci
  _coppia(r, null, [36, 224, 50, 224, 52, 238, 43, 247, 34, 238]); // mani
  _coppia(r, null, [70, 396, 94, 396, 96, 410, 88, 417, 68, 414]); // piedi

  if (!retro) {
    _coppia(r, 'trapezio', [100, 66, 86, 68, 64, 80, 74, 87, 100, 85]);
    _coppia(r, 'pettorali', [100, 84, 72, 84, 62, 100, 68, 120, 86, 128, 100, 124]);
    _coppia(r, 'addominali', [66, 124, 82, 132, 82, 206, 74, 204, 66, 170]); // obliqui
    for (var i = 0; i < 4; i++) {
      final y = 130.0 + i * 21;
      r.add(_Regione('addominali', _rr(84, y, 99, y + 18, 6)));
      r.add(_Regione('addominali', _rr(101, y, 116, y + 18, 6)));
    }
    _coppia(r, 'deltoidi', [62, 76, 46, 80, 36, 96, 40, 116, 54, 114, 64, 96]);
    _coppia(r, 'bicipiti', [41, 114, 56, 112, 58, 140, 53, 160, 42, 158, 38, 136]);
    _coppia(r, 'quadricipiti', [68, 208, 99, 206, 98, 262, 91, 302, 78, 302, 70, 262, 65, 232]);
    _coppia(r, 'polpacci', [73, 310, 92, 310, 91, 372, 83, 396, 76, 374]);
  } else {
    _coppia(r, 'trapezio', [100, 62, 84, 68, 62, 80, 80, 96, 100, 118]);
    _coppia(r, 'dorsali', [100, 118, 82, 100, 68, 104, 66, 128, 78, 160, 100, 172]);
    _coppia(r, 'lombari', [100, 174, 86, 166, 82, 192, 100, 200]);
    _coppia(r, 'deltoidi', [62, 76, 46, 80, 36, 96, 40, 116, 54, 114, 64, 96]);
    _coppia(r, 'tricipiti', [41, 114, 56, 112, 58, 140, 53, 160, 42, 158, 38, 136]);
    _coppia(r, 'glutei', [100, 200, 74, 198, 66, 222, 80, 242, 100, 238]);
    _coppia(r, 'femorali', [68, 246, 99, 242, 98, 300, 80, 304, 70, 272]);
    _coppia(r, 'polpacci', [70, 308, 94, 308, 92, 372, 84, 396, 74, 374]);
  }
  return r;
}

class _CorpoPainter extends CustomPainter {
  final List<_Regione> regioni;
  final Map<String, int> volumi;
  final String? selezionato;
  _CorpoPainter(this.regioni, this.volumi, this.selezionato);

  @override
  void paint(Canvas canvas, Size size) {
    final scala = size.width / 200;
    canvas.save();
    canvas.scale(scala, scala);
    final contorno = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = Colors.black.withOpacity(0.6);

    for (final reg in regioni) {
      final id = reg.muscolo;
      final n = id == null ? 0 : (volumi[id] ?? 0);
      final colore = id == null ? _coloreNeutro : coloreVolume(n);
      if (n > 0) {
        canvas.drawPath(
          reg.path,
          Paint()
            ..color = colore.withOpacity(0.5)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
        );
      }
      canvas.drawPath(reg.path, Paint()..color = colore);
      canvas.drawPath(reg.path, contorno);
      if (id != null && id == selezionato) {
        canvas.drawPath(
          reg.path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4
            ..color = Colors.white,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CorpoPainter old) =>
      old.volumi != volumi || old.selezionato != selezionato || old.regioni != regioni;
}

class _Corpo extends StatelessWidget {
  final List<_Regione> regioni;
  final Map<String, int> volumi;
  final String? selezionato;
  final ValueChanged<String> onTap;

  const _Corpo({
    required this.regioni,
    required this.volumi,
    required this.selezionato,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, vincoli) {
        final w = vincoli.maxWidth;
        final h = w * 2.1;
        final scala = w / 200;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) {
            final p = d.localPosition / scala;
            for (final reg in regioni.reversed) {
              final id = reg.muscolo;
              if (id != null && reg.path.contains(p)) {
                onTap(id);
                return;
              }
            }
          },
          child: SizedBox(
            width: w,
            height: h,
            child: CustomPaint(painter: _CorpoPainter(regioni, volumi, selezionato)),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------

class MappaMuscolareScreen extends StatefulWidget {
  const MappaMuscolareScreen({super.key});

  @override
  State<MappaMuscolareScreen> createState() => _MappaMuscolareScreenState();
}

class _MappaMuscolareScreenState extends State<MappaMuscolareScreen> {
  static final _fronte = _costruisciRegioni(false);
  static final _retro = _costruisciRegioni(true);

  bool _loading = true;
  List<Map<String, dynamic>> _recenti = [];
  Map<String, int> _volumi = {};
  String? _selezionato;

  @override
  void initState() {
    super.initState();
    _carica();
  }

  Future<void> _carica() async {
    final recenti = await DatabaseHelper.instance.getEserciziRecenti(giorni: 7);
    final volumi = <String, int>{};
    for (final r in recenti) {
      final id = muscoloDi(r['nome'] as String, r['categoria'] as String);
      if (id == null) continue;
      volumi[id] = (volumi[id] ?? 0) + (r['serie'] as int);
    }
    if (!mounted) return;
    setState(() {
      _recenti = recenti;
      _volumi = volumi;
      _loading = false;
    });
  }

  String _fmtKg(num v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  String _giudizio(int n) {
    if (n == 0) return 'A riposo: nessuna serie negli ultimi 7 giorni.';
    if (n <= 8) return 'Volume basso (1-8 serie): va bene per mantenere, aumenta se vuoi crescere.';
    if (n <= 18) return 'Volume ottimale: 9-18 serie a settimana.';
    return 'Volume alto (oltre 18 serie): valuta di lasciarlo recuperare.';
  }

  void _apriDettaglio(String id) {
    setState(() => _selezionato = id);
    final m = muscoli.firstWhere((x) => x.id == id);
    final n = _volumi[id] ?? 0;
    final fatti = _recenti.where((r) => muscoloDi(r['nome'] as String, r['categoria'] as String) == id).toList();
    final nomiFatti = fatti.map((r) => r['nome'] as String).toSet();
    final consigliati = consigliatiPer(id, nomiFatti);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(width: 14, height: 14, decoration: BoxDecoration(color: coloreVolume(n), shape: BoxShape.circle)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      m.nome.toUpperCase(),
                      style: GoogleFonts.oswald(fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: 0.8),
                    ),
                  ),
                  Text('$n serie', style: const TextStyle(color: AppColors.accento, fontWeight: FontWeight.w700, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 6),
              Text(_giudizio(n), style: TextStyle(color: Colors.grey.shade500)),
              const SizedBox(height: 22),
              _titoloSezione('FATTO NEGLI ULTIMI 7 GIORNI'),
              if (fatti.isEmpty)
                Text('Nessun esercizio per questo muscolo.', style: TextStyle(color: Colors.grey.shade500))
              else
                for (final r in fatti)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(color: coloreChip(ctx), borderRadius: BorderRadius.circular(18)),
                    child: Row(
                      children: [
                        Expanded(child: Text(r['nome'] as String, style: const TextStyle(fontWeight: FontWeight.w600))),
                        const SizedBox(width: 8),
                        Text(
                          '${r['serie']} serie · ${_fmtKg(r['carico_max'] as num)} kg',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
              const SizedBox(height: 18),
              _titoloSezione(n > 18 ? 'ALTERNATIVE PER VARIARE' : 'ESERCIZI CONSIGLIATI'),
              if (consigliati.isEmpty)
                Text('Hai già fatto tutti gli esercizi del catalogo per questo muscolo.',
                    style: TextStyle(color: Colors.grey.shade500))
              else
                for (final nome in consigliati)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.accento.withOpacity(0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.add_circle_outline, color: AppColors.accento, size: 20),
                        const SizedBox(width: 10),
                        Expanded(child: Text(nome, style: const TextStyle(fontWeight: FontWeight.w600))),
                      ],
                    ),
                  ),
              const SizedBox(height: 10),
              Text(
                'Suggerimenti generali dal catalogo: aggiungili a una scheda dall\'editor.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    ).then((_) {
      if (mounted) setState(() => _selezionato = null);
    });
  }

  Widget _titoloSezione(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          t,
          style: TextStyle(
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w700,
            fontSize: 12,
            letterSpacing: 1.4,
          ),
        ),
      );

  Widget _classifica() {
    final voci = muscoli.where((m) => (_volumi[m.id] ?? 0) > 0).toList()
      ..sort((a, b) => (_volumi[b.id] ?? 0).compareTo(_volumi[a.id] ?? 0));
    final top = voci.take(6).toList();
    if (top.isEmpty) return const SizedBox.shrink();
    final massimo = (_volumi[top.first.id] ?? 1).toDouble();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: coloreSuperficie(context), borderRadius: BorderRadius.circular(28)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _titoloSezione('GRUPPI PIÙ ALLENATI'),
          for (final m in top)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: InkWell(
                onTap: () => _apriDettaglio(m.id),
                child: Row(
                  children: [
                    SizedBox(width: 104, child: Text(m.nome, style: const TextStyle(fontWeight: FontWeight.w600))),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: (_volumi[m.id] ?? 0) / massimo,
                          minHeight: 12,
                          backgroundColor: coloreChip(context),
                          color: coloreVolume(_volumi[m.id] ?? 0),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 36,
                      child: Text(
                        '${_volumi[m.id]}',
                        textAlign: TextAlign.end,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _chipMuscolo(Muscolo m) {
    final n = _volumi[m.id] ?? 0;
    return GestureDetector(
      onTap: () => _apriDettaglio(m.id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(color: coloreSuperficie(context), borderRadius: BorderRadius.circular(20)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: coloreVolume(n), shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text('${m.nome} · $n', style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _legenda() {
    final voci = [
      ('A riposo (0 serie)', _coloreRiposo),
      ('Mantenimento (1-8)', _coloreBasso),
      ('Volume ottimale (9-18)', _coloreOttimale),
      ('Alto volume (oltre 18)', _coloreAlto),
    ];
    return Wrap(
      spacing: 16,
      runSpacing: 6,
      children: [
        for (final v in voci)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 12, height: 12, decoration: BoxDecoration(color: v.$2, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(v.$1, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
            ],
          ),
      ],
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
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Serie degli ultimi 7 giorni. Tocca un muscolo per vedere cosa hai fatto e cosa fare.',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                    const SizedBox(height: 16),
                    _classifica(),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
                      decoration: BoxDecoration(
                        color: coloreSuperficie(context),
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _Corpo(
                                  regioni: _fronte,
                                  volumi: _volumi,
                                  selezionato: _selezionato,
                                  onTap: _apriDettaglio,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _Corpo(
                                  regioni: _retro,
                                  volumi: _volumi,
                                  selezionato: _selezionato,
                                  onTap: _apriDettaglio,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: Center(
                                  child: Text('FRONTE', style: TextStyle(color: Colors.grey.shade600, fontSize: 11, letterSpacing: 1.4)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Center(
                                  child: Text('RETRO', style: TextStyle(color: Colors.grey.shade600, fontSize: 11, letterSpacing: 1.4)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: muscoli.map(_chipMuscolo).toList(),
                    ),
                    const SizedBox(height: 18),
                    _legenda(),
                  ],
                ),
              ),
            ),
    );
  }
}
