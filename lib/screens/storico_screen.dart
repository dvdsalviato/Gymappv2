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
            const SizedBox(height: 20),
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
                                                        Text(
                                                          _testoSerie(v),
                                                          style: const TextStyle(fontWeight: FontWeight.w600),
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
