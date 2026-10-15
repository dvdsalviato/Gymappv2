import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../data/progressione.dart' show formatKg;
import '../data/tempo.dart';
import '../db/database_helper.dart';
import '../theme/app_theme.dart';

// ---- Funzioni condivise con la schermata Storico ----

bool serieATempo(Map<String, dynamic> m) => (m['a_tempo'] as int?) == 1;

/// Valore da confrontare per una serie: kg, oppure secondi se l'esercizio è a tempo.
double valoreSerie(Map<String, dynamic> m) {
  final v = serieATempo(m) ? m['rep'] : m['carico'];
  return (v as num).toDouble();
}

String testoSerie(Map<String, dynamic> m) {
  if (serieATempo(m)) return formattaDurata((m['rep'] as num).toInt());
  return '${formatKg((m['carico'] as num).toDouble())} kg × ${m['rep']}';
}

/// "2026-04-12T18:30:00" diventa "2026-04-12".
String giornoDi(Map<String, dynamic> m) => (m['data'] as String).substring(0, 10);

/// "2026-04-12" diventa "12/04".
String dataBreve(String giorno) {
  final p = giorno.split('-');
  return p.length == 3 ? '${p[2]}/${p[1]}' : giorno;
}

/// "2026-04-12" diventa "12/04/2026".
String dataLunga(String giorno) {
  final p = giorno.split('-');
  return p.length == 3 ? '${p[2]}/${p[1]}/${p[0]}' : giorno;
}

class PuntoGiorno {
  final String giorno;
  final double valore;
  final String dettaglio;
  const PuntoGiorno(this.giorno, this.valore, this.dettaglio);
}

/// Un punto per ogni giorno di allenamento, dal più vecchio al più recente.
/// [metrica]: 0 = carico massimo (o durata più lunga), 1 = 1RM stimato (o
/// durata totale), 2 = volume (solo esercizi con carico).
List<PuntoGiorno> puntiPerGiorno(List<Map<String, dynamic>> serie, int metrica) {
  final perGiorno = <String, List<Map<String, dynamic>>>{};
  for (final s in serie) {
    perGiorno.putIfAbsent(giornoDi(s), () => []).add(s);
  }
  final giorni = perGiorno.keys.toList()..sort();
  final punti = <PuntoGiorno>[];
  for (final g in giorni) {
    final righe = perGiorno[g]!;
    var migliore = righe.first;
    for (final r in righe) {
      if (valoreSerie(r) > valoreSerie(migliore)) migliore = r;
    }
    var valore = valoreSerie(migliore);
    if (serieATempo(righe.first)) {
      if (metrica == 1) {
        valore = 0;
        for (final r in righe) {
          valore += (r['rep'] as num).toDouble();
        }
      }
    } else if (metrica == 1) {
      // Stima del massimale con la formula di Epley.
      valore = 0;
      for (final r in righe) {
        final stima = (r['carico'] as num).toDouble() * (1 + (r['rep'] as num).toDouble() / 30);
        if (stima > valore) valore = stima;
      }
    } else if (metrica == 2) {
      valore = 0;
      for (final r in righe) {
        valore += (r['carico'] as num).toDouble() * (r['rep'] as num).toDouble();
      }
    }
    punti.add(PuntoGiorno(g, valore, testoSerie(migliore)));
  }
  return punti;
}

// ---- Pagina di dettaglio di un esercizio ----

class StoricoEsercizioScreen extends StatefulWidget {
  final String nome;
  const StoricoEsercizioScreen({super.key, required this.nome});

  @override
  State<StoricoEsercizioScreen> createState() => _StoricoEsercizioScreenState();
}

class _StoricoEsercizioScreenState extends State<StoricoEsercizioScreen> {
  List<Map<String, dynamic>> _serie = [];
  bool _loading = true;
  int _metrica = 0;

  @override
  void initState() {
    super.initState();
    _carica();
  }

  Future<void> _carica() async {
    final serie = await DatabaseHelper.instance.getStoricoEsercizio(widget.nome);
    if (!mounted) return;
    setState(() {
      _serie = serie;
      _loading = false;
    });
  }

  bool get _aTempo => _serie.isNotEmpty && serieATempo(_serie.first);

  List<String> get _nomiMetriche => _aTempo ? ['Più lunga', 'Totale'] : ['Carico max', '1RM stimato', 'Volume'];

  String _formattaValore(double v) {
    if (_aTempo) return formattaDurata(v.round());
    return '${formatKg(double.parse(v.toStringAsFixed(1)))} kg';
  }

  Future<void> _modifica(Map<String, dynamic> s) async {
    final aTempo = serieATempo(s);
    final rep = (s['rep'] as num).toInt();
    final caricoCtrl = TextEditingController(text: formatKg((s['carico'] as num).toDouble()));
    final repCtrl = TextEditingController(text: '$rep');
    final minCtrl = TextEditingController(text: '${rep ~/ 60}');
    final secCtrl = TextEditingController(text: '${rep % 60}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Modifica serie · ${dataBreve(giornoDi(s))}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (aTempo)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: minCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Minuti'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: secCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Secondi'),
                    ),
                  ),
                ],
              )
            else ...[
              TextField(
                controller: caricoCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Carico (kg)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: repCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Ripetizioni'),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
            child: const Text('Salva'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    var nuovoCarico = (s['carico'] as num).toDouble();
    var nuoveRep = rep;
    if (aTempo) {
      final m = int.tryParse(minCtrl.text.trim()) ?? 0;
      final sec = int.tryParse(secCtrl.text.trim()) ?? 0;
      nuoveRep = m * 60 + sec;
    } else {
      nuovoCarico = double.tryParse(caricoCtrl.text.trim().replaceAll(',', '.')) ?? -1;
      nuoveRep = int.tryParse(repCtrl.text.trim()) ?? -1;
    }
    if (nuoveRep <= 0 || nuovoCarico < 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Valori non validi, serie non modificata')));
      return;
    }
    await DatabaseHelper.instance.updateStorico(s['id'] as int, carico: nuovoCarico, rep: nuoveRep);
    await _carica();
  }

  Future<void> _elimina(Map<String, dynamic> s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminare questa serie?'),
        content: Text('${testoSerie(s)}\n${dataLunga(giornoDi(s))}'),
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
    await DatabaseHelper.instance.deleteStorico(s['id'] as int);
    await _carica();
  }

  Widget _statistica(String etichetta, String valore) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: coloreCard(context), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            etichetta.toUpperCase(),
            style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1),
          ),
          const SizedBox(height: 4),
          Text(valore, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _riepilogo() {
    var record = _serie.first;
    for (final s in _serie) {
      if (valoreSerie(s) > valoreSerie(record)) record = s;
    }
    final giorni = _serie.map(giornoDi).toSet().length;
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _statistica('Record', testoSerie(record))),
            const SizedBox(width: 10),
            Expanded(child: _statistica('Ultima volta', dataLunga(giornoDi(_serie.first)))),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _statistica('Allenamenti', '$giorni')),
            const SizedBox(width: 10),
            Expanded(child: _statistica('Serie totali', '${_serie.length}')),
          ],
        ),
      ],
    );
  }

  Widget _grafico() {
    final punti = puntiPerGiorno(_serie, _metrica);
    if (punti.length < 2) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'Servono almeno due allenamenti per vedere l\'andamento',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    var minV = punti.first.valore;
    var maxV = minV;
    for (final p in punti) {
      if (p.valore < minV) minV = p.valore;
      if (p.valore > maxV) maxV = p.valore;
    }
    final margine = (maxV - minV) == 0 ? (maxV == 0 ? 1.0 : maxV * 0.2) : (maxV - minV) * 0.2;
    final minY = (minV - margine) < 0 ? 0.0 : (minV - margine);
    final maxY = maxV + margine;
    final ultimo = punti.length - 1;
    final spots = [for (var i = 0; i < punti.length; i++) FlSpot(i.toDouble(), punti[i].valore)];

    return SizedBox(
      height: 230,
      child: LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (value, meta) {
                  if (value == meta.min || value == meta.max) return const SizedBox.shrink();
                  return Text(
                    _aTempo ? formattaDurata(value.round()) : formatKg(double.parse(value.toStringAsFixed(1))),
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final i = value.round();
                  if ((value - i).abs() > 0.001 || i < 0 || i > ultimo) return const SizedBox.shrink();
                  if (i == 0 || i == ultimo || i == ultimo ~/ 2) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        dataBreve(punti[i].giorno),
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
          // Toccando un punto compare la data e il valore di quel giorno.
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touched) => [
                for (final t in touched)
                  LineTooltipItem(
                    '${dataLunga(punti[t.spotIndex].giorno)}\n${_formattaValore(punti[t.spotIndex].valore)}'
                    '${_metrica == 0 ? '\n${punti[t.spotIndex].dettaglio}' : ''}',
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  ),
              ],
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppColors.accento,
              barWidth: 3,
              dotData: FlDotData(show: punti.length <= 31),
              belowBarData: BarAreaData(show: true, color: AppColors.accento.withOpacity(0.12)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardGiorno(String giorno, List<Map<String, dynamic>> righe) {
    final ordinate = [...righe]..sort((a, b) {
        final c = (a['serie_numero'] as int).compareTo(b['serie_numero'] as int);
        return c != 0 ? c : (a['id'] as int).compareTo(b['id'] as int);
      });
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 12, 6, 8),
      decoration: BoxDecoration(color: coloreCard(context), borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dataLunga(giorno),
            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accento),
          ),
          const SizedBox(height: 4),
          for (final s in ordinate)
            InkWell(
              onTap: () => _modifica(s),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 64,
                      child: Text('Serie ${s['serie_numero']}', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                    ),
                    Expanded(child: Text(testoSerie(s), style: const TextStyle(fontWeight: FontWeight.w600))),
                    IconButton(
                      onPressed: () => _modifica(s),
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      tooltip: 'Modifica',
                      visualDensity: VisualDensity.compact,
                    ),
                    IconButton(
                      onPressed: () => _elimina(s),
                      icon: const Icon(Icons.delete_outline, size: 20),
                      tooltip: 'Elimina',
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget corpo;
    if (_loading) {
      corpo = const Center(child: CircularProgressIndicator());
    } else if (_serie.isEmpty) {
      corpo = Center(
        child: Text('Nessuna registrazione per questo esercizio.', style: TextStyle(color: Colors.grey.shade600)),
      );
    } else {
      final perGiorno = <String, List<Map<String, dynamic>>>{};
      for (final s in _serie) {
        perGiorno.putIfAbsent(giornoDi(s), () => []).add(s);
      }
      final giorni = perGiorno.keys.toList()..sort((a, b) => b.compareTo(a));
      final nomi = _nomiMetriche;
      if (_metrica >= nomi.length) _metrica = 0;
      corpo = ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _riepilogo(),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<int>(
              segments: [for (var i = 0; i < nomi.length; i++) ButtonSegment(value: i, label: Text(nomi[i]))],
              selected: {_metrica},
              onSelectionChanged: (v) => setState(() => _metrica = v.first),
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: AppColors.accento,
                selectedForegroundColor: Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _grafico(),
          const SizedBox(height: 20),
          Text(
            'TUTTE LE REGISTRAZIONI (tocca una serie per correggerla)',
            style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 1.2),
          ),
          const SizedBox(height: 10),
          for (final g in giorni) _cardGiorno(g, perGiorno[g]!),
        ],
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(widget.nome)),
      body: corpo,
    );
  }
}
