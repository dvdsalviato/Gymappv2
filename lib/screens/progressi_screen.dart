import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/progressione.dart';
import '../db/database_helper.dart';
import '../theme/app_theme.dart';
import 'storico_esercizio_screen.dart';
import 'storico_screen.dart';

/// Massimale stimato (formula di Epley): quanto potresti sollevare per una
/// ripetizione, ricavato da carico e ripetizioni fatte.
double massimaleStimato(double carico, int rep) => rep <= 1 ? carico : carico * (1 + rep / 30);

class _Massimale {
  final String nome;
  final double attuale;
  final double? prima;
  const _Massimale(this.nome, this.attuale, this.prima);

  double? get variazione => (prima == null || prima! <= 0) ? null : (attuale - prima!) / prima! * 100;
}

class _Record {
  final String nome;
  final double carico;
  final int rep;
  final DateTime data;
  const _Record(this.nome, this.carico, this.rep, this.data);
}

/// Progressi: risponde a "sto migliorando?". Costanza, serie per muscolo
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

    final adesso = DateTime.now();
    final limite30 = adesso.subtract(const Duration(days: 30));
    final limite90 = adesso.subtract(const Duration(days: 90));
    final attuale = <String, double>{};
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
        if (stima > (attuale[nome] ?? 0)) attuale[nome] = stima;
      } else if (data.isAfter(limite90)) {
        if (stima > (precedente[nome] ?? 0)) precedente[nome] = stima;
      }
      // Record: carico mai sollevato prima su quell'esercizio.
      final massimo = massimoCarico[nome];
      if (massimo != null && carico > massimo) record.add(_Record(nome, carico, rep, data));
      if (massimo == null || carico > massimo) massimoCarico[nome] = carico;
    }

    final massimali = [
      for (final e in attuale.entries) _Massimale(e.key, e.value, precedente[e.key]),
    ]..sort((a, b) => b.attuale.compareTo(a.attuale));

    if (!mounted) return;
    setState(() {
      _presenze = presenze;
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
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: coloreSuperficie(context), borderRadius: BorderRadius.circular(28)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  titolo.toUpperCase(),
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
              if (azione != null) azione,
            ],
          ),
          if (sottotitolo != null) ...[
            const SizedBox(height: 2),
            Text(sottotitolo, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ],
          const SizedBox(height: 12),
          figlio,
        ],
      ),
    );
  }

  // ---- Costanza ----

  Widget _costanza() {
    final scuro = Theme.of(context).brightness == Brightness.dark;
    final vuoto = (scuro ? Colors.white : Colors.black).withValues(alpha: 0.07);
    final oggi = _giorno(DateTime.now());
    final inizio = _lunedi(oggi).subtract(const Duration(days: 7 * 11));
    final fila = _settimaneDiFila;
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
          const SizedBox(height: 16),
          // Ultime 12 settimane: una colonna per settimana, un quadratino per giorno.
          LayoutBuilder(builder: (context, vincoli) {
            const colonne = 12;
            const spazio = 4.0;
            final lato = ((vincoli.maxWidth - spazio * (colonne - 1)) / colonne).clamp(8.0, 22.0);
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var c = 0; c < colonne; c++)
                  Column(
                    children: [
                      for (var r = 0; r < 7; r++)
                        Builder(builder: (context) {
                          final g = DateTime(inizio.year, inizio.month, inizio.day + c * 7 + r);
                          final futuro = g.isAfter(oggi);
                          final fatto = _presenze.contains(g);
                          return Container(
                            width: lato,
                            height: lato,
                            margin: const EdgeInsets.only(bottom: spazio),
                            decoration: BoxDecoration(
                              color: futuro ? Colors.transparent : (fatto ? AppColors.accento : vuoto),
                              borderRadius: BorderRadius.circular(lato * 0.3),
                              border: g == oggi ? Border.all(color: AppColors.accento, width: 1.5) : null,
                            ),
                          );
                        }),
                    ],
                  ),
              ],
            );
          }),
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
                  height: 10,
                  decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(5)),
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
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  height: 10,
                  width: larghezza * (n / scala).clamp(0.0, 1.0),
                  decoration: BoxDecoration(color: colore, borderRadius: BorderRadius.circular(5)),
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
      titolo: 'Massimali stimati',
      sottotitolo: 'Quanto potresti sollevare per 1 ripetizione · ultimi 30 giorni',
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
                            '${formatKg((m.attuale * 2).round() / 2)} kg',
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
              shape: const StadiumBorder(),
            ),
          ),
        ],
      ),
    );
  }
}
