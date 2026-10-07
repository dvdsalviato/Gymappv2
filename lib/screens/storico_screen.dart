import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../data/tempo.dart';
import '../db/database_helper.dart';
import '../theme/app_theme.dart';

class StoricoScreen extends StatefulWidget {
  const StoricoScreen({super.key});

  @override
  State<StoricoScreen> createState() => _StoricoScreenState();
}

class _StoricoScreenState extends State<StoricoScreen> {
  List<Map<String, dynamic>> _voci = [];
  bool _loading = true;
  bool _perGiorno = false;

  @override
  void initState() {
    super.initState();
    _carica();
  }

  Future<void> _carica() async {
    setState(() => _loading = true);
    final voci = await DatabaseHelper.instance.getStoricoConNome();
    setState(() {
      _voci = voci;
      _loading = false;
    });
  }

  String _formattaData(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    String due(int n) => n.toString().padLeft(2, '0');
    return '${due(d.day)}/${due(d.month)}/${d.year} ${due(d.hour)}:${due(d.minute)}';
  }

  // scheda -> esercizio -> lista di serie (più recenti prima, come da query)
  Map<String, Map<String, List<Map<String, dynamic>>>> _raggruppa() {
    final risultato = <String, Map<String, List<Map<String, dynamic>>>>{};
    for (final v in _voci) {
      final scheda = (v['scheda_nome'] as String?) ?? 'Scheda';
      final esercizio = v['esercizio_nome'] as String;
      risultato.putIfAbsent(scheda, () => {});
      risultato[scheda]!.putIfAbsent(esercizio, () => []).add(v);
    }
    return risultato;
  }

  bool _eATempo(Map<String, dynamic> m) => (m['a_tempo'] as int?) == 1;

  double _valoreGrafico(Map<String, dynamic> m) {
    final v = _eATempo(m) ? m['rep'] : m['carico'];
    return (v as num).toDouble();
  }

  String _testoSerie(Map<String, dynamic> m) {
    if (_eATempo(m)) return formattaDurata((m['rep'] as num).toInt());
    return '${m['carico']} kg x ${m['rep']}';
  }

  Future<bool> _conferma(String titolo, String testo) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titolo),
        content: Text(testo),
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
    return r == true;
  }

  Future<void> _eliminaSerie(Map<String, dynamic> v) async {
    final ok = await _conferma(
      'Eliminare questa serie?',
      '${v['esercizio_nome']}: ${_testoSerie(v)}\n${_formattaData(v['data'] as String)}',
    );
    if (!ok) return;
    await DatabaseHelper.instance.deleteStorico(v['id'] as int);
    await _carica();
  }

  Future<void> _eliminaGiorno(String giorno, int n) async {
    final ok = await _conferma(
      'Eliminare questo giorno?',
      'Verranno eliminate tutte le $n serie registrate e la presenza nel calendario.',
    );
    if (!ok) return;
    await DatabaseHelper.instance.deleteStoricoGiorno(giorno);
    await _carica();
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
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 14),
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
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final v in e.value)
                        InputChip(
                          label: Text(_testoSerie(v), style: const TextStyle(fontSize: 12)),
                          onDeleted: () => _eliminaSerie(v),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _vistaPerGiorno() {
    final perGiorno = <String, List<Map<String, dynamic>>>{};
    for (final v in _voci) {
      final g = (v['data'] as String).substring(0, 10);
      perGiorno.putIfAbsent(g, () => []).add(v);
    }
    final giorni = perGiorno.keys.toList()..sort((a, b) => b.compareTo(a));
    return RefreshIndicator(
      onRefresh: _carica,
      child: ListView(
        children: [for (final g in giorni) _cardGiorno(g, perGiorno[g]!)],
      ),
    );
  }

  Widget _grafico(List<Map<String, dynamic>> serie) {
    // La lista arriva più-recente-prima: la giriamo per avere l'asse del
    // tempo che scorre da sinistra (vecchio) a destra (recente).
    final cronologico = serie.reversed.toList();
    if (cronologico.length < 2) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Serve più di un allenamento per vedere il grafico',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
        ),
      );
    }
    final spots = [
      for (int i = 0; i < cronologico.length; i++)
        FlSpot(i.toDouble(), _valoreGrafico(cronologico[i])),
    ];
    return SizedBox(
      height: 90,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          minY: 0,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppColors.accento,
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: true, color: Color(0x2239FF14)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gruppi = _raggruppa();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Storico', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('I tuoi allenamenti, per scheda ed esercizio', style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Per scheda')),
                ButtonSegment(value: true, label: Text('Per giorno')),
              ],
              selected: {_perGiorno},
              onSelectionChanged: (v) => setState(() => _perGiorno = v.first),
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: AppColors.accento,
                selectedForegroundColor: Colors.black,
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _voci.isEmpty
                      ? Center(
                          child: Text(
                            'Nessuna serie registrata ancora.',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        )
                      : _perGiorno
                          ? _vistaPerGiorno()
                          : RefreshIndicator(
                          onRefresh: _carica,
                          child: ListView(
                            children: gruppi.entries.map((scheda) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 24),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      scheda.key,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.accento,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    ...scheda.value.entries.map((esercizio) {
                                      final serie = esercizio.value;
                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 14),
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: coloreCard(context),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              esercizio.key,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                            ),
                                            Builder(
                                              builder: (context) {
                                                final record = serie.reduce(
                                                  (a, b) => _valoreGrafico(a) >= _valoreGrafico(b) ? a : b,
                                                );
                                                return Padding(
                                                  padding: const EdgeInsets.only(top: 2, bottom: 4),
                                                  child: Text(
                                                    '🏆 Record: ${_testoSerie(record)}',
                                                    style: const TextStyle(
                                                      color: AppColors.accento,
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                            _grafico(serie),
                                            const SizedBox(height: 8),
                                            ...serie.take(6).map(
                                                  (v) => Padding(
                                                    padding: const EdgeInsets.symmetric(vertical: 3),
                                                    child: Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        Text(
                                                          _formattaData(v['data'] as String),
                                                          style: TextStyle(
                                                            color: Colors.grey.shade600,
                                                            fontSize: 13,
                                                          ),
                                                        ),
                                                        Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Text(
                                                              _testoSerie(v),
                                                              style: const TextStyle(fontWeight: FontWeight.w600),
                                                            ),
                                                            const SizedBox(width: 6),
                                                            InkResponse(
                                                              onTap: () => _eliminaSerie(v),
                                                              child: Icon(Icons.close, size: 18, color: Colors.grey.shade600),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                            if (serie.length > 6)
                                              Padding(
                                                padding: const EdgeInsets.only(top: 4),
                                                child: Text(
                                                  '+ altre ${serie.length - 6} serie',
                                                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                                                ),
                                              ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
