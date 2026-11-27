import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/muscoli.dart';
import '../data/progressione.dart';
import '../data/statistiche.dart';
import '../db/database_helper.dart';
import '../theme/app_theme.dart';
import 'mappa_muscolare_screen.dart';
import 'storico_esercizio_screen.dart';
import 'storico_screen.dart';

/// Massimale stimato (formula di Epley): quanto potresti sollevare per una
/// ripetizione, ricavato da carico e ripetizioni fatte.
double massimaleStimato(double carico, int rep) => rep <= 1 ? carico : carico * (1 + rep / 30);

class _Massimale {
  final String nome;
  final double attuale;
  final double? prima;
  final double carico; // la miglior serie vera dell'ultimo mese
  final int rep;
  const _Massimale(this.nome, this.attuale, this.prima, this.carico, this.rep);

  double? get variazione => (prima == null || prima! <= 0) ? null : (attuale - prima!) / prima! * 100;
}

class _Record {
  final String nome;
  final double carico;
  final int rep;
  final DateTime data;
  const _Record(this.nome, this.carico, this.rep, this.data);
}

/// Progressi: risponde a "sto migliorando?". Mappa del corpo, costanza, serie per muscolo
/// rispetto alla settimana scorsa, massimali stimati e record recenti.
class ProgressiScreen extends StatefulWidget {
  const ProgressiScreen({super.key});

  @override
  State<ProgressiScreen> createState() => _ProgressiScreenState();
}

class _ProgressiScreenState extends State<ProgressiScreen> {
  static const _mesi = ['gen', 'feb', 'mar', 'apr', 'mag', 'giu', 'lug', 'ago', 'set', 'ott', 'nov', 'dic'];
  static const _gruppi = ['Petto', 'Schiena', 'Gambe', 'Spalle', 'Bicipiti', 'Tricipiti', 'Core'];

  bool _loading = true;
  Set<DateTime> _presenze = {};
  Map<String, int> _settimana = {};
  Map<String, int> _settimanaPrima = {};
  List<_Massimale> _massimali = [];
  List<_Record> _record = [];
  Map<String, int> _volumiMuscoli = {};
  int _obiettivo = obiettivoPredefinito;

  @override
  void initState() {
    super.initState();
    _carica();
  }

  Future<void> _carica() async {
    final db = DatabaseHelper.instance;
    final presenze = await db.getGiorniPresenza();
    final settimana = await db.getSeriePerCategoriaTra(giorni: 7);
    final prima = await db.getSeriePerCategoriaTra(giorni: 7, finoAGiorniFa: 7);
    final serie = await db.getSerieForza();
    final muscoliSett = await volumiMuscoli();
    final obiettivo = await leggiObiettivoSettimanale();

    final adesso = DateTime.now();
    final limite30 = adesso.subtract(const Duration(days: 30));
    final limite90 = adesso.subtract(const Duration(days: 90));
    final attuale = <String, double>{};
    final miglioreSerie = <String, (double, int)>{};
    final precedente = <String, double>{};
    final massimoCarico = <String, double>{};
    final record = <_Record>[];

    for (final r in serie) {
      final nome = r['nome'] as String;
      final carico = (r['carico'] as num).toDouble();
      final rep = (r['rep'] as num).toInt();
      final data = DateTime.tryParse(r['data'] as String);
      if (data == null) continue;
      final stima = massimaleStimato(carico, rep);
      if (data.isAfter(limite30)) {
        if (stima > (attuale[nome] ?? 0)) {
          attuale[nome] = stima;
          miglioreSerie[nome] = (carico, rep);
        }
      } else if (data.isAfter(limite90)) {
        if (stima > (precedente[nome] ?? 0)) precedente[nome] = stima;
      }
      // Record: carico mai sollevato prima su quell'esercizio.
      final massimo = massimoCarico[nome];
      if (massimo != null && carico > massimo) record.add(_Record(nome, carico, rep, data));
      if (massimo == null || carico > massimo) massimoCarico[nome] = carico;
    }

    final massimali = [
      for (final e in attuale.entries)
        _Massimale(
          e.key,
          e.value,
          precedente[e.key],
          miglioreSerie[e.key]?.$1 ?? 0,
          miglioreSerie[e.key]?.$2 ?? 0,
        ),
    ]..sort((a, b) => b.attuale.compareTo(a.attuale));

    if (!mounted) return;
    setState(() {
      _presenze = presenze;
      _volumiMuscoli = muscoliSett;
      _obiettivo = obiettivo;
      _settimana = settimana;
      _settimanaPrima = prima;
      _massimali = massimali.take(8).toList();
      _record = record.reversed.take(5).toList();
      _loading = false;
    });
  }

  DateTime _giorno(DateTime d) => DateTime(d.year, d.month, d.day);
  DateTime _lunedi(DateTime d) => _giorno(d).subtract(Duration(days: d.weekday - 1));
  String _data(DateTime d) => '${d.day} ${_mesi[d.month - 1]}';

  /// Settimane consecutive con almeno un allenamento (la corrente conta se c'è).
  int get _settimaneDiFila {
    final settimane = {for (final d in _presenze) _lunedi(d)};
    var w = _lunedi(DateTime.now());
    if (!settimane.contains(w)) w = w.subtract(const Duration(days: 7));
    var n = 0;
    while (settimane.contains(w)) {
      n++;
      w = w.subtract(const Duration(days: 7));
    }
    return n;
  }

  int get _ultimi30 {
    final limite = _giorno(DateTime.now()).subtract(const Duration(days: 29));
    return _presenze.where((d) => !d.isBefore(limite)).length;
  }

  Widget _card({required String titolo, String? sottotitolo, required Widget figlio, Widget? azione}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: pannello(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TitoloSezione(titolo, azione: azione, padding: EdgeInsets.zero),
          if (sottotitolo != null) ...[
            const SizedBox(height: 4),
            Text(sottotitolo, style: TextStyle(color: Colors.grey.shade600, fontSize: 12, height: 1.3)),
          ],
          const SizedBox(height: 14),
          figlio,
        ],
      ),
    );
  }

  // ---- Muscoli (mappa del corpo) ----

  Future<void> _apriMappa() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const MappaMuscolareScreen()));
    _carica();
  }

  Widget _muscoli() {
    final allenati = _volumiMuscoli.values.where((n) => n > 0).length;
    final totale = _volumiMuscoli.values.fold<int>(0, (a, b) => a + b);
    return GestureDetector(
      onTap: _apriMappa,
      child: _card(
        titolo: 'Muscoli · ultimi 7 giorni',
        azione: TextButton(
          onPressed: _apriMappa,
          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: const Size(0, 32)),
          child: const Text('Dettagli'),
        ),
        figlio: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 5,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 260),
                    child: CorpoMuscoliCompatto(volumi: _volumiMuscoli),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _numeroLaterale('$totale', 'serie totali'),
                      const SizedBox(height: 18),
                      _numeroLaterale('$allenati/${muscoli.length}', 'muscoli\nallenati'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Align(alignment: Alignment.centerLeft, child: LegendaVolume()),
          ],
        ),
      ),
    );
  }

  Widget _numeroLaterale(String valore, String etichetta) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(valore, style: GoogleFonts.oswald(fontSize: 30, fontWeight: FontWeight.w700, height: 1)),
        const SizedBox(height: 4),
        Text(etichetta, style: TextStyle(color: Colors.grey.shade500, fontSize: 12, height: 1.2)),
      ],
    );
  }

  // ---- Costanza ----

  /// Ultime 12 settimane: una barra per settimana, fatta di tanti tasselli
  /// quanti sono i giorni di allenamento. La linea tratteggiata è l'obiettivo.
  Widget _costanza() {
    final scuro = Theme.of(context).brightness == Brightness.dark;
    final vuoto = (scuro ? Colors.white : Colors.black).withValues(alpha: 0.06);
    final oggi = _giorno(DateTime.now());
    final lunediOra = _lunedi(oggi);
    final fila = _settimaneDiFila;
    const settimane = 12;
    const tassello = 9.0;
    const spazio = 3.0;
    const altezzaBarre = 7 * tassello + 6 * spazio;
    final obiettivo = _obiettivo.clamp(1, 7);

    int giorniDi(DateTime lunedi) {
      var n = 0;
      for (var i = 0; i < 7; i++) {
        if (_presenze.contains(DateTime(lunedi.year, lunedi.month, lunedi.day + i))) n++;
      }
      return n;
    }

    final colonne = [
      for (var c = settimane - 1; c >= 0; c--) DateTime(lunediOra.year, lunediOra.month, lunediOra.day - 7 * c),
    ];
    final raggiunte = colonne.where((l) => giorniDi(l) >= obiettivo).length;

    return _card(
      titolo: 'Costanza',
      figlio: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$fila', style: GoogleFonts.oswald(fontSize: 52, fontWeight: FontWeight.w700, height: 1)),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    fila == 1 ? 'settimana di fila\ncon almeno un allenamento' : 'settimane di fila\ncon almeno un allenamento',
                    style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600, height: 1.25),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('$_ultimi30', style: GoogleFonts.oswald(fontSize: 28, fontWeight: FontWeight.w700, height: 1)),
                  Text('in 30 giorni', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: altezzaBarre,
            child: Stack(
              children: [
                // Linea dell'obiettivo settimanale.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: (obiettivo * (tassello + spazio) - spazio / 2 - 0.5).clamp(0.0, altezzaBarre - 1),
                  child: CustomPaint(
                    size: const Size(double.infinity, 1),
                    painter: _Tratteggio(Colors.grey.shade500.withValues(alpha: 0.7)),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < colonne.length; i++) ...[
                      if (i > 0) const SizedBox(width: 5),
                      Expanded(
                        child: Builder(builder: (context) {
                          final n = giorniDi(colonne[i]);
                          final corrente = i == colonne.length - 1;
                          final colore = n >= obiettivo
                              ? AppColors.accento
                              : AppColors.accento.withValues(alpha: 0.45);
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              for (var r = 6; r >= 0; r--) ...[
                                Container(
                                  height: tassello,
                                  decoration: BoxDecoration(
                                    color: r < n ? colore : (corrente ? Colors.transparent : vuoto),
                                    borderRadius: BorderRadius.circular(2),
                                    border: corrente && r >= n
                                        ? Border.all(color: AppColors.accento.withValues(alpha: 0.35))
                                        : null,
                                  ),
                                ),
                                if (r > 0) const SizedBox(height: spazio),
                              ],
                            ],
                          );
                        }),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (var i = 0; i < colonne.length; i++) ...[
                if (i > 0) const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    i == colonne.length - 1
                        ? 'ORA'
                        : ((i == 0 || colonne[i].month != colonne[i - 1].month)
                            ? _mesi[colonne[i].month - 1].toUpperCase()
                            : ''),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.visible,
                    softWrap: false,
                    style: TextStyle(
                      color: i == colonne.length - 1 ? AppColors.accento : Colors.grey.shade600,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CustomPaint(size: const Size(18, 1), painter: _Tratteggio(Colors.grey.shade500)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Obiettivo $obiettivo a settimana · raggiunto $raggiunte volte su $settimane',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---- Serie per muscolo ----

  Widget _seriePerMuscolo() {
    final gruppi = _gruppi.where((g) => (_settimana[g] ?? 0) > 0 || (_settimanaPrima[g] ?? 0) > 0).toList();
    return _card(
      titolo: 'Serie per muscolo',
      sottotitolo: 'Ultimi 7 giorni · zona utile per crescere: 10–20 serie a settimana',
      figlio: gruppi.isEmpty
          ? Text(
              'Allenati questa settimana e qui vedrai quanto lavora ogni muscolo.',
              style: TextStyle(color: Colors.grey.shade500),
            )
          : Column(children: [for (final g in gruppi) _rigaMuscolo(g)]),
    );
  }

  Widget _rigaMuscolo(String gruppo) {
    final n = _settimana[gruppo] ?? 0;
    final prima = _settimanaPrima[gruppo] ?? 0;
    final scuro = Theme.of(context).brightness == Brightness.dark;
    final fondo = (scuro ? Colors.white : Colors.black).withValues(alpha: 0.07);
    final colore = n >= 10 && n <= 20
        ? AppColors.accento
        : (n > 20 ? Colors.orange.shade400 : AppColors.accento.withValues(alpha: 0.45));
    final differenza = n - prima;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text(gruppo, style: const TextStyle(fontWeight: FontWeight.w700))),
              if (differenza != 0)
                Text(
                  '${differenza > 0 ? '+' : ''}$differenza vs sett. scorsa',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              const SizedBox(width: 10),
              Text('$n', style: GoogleFonts.oswald(fontSize: 18, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          LayoutBuilder(builder: (context, vincoli) {
            final larghezza = vincoli.maxWidth;
            const scala = 25.0; // la barra piena vale 25 serie
            return Stack(
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(2)),
                ),
                // zona 10-20 serie
                Positioned(
                  left: larghezza * 10 / scala,
                  width: larghezza * 10 / scala,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.accento.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  height: 8,
                  width: larghezza * (n / scala).clamp(0.0, 1.0),
                  decoration: BoxDecoration(color: colore, borderRadius: BorderRadius.circular(2)),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  // ---- Massimali ----

  Widget _massimaliCard() {
    return _card(
      titolo: 'Forza per esercizio',
      sottotitolo: 'La tua miglior serie degli ultimi 30 giorni. La percentuale confronta la forza con i 2 mesi prima.',
      figlio: _massimali.isEmpty
          ? Text('Registra qualche serie con carico e qui vedrai la tua forza crescere.',
              style: TextStyle(color: Colors.grey.shade500))
          : Column(
              children: [
                for (final m in _massimali)
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => StoricoEsercizioScreen(nome: m.nome)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              m.nome,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          if (m.variazione != null && m.variazione!.abs() >= 1)
                            Container(
                              margin: const EdgeInsets.only(right: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: (m.variazione! > 0 ? AppColors.accento : Colors.orange.shade400)
                                    .withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${m.variazione! > 0 ? '+' : '−'}${m.variazione!.abs().toStringAsFixed(0)}%',
                                style: TextStyle(
                                  color: m.variazione! > 0 ? AppColors.accento : Colors.orange.shade400,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          Text(
                            '${formatKg(m.carico)} kg × ${m.rep}',
                            style: GoogleFonts.oswald(fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                          Icon(Icons.chevron_right, color: Colors.grey.shade500, size: 20),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  // ---- Record ----

  Widget _recordCard() {
    return _card(
      titolo: 'Record recenti',
      figlio: _record.isEmpty
          ? Text('Il primo record arriva presto: supera il tuo carico massimo su un esercizio.',
              style: TextStyle(color: Colors.grey.shade500))
          : Column(
              children: [
                for (final r in _record)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        const Text('🏆', style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.nome, style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text(_data(r.data), style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                            ],
                          ),
                        ),
                        Text(
                          '${formatKg(r.carico)} kg × ${r.rep}',
                          style: TextStyle(color: AppColors.accento, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Future<void> _apriStorico() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Storico completo')),
          body: const StoricoScreen(),
        ),
      ),
    );
    _carica();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _carica,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'PROGRESSI',
                  style: GoogleFonts.oswald(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: 1),
                ),
              ),
              TextButton.icon(
                onPressed: _apriStorico,
                icon: const Icon(Icons.history, size: 20),
                label: const Text('Storico'),
              ),
            ],
          ),
          Text('Stai migliorando? Ecco i numeri.', style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 18),
          _muscoli(),
          _costanza(),
          _seriePerMuscolo(),
          _massimaliCard(),
          _recordCard(),
          OutlinedButton.icon(
            onPressed: _apriStorico,
            icon: const Icon(Icons.list_alt),
            label: const Text('Storico completo, giorno per giorno'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(raggioPannello)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Linea orizzontale tratteggiata (obiettivo settimanale).
class _Tratteggio extends CustomPainter {
  final Color colore;
  _Tratteggio(this.colore);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = colore
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 7) {
      canvas.drawLine(Offset(x, 0), Offset((x + 4).clamp(0, size.width), 0), p);
    }
  }

  @override
  bool shouldRepaint(_Tratteggio old) => old.colore != colore;
}
