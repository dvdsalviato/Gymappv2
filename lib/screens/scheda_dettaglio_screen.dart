import 'package:flutter/material.dart';
import '../data/tempo.dart';
import '../db/database_helper.dart';
import '../models/esercizio.dart';
import '../models/scheda.dart';
import '../theme/app_theme.dart';
import 'scheda_editor_screen.dart';

/// Dettaglio di una scheda: elenco degli esercizi in sola lettura, con la
/// matita per modificarla e i pulsanti per duplicarla, condividerla,
/// eliminarla o iniziare l'allenamento.
///
/// Chiude restituendo l'azione scelta ('inizia', 'condividi', 'elimina',
/// 'duplicata'): se ne occupa la schermata Schede.
class SchedaDettaglioScreen extends StatefulWidget {
  final Scheda scheda;
  const SchedaDettaglioScreen({super.key, required this.scheda});

  @override
  State<SchedaDettaglioScreen> createState() => _SchedaDettaglioScreenState();
}

class _SchedaDettaglioScreenState extends State<SchedaDettaglioScreen> {
  List<Esercizio> _esercizi = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _carica();
  }

  Future<void> _carica() async {
    final lista = await DatabaseHelper.instance.getEsercizi(widget.scheda.id!);
    if (!mounted) return;
    setState(() {
      _esercizi = lista;
      _loading = false;
    });
  }

  Future<void> _modifica() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SchedaEditorScreen(scheda: widget.scheda)),
    );
    await _carica();
  }

  Future<void> _duplica() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Duplicare la scheda?'),
        content: Text(
          'Verrà creata una copia di "${widget.scheda.nome}" con gli stessi esercizi. Lo storico non viene copiato.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
            child: const Text('Duplica'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await DatabaseHelper.instance.duplicaScheda(widget.scheda.id!);
    if (!mounted) return;
    Navigator.pop(context, 'duplicata');
  }

  String _riposo(int s) => (s >= 120 && s % 60 == 0) ? '${s ~/ 60} min' : '$s s';

  Widget _riga(int indice, Esercizio e) {
    final obiettivo = e.aTempo ? '${e.serieTotali} × ${formattaDurata(e.repTarget)}' : '${e.serieTotali} × ${e.repTarget}';
    final note = e.note?.trim() ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
      decoration: BoxDecoration(color: coloreCard(context), borderRadius: BorderRadius.circular(18)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: coloreChip(context), shape: BoxShape.circle),
            child: Text('${indice + 1}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.nome, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 2),
                Text(e.categoria, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(note, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(obiettivo, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              Text('riposo ${_riposo(e.riposoSecondi)}', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final serieTotali = _esercizi.fold<int>(0, (a, e) => a + e.serieTotali);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.scheda.nome),
        actions: [
          IconButton(tooltip: 'Modifica', icon: const Icon(Icons.edit_outlined), onPressed: _modifica),
          IconButton(tooltip: 'Duplica', icon: const Icon(Icons.content_copy_outlined), onPressed: _duplica),
          PopupMenuButton<String>(
            onSelected: (v) => Navigator.pop(context, v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'condividi', child: Text('Condividi come QR')),
              PopupMenuItem(value: 'elimina', child: Text('Elimina scheda')),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: _esercizi.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text(
                              'Nessun esercizio in questa scheda.\nTocca la matita per aggiungerne.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                '${_esercizi.length} esercizi · $serieTotali serie in totale',
                                style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                              ),
                            ),
                            for (var i = 0; i < _esercizi.length; i++) _riga(i, _esercizi[i]),
                          ],
                        ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                    child: FilledButton.icon(
                      onPressed: _esercizi.isEmpty ? null : () => Navigator.pop(context, 'inizia'),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Inizia allenamento'),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
