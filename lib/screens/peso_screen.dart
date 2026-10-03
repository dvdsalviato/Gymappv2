import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../db/database_helper.dart';
import '../theme/app_theme.dart';

/// Monitoraggio del peso corporeo: valore attuale, grafico dell'andamento
/// e storico delle registrazioni. Si usa dentro la schermata principale.
class PesoScreen extends StatefulWidget {
  const PesoScreen({super.key});

  @override
  State<PesoScreen> createState() => _PesoScreenState();
}

class _PesoScreenState extends State<PesoScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _pesi = [];
  int _periodo = 30; // giorni; 0 = tutto

  @override
  void initState() {
    super.initState();
    _carica();
  }

  Future<void> _carica() async {
    final pesi = await DatabaseHelper.instance.getPesi();
    if (!mounted) return;
    setState(() {
      _pesi = pesi;
      _loading = false;
    });
  }

  double _kg(Map<String, dynamic> m) => (m['peso_kg'] as num).toDouble();

  DateTime _data(Map<String, dynamic> m) => DateTime.tryParse(m['data'] as String) ?? DateTime.now();

  String _fmt(double v) => v.toStringAsFixed(1).replaceAll('.', ',');

  String _dataLunga(DateTime d) => '${d.day}/${d.month}/${d.year}';

  List<Map<String, dynamic>> get _filtrati {
    if (_periodo == 0) return _pesi;
    final da = DateTime.now().subtract(Duration(days: _periodo));
    return _pesi.where((m) => _data(m).isAfter(da)).toList();
  }

  Future<void> _registra() async {
    final profilo = await DatabaseHelper.instance.getProfilo();
    final double? ultimo = _pesi.isNotEmpty ? _kg(_pesi.last) : (profilo?['peso_kg'] as num?)?.toDouble();
    final controller = TextEditingController(text: ultimo == null ? '' : _fmt(ultimo));
    controller.selection = TextSelection(baseOffset: 0, extentOffset: controller.text.length);
    if (!mounted) return;
    final valore = await showDialog<double>(
      context: context,
      builder: (ctx) {
        void conferma() {
          final v = double.tryParse(controller.text.trim().replaceAll(',', '.'));
          if (v != null && v > 20 && v < 400) Navigator.pop(ctx, v);
        }

        return AlertDialog(
          title: const Text('Registra il peso'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(suffixText: 'kg'),
            onSubmitted: (_) => conferma(),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
            FilledButton(
              onPressed: conferma,
              style: FilledButton.styleFrom(minimumSize: const Size(90, 44)),
              child: const Text('Salva'),
            ),
          ],
        );
      },
    );
    if (valore == null) return;
    await DatabaseHelper.instance.insertPeso(valore, DateTime.now());
    final p = await DatabaseHelper.instance.getProfilo() ?? {};
    await DatabaseHelper.instance.salvaProfilo({...p, 'peso_kg': valore});
    await _carica();
  }

  Future<void> _elimina(Map<String, dynamic> m) async {
    final id = m['id'] as int?;
    if (id == null) return;
    final conferma = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminare questa registrazione?'),
        content: Text('${_fmt(_kg(m))} kg del ${_dataLunga(_data(m))}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(minimumSize: const Size(90, 44)),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (conferma != true) return;
    await DatabaseHelper.instance.deletePeso(id);
    await _carica();
  }

  Widget _cardPesoAttuale(List<Map<String, dynamic>> dati) {
    final ultimo = _pesi.isEmpty ? null : _kg(_pesi.last);
    double? delta;
    if (dati.length >= 2) delta = _kg(dati.last) - _kg(dati.first);
    final periodoTesto = _periodo == 0 ? 'in totale' : 'negli ultimi $_periodo giorni';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: coloreSuperficie(context),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PESO ATTUALE',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                ultimo == null ? '--' : _fmt(ultimo),
                style: GoogleFonts.oswald(fontSize: 58, fontWeight: FontWeight.w700, height: 1.0),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'kg',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 20, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (delta != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  delta == 0 ? Icons.trending_flat : (delta < 0 ? Icons.trending_down : Icons.trending_up),
                  color: AppColors.accento,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '${delta > 0 ? '+' : ''}${_fmt(delta)} kg $periodoTesto',
                    style: const TextStyle(color: AppColors.accento, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _grafico(List<Map<String, dynamic>> dati) {
    if (dati.length < 2) {
      return Container(
        height: 150,
        alignment: Alignment.center,
        child: Text(
          'Registra almeno due pesi per vedere il grafico',
          style: TextStyle(color: Colors.grey.shade500),
          textAlign: TextAlign.center,
        ),
      );
    }
    final spots = <FlSpot>[
      for (var i = 0; i < dati.length; i++) FlSpot(i.toDouble(), _kg(dati[i])),
    ];
    double minV = _kg(dati.first);
    double maxV = minV;
    for (final m in dati) {
      final v = _kg(m);
      if (v < minV) minV = v;
      if (v > maxV) maxV = v;
    }
    final minY = (minV - 1).floorToDouble();
    final maxY = (maxV + 1).ceilToDouble();
    double intervallo = ((maxY - minY) / 4).ceilToDouble();
    if (intervallo < 1) intervallo = 1;

    return SizedBox(
      height: 210,
      child: LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: intervallo,
            getDrawingHorizontalLine: (v) => FlLine(color: Colors.white.withOpacity(0.07), strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                interval: intervallo,
                getTitlesWidget: (value, meta) => Text(
                  value.toStringAsFixed(0),
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                ),
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppColors.accento,
              barWidth: 3,
              dotData: FlDotData(show: dati.length <= 31),
              belowBarData: BarAreaData(show: true, color: AppColors.accento.withOpacity(0.12)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _riga(int indice, List<Map<String, dynamic>> ordine) {
    // ordine: dal più recente al più vecchio
    final m = ordine[indice];
    final precedente = indice + 1 < ordine.length ? ordine[indice + 1] : null;
    final delta = precedente == null ? null : _kg(m) - _kg(precedente);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.only(left: 18, right: 6, top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: coloreSuperficie(context),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${_fmt(_kg(m))} kg', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                Text(_dataLunga(_data(m)), style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              ],
            ),
          ),
          if (delta != null)
            Text(
              '${delta > 0 ? '+' : ''}${_fmt(delta)}',
              style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w600),
            ),
          IconButton(
            onPressed: () => _elimina(m),
            icon: Icon(Icons.delete_outline, color: Colors.grey.shade600),
            tooltip: 'Elimina',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final dati = _filtrati;
    final ordine = _pesi.reversed.take(15).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PESO', style: GoogleFonts.oswald(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: 1)),
          const SizedBox(height: 14),
          _cardPesoAttuale(dati),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 30, label: Text('30 giorni')),
                ButtonSegment(value: 90, label: Text('90 giorni')),
                ButtonSegment(value: 0, label: Text('Tutto')),
              ],
              selected: {_periodo},
              onSelectionChanged: (s) => setState(() => _periodo = s.first),
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: AppColors.accento,
                selectedForegroundColor: Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(8, 20, 20, 14),
            decoration: BoxDecoration(
              color: coloreSuperficie(context),
              borderRadius: BorderRadius.circular(28),
            ),
            child: _grafico(dati),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _registra,
            icon: const Icon(Icons.add),
            label: const Text('Registra peso'),
          ),
          if (ordine.isNotEmpty) ...[
            const SizedBox(height: 26),
            Text(
              'REGISTRAZIONI',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w700,
                fontSize: 12,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < ordine.length; i++) _riga(i, ordine),
          ],
        ],
      ),
    );
  }
}
