import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../data/classificatore.dart';
import '../data/progressione.dart' show formatKg;
import '../db/database_helper.dart';
import '../theme/app_theme.dart';
import 'storico_esercizio_screen.dart';

const List<String> _ordineGruppi = [
  'Petto',
  'Schiena',
  'Gambe',
  'Spalle',
  'Bicipiti',
  'Tricipiti',
  'Core',
  'Cardio',
  'Altro',
];

/// Un esercizio con tutte le sue serie (le più recenti prima).
class _Esercizio {
  final String nome;
  final bool aTempo;
  final List<Map<String, dynamic>> serie;
  const _Esercizio(this.nome, this.aTempo, this.serie);

  Map<String, dynamic> get record => serie.reduce((a, b) => valoreSerie(a) >= valoreSerie(b) ? a : b);
  String get ultimaVolta => dataBreve(giornoDi(serie.first));
}

class StoricoScreen extends StatefulWidget {
  const StoricoScreen({super.key});

  @override
  State<StoricoScreen> createState() => _StoricoScreenState();
}

class _StoricoScreenState extends State<StoricoScreen> {
  bool _loading = true;
  bool _vuoto = true;
  int _vista = 0; // 0 = per scheda, 1 = per gruppo, 2 = per giorno
  Map<String, List<_Esercizio>> _perScheda = {};
  Map<String, List<_Esercizio>> _perGruppo = {};
  Map<String, List<Map<String, dynamic>>> _perGiorno = {};
  List<String> _giorni = [];
  Map<String, int> _serieSettimana = {};

  @override
  void initState() {
    super.initState();
    _carica();
  }

  Future<void> _carica({bool silenzioso = false}) async {
    if (!silenzioso) setState(() => _loading = true);
    final voci = await DatabaseHelper.instance.getStoricoCompleto();

    final categoriePerNome = <String, String>{};
    String categoriaDi(String nome, String? categoria) {
      if (categoria != null && categoria != 'Altro') return categoria;
      return categoriePerNome.putIfAbsent(nome, () => classificaEsercizio(nome) ?? 'Altro');
    }

    final limiteSettimana = DateTime.now().subtract(const Duration(days: 7));
    final settimana = <String, int>{};
    final scheda = <String, Map<String, List<Map<String, dynamic>>>>{};
    final gruppo = <String, Map<String, List<Map<String, dynamic>>>>{};
    final giorno = <String, List<Map<String, dynamic>>>{};
    for (final v in voci) {
      final nomeScheda = (v['scheda_nome'] as String?) ?? 'Scheda';
      final nome = v['esercizio_nome'] as String;
      scheda.putIfAbsent(nomeScheda, () => {}).putIfAbsent(nome, () => []).add(v);
      // Per gruppo l'esercizio si unisce anche se è in schede diverse.
      gruppo
          .putIfAbsent(categoriaDi(nome, v['categoria'] as String?), () => {})
          .putIfAbsent(nome.trim().toLowerCase(), () => [])
          .add(v);
      giorno.putIfAbsent(giornoDi(v), () => []).add(v);
      final quando = DateTime.tryParse(v['data'] as String);
      if (quando != null && quando.isAfter(limiteSettimana)) {
        final cat = categoriaDi(nome, v['categoria'] as String?);
        settimana[cat] = (settimana[cat] ?? 0) + 1;
      }
    }

    List<_Esercizio> converti(Map<String, List<Map<String, dynamic>>> m) {
      return [
        for (final righe in m.values)
          _Esercizio(righe.first['esercizio_nome'] as String, serieATempo(righe.first), righe),
      ];
    }

    final perScheda = {for (final e in scheda.entries) e.key: converti(e.value)};
    final perGruppo = <String, List<_Esercizio>>{};
    for (final nome in _ordineGruppi) {
      final m = gruppo[nome];
      if (m != null) perGruppo[nome] = converti(m);
    }
    for (final e in gruppo.entries) {
      perGruppo.putIfAbsent(e.key, () => converti(e.value));
    }

    if (!mounted) return;
    setState(() {
      _vuoto = voci.isEmpty;
      _perScheda = perScheda;
      _perGruppo = perGruppo;
      _perGiorno = giorno;
      _serieSettimana = settimana;
      _giorni = giorno.keys.toList()..sort((a, b) => b.compareTo(a));
      _loading = false;
    });
  }

  Future<void> _apriDettaglio(_Esercizio e) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StoricoEsercizioScreen(nome: e.nome)),
    );
    // Al ritorno potresti aver corretto o eliminato delle serie.
    await _carica(silenzioso: true);
  }

  Future<void> _eliminaGiorno(String giorno, int n) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminare questo giorno?'),
        content: Text('Verranno eliminate tutte le $n serie registrate e la presenza nel calendario.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await DatabaseHelper.instance.deleteStoricoGiorno(giorno);
    await _carica(silenzioso: true);
  }

  /// Piccolo grafico senza assi: il carico massimo degli ultimi allenamenti.
  Widget _miniGrafico(_Esercizio e) {
    final punti = puntiPerGiorno(e.serie, 0);
    final ultimi = punti.length > 10 ? punti.sublist(punti.length - 10) : punti;
    if (ultimi.length < 2) return const SizedBox.shrink();
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: [for (var i = 0; i < ultimi.length; i++) FlSpot(i.toDouble(), ultimi[i].valore)],
            isCurved: true,
            color: AppColors.accento,
            barWidth: 2,
            dotData: const FlDotData(show: false),
          ),
        ],
      ),
    );
  }

  Widget _rigaEsercizio(_Esercizio e) {
    return InkWell(
      onTap: () => _apriDettaglio(e),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.nome, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    '🏆 ${testoSerie(e.record)} · ultima volta ${e.ultimaVolta}',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                ],
              ),
            ),
            SizedBox(width: 64, height: 28, child: _miniGrafico(e)),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: Colors.grey.shade500),
          ],
        ),
      ),
    );
  }

  Widget _sezione(String titolo, List<_Esercizio> esercizi, bool aperta) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: coloreCard(context), borderRadius: BorderRadius.circular(20)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey<String>('storico-$_vista-$titolo'),
          initiallyExpanded: aperta,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.only(bottom: 8),
          title: Text(
            titolo,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppColors.accento),
          ),
          subtitle: Text(
            esercizi.length == 1 ? '1 esercizio' : '${esercizi.length} esercizi',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
          children: [for (final e in esercizi) _rigaEsercizio(e)],
        ),
      ),
    );
  }

  /// Quante serie hai fatto negli ultimi 7 giorni per ogni gruppo muscolare.
  Widget _cardVolume() {
    const gruppi = ['Petto', 'Schiena', 'Gambe', 'Spalle', 'Bicipiti', 'Tricipiti', 'Core'];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(color: coloreCard(context), borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('QUESTA SETTIMANA', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.3, fontSize: 12)),
          const SizedBox(height: 2),
          Text('Serie negli ultimi 7 giorni, per gruppo', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          const SizedBox(height: 10),
          for (final g in gruppi) _rigaVolume(g, _serieSettimana[g] ?? 0),
          const SizedBox(height: 6),
          Text(
            'La fascia verde (10-20 serie) è solo indicativa, per chi punta ad aumentare la massa muscolare: non è una regola.',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _rigaVolume(String gruppo, int n) {
    final colore = n == 0
        ? Colors.grey
        : (n < 10 ? Colors.orange.shade400 : (n <= 20 ? Colors.green.shade400 : Colors.amber.shade700));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 74, child: Text(gruppo, style: const TextStyle(fontSize: 13))),
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) {
                const massimo = 30.0;
                final larghezza = c.maxWidth;
                return Stack(
                  children: [
                    Container(
                      height: 10,
                      decoration: BoxDecoration(color: coloreChip(context), borderRadius: BorderRadius.circular(5)),
                    ),
                    Positioned(
                      left: larghezza * 10 / massimo,
                      width: larghezza * 10 / massimo,
                      child: Container(height: 10, color: Colors.green.withOpacity(0.25)),
                    ),
                    Container(
                      height: 10,
                      width: larghezza * (n > massimo ? 1.0 : n / massimo),
                      decoration: BoxDecoration(color: colore, borderRadius: BorderRadius.circular(5)),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(width: 26, child: Text('$n', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w800))),
        ],
      ),
    );
  }

  Widget _vistaRaggruppata(Map<String, List<_Esercizio>> sezioni, {bool conVolume = false}) {
    final voci = sezioni.entries.toList();
    final extra = conVolume ? 1 : 0;
    return RefreshIndicator(
      onRefresh: () => _carica(silenzioso: true),
      child: ListView.builder(
        itemCount: voci.length + extra,
        itemBuilder: (context, i) {
          if (conVolume && i == 0) return _cardVolume();
          final k = i - extra;
          return _sezione(voci[k].key, voci[k].value, k == 0);
        },
      ),
    );
  }

  /// "3 × 10 a 60 kg" se le serie sono uguali, altrimenti "60×10 · 60×8 · 55×8".
  String _riassunto(List<Map<String, dynamic>> serie) {
    if (serie.isEmpty) return '';
    if (serieATempo(serie.first)) return serie.map(testoSerie).join(' · ');
    final primo = serie.first;
    final uguali = serie.every((s) => s['carico'] == primo['carico'] && s['rep'] == primo['rep']);
    if (uguali) {
      return '${serie.length} × ${primo['rep']} a ${formatKg((primo['carico'] as num).toDouble())} kg';
    }
    return serie.map((s) => '${formatKg((s['carico'] as num).toDouble())}×${s['rep']}').join(' · ');
  }

  Widget _cardGiorno(String giorno, List<Map<String, dynamic>> righe) {
    const nomiGiorni = ['lunedì', 'martedì', 'mercoledì', 'giovedì', 'venerdì', 'sabato', 'domenica'];
    final d = DateTime.tryParse(giorno);
    final titolo = d == null ? giorno : '${nomiGiorni[d.weekday - 1]} ${d.day}/${d.month}/${d.year}';
    final ordinate = [...righe]..sort((a, b) => (a['data'] as String).compareTo(b['data'] as String));
    final perEsercizio = <String, List<Map<String, dynamic>>>{};
    for (final v in ordinate) {
      perEsercizio.putIfAbsent(v['esercizio_nome'] as String, () => []).add(v);
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
      decoration: BoxDecoration(color: coloreCard(context), borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  titolo,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.accento),
                ),
              ),
              Text('${righe.length} serie', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
              IconButton(
                onPressed: () => _eliminaGiorno(giorno, righe.length),
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Elimina tutto il giorno',
              ),
            ],
          ),
          for (final e in perEsercizio.entries)
            InkWell(
              onTap: () => _apriDettaglio(_Esercizio(e.key, serieATempo(e.value.first), e.value.reversed.toList())),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 4, right: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text(_riassunto(e.value), style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, size: 20, color: Colors.grey.shade500),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _vistaPerGiorno() {
    return RefreshIndicator(
      onRefresh: () => _carica(silenzioso: true),
      child: ListView.builder(
        itemCount: _giorni.length,
        itemBuilder: (context, i) => _cardGiorno(_giorni[i], _perGiorno[_giorni[i]]!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget corpo;
    if (_loading) {
      corpo = const Center(child: CircularProgressIndicator());
    } else if (_vuoto) {
      corpo = Center(
        child: Text('Nessuna serie registrata ancora.', style: TextStyle(color: Colors.grey.shade600)),
      );
    } else if (_vista == 0) {
      corpo = _vistaRaggruppata(_perScheda);
    } else if (_vista == 1) {
      corpo = _vistaRaggruppata(_perGruppo, conVolume: true);
    } else {
      corpo = _vistaPerGiorno();
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Storico', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              'Tocca un esercizio per vedere l\'andamento e correggere le serie',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('Scheda')),
                  ButtonSegment(value: 1, label: Text('Gruppo')),
                  ButtonSegment(value: 2, label: Text('Giorno')),
                ],
                selected: {_vista},
                onSelectionChanged: (v) => setState(() => _vista = v.first),
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: AppColors.accento,
                  selectedForegroundColor: Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(child: corpo),
          ],
        ),
      ),
    );
  }
}
