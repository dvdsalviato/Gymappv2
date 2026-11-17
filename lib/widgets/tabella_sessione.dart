import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/progressione.dart';
import '../data/tempo.dart';
import '../db/database_helper.dart';
import '../models/esercizio.dart';
import '../theme/app_theme.dart';

/// Tabella delle serie fatte nell'allenamento in corso: si vedono tutte
/// insieme e si correggono o si eliminano al volo, senza uscire.
/// Restituisce true se qualcosa è cambiato.
Future<bool> mostraTabellaSessione(
  BuildContext context, {
  required DateTime inizio,
  required List<Esercizio> esercizi,
}) async {
  final cambiato = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _TabellaSessione(inizio: inizio, esercizi: esercizi),
  );
  return cambiato == true;
}

class _TabellaSessione extends StatefulWidget {
  final DateTime inizio;
  final List<Esercizio> esercizi;
  const _TabellaSessione({required this.inizio, required this.esercizi});

  @override
  State<_TabellaSessione> createState() => _TabellaSessioneState();
}

class _TabellaSessioneState extends State<_TabellaSessione> {
  List<Map<String, dynamic>> _serie = [];
  bool _caricato = false;
  bool _cambiato = false;

  @override
  void initState() {
    super.initState();
    _carica();
  }

  Future<void> _carica() async {
    final righe = await DatabaseHelper.instance.getSerieDaData(widget.inizio);
    if (!mounted) return;
    setState(() {
      _serie = righe;
      _caricato = true;
    });
  }

  Future<void> _modifica(Map<String, dynamic> r) async {
    final aTempo = (r['a_tempo'] as int?) == 1;
    final kgCtrl = TextEditingController(text: formatKg((r['carico'] as num).toDouble()));
    final repCtrl = TextEditingController(text: '${r['rep']}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${r['nome']} · serie ${r['serie_numero']}'),
        content: Row(
          children: [
            if (!aTempo) ...[
              Expanded(
                child: TextField(
                  controller: kgCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                  decoration: const InputDecoration(labelText: 'kg'),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: TextField(
                controller: repCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(labelText: aTempo ? 'secondi' : 'ripetizioni'),
              ),
            ),
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
    final carico = aTempo ? (r['carico'] as num).toDouble() : double.tryParse(kgCtrl.text.replaceAll(',', '.'));
    final rep = int.tryParse(repCtrl.text);
    if (carico == null || rep == null || rep <= 0 || carico < 0) return;
    await DatabaseHelper.instance.updateStorico(r['id'] as int, carico: carico, rep: rep);
    _cambiato = true;
    await _carica();
  }

  Future<void> _elimina(Map<String, dynamic> r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminare questa serie?'),
        content: Text('${r['nome']} · serie ${r['serie_numero']}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
              minimumSize: const Size(100, 44),
            ),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await DatabaseHelper.instance.deleteStorico(r['id'] as int);
    _cambiato = true;
    await _carica();
  }

  String _valore(Map<String, dynamic> r) {
    final rep = (r['rep'] as num).toInt();
    if ((r['a_tempo'] as int?) == 1) return formattaDurata(rep);
    return '${formatKg((r['carico'] as num).toDouble())} kg × $rep';
  }

  @override
  Widget build(BuildContext context) {
    // Esercizi nell'ordine della scheda (una volta sola anche se in superset).
    final visti = <int>{};
    final ordine = <Esercizio>[for (final e in widget.esercizi) if (e.id != null && visti.add(e.id!)) e];
    final perEsercizio = <int, List<Map<String, dynamic>>>{};
    for (final r in _serie) {
      perEsercizio.putIfAbsent(r['esercizio_id'] as int, () => []).add(r);
    }
    final fatte = _serie.length;
    final previste = ordine.fold<int>(0, (a, e) => a + e.serieTotali);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _cambiato);
      },
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text('Serie della sessione', style: GoogleFonts.oswald(fontSize: 24, fontWeight: FontWeight.w700)),
                ),
                Text(
                  '$fatte / $previste',
                  style: GoogleFonts.oswald(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.accento),
                ),
              ],
            ),
            Text(
              'Tocca una serie per correggerla, tieni premuto per eliminarla.',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
            const SizedBox(height: 14),
            if (!_caricato)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              for (final e in ordine) _blocco(e, perEsercizio[e.id] ?? const []),
          ],
        ),
      ),
    );
  }

  Widget _blocco(Esercizio e, List<Map<String, dynamic>> righe) {
    final completo = righe.length >= e.serieTotali;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(color: coloreCard(context), borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(e.nome, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
              if (completo) Icon(Icons.check_circle, color: AppColors.accento, size: 18),
              const SizedBox(width: 6),
              Text(
                '${righe.length}/${e.serieTotali}',
                style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (righe.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('Ancora da fare', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            )
          else
            for (final r in righe)
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _modifica(r),
                onLongPress: () => _elimina(r),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 34,
                        child: Text(
                          'S${r['serie_numero']}',
                          style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w700),
                        ),
                      ),
                      Expanded(
                        child: Text(_valore(r), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      ),
                      Icon(Icons.edit_outlined, size: 16, color: Colors.grey.shade500),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
