import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/tempo.dart';
import '../db/database_helper.dart';
import '../models/esercizio.dart';
import '../models/scheda.dart';
import '../theme/app_theme.dart';
import '../widgets/animazione_esercizio.dart';
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
  late String _nome = widget.scheda.nome;

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
    // Il nome potrebbe essere cambiato nell'editor.
    final schede = await DatabaseHelper.instance.getSchede();
    for (final s in schede) {
      if (s.id == widget.scheda.id) _nome = s.nome;
    }
    await _carica();
  }

  Future<void> _duplica() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Duplicare la scheda?'),
        content: Text(
          'Verrà creata una copia di "$_nome" con gli stessi esercizi. Lo storico non viene copiato.',
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

  /// Durata stimata: per ogni serie il tempo di esecuzione (circa 3 secondi a
  /// ripetizione, o la durata se è a tempo) più il recupero, e un minuto per
  /// passare da un esercizio all'altro.
  int _minutiStimati() {
    var secondi = 0;
    for (final e in _esercizi) {
      final esecuzione = e.aTempo ? e.repTarget : e.repTarget * 3;
      secondi += e.serieTotali * (esecuzione + e.riposoSecondi) + 60;
    }
    final minuti = (secondi / 60).round();
    return minuti < 10 ? minuti : ((minuti + 2) ~/ 5) * 5;
  }

  Widget _tessera(String valore, String etichetta) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: coloreCard(context), borderRadius: BorderRadius.circular(18)),
        child: Column(
          children: [
            Text(valore, style: GoogleFonts.oswald(fontSize: 24, fontWeight: FontWeight.w700, height: 1.1)),
            const SizedBox(height: 2),
            Text(etichetta, style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  /// Riepilogo in alto: numeri principali e muscoli allenati.
  Widget _riepilogo() {
    final serieTotali = _esercizi.fold<int>(0, (a, e) => a + e.serieTotali);
    final perGruppo = <String, int>{};
    for (final e in _esercizi) {
      perGruppo[e.categoria] = (perGruppo[e.categoria] ?? 0) + e.serieTotali;
    }
    final gruppi = perGruppo.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _tessera('${_esercizi.length}', 'esercizi'),
              const SizedBox(width: 8),
              _tessera('$serieTotali', 'serie'),
              const SizedBox(width: 8),
              _tessera('~${_minutiStimati()}', 'minuti'),
            ],
          ),
          if (gruppi.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final g in gruppi)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.accento.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${g.key} · ${g.value} serie',
                      style: const TextStyle(color: AppColors.accento, fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _riposo(int s) => (s >= 120 && s % 60 == 0) ? '${s ~/ 60} min' : '$s s';

  Widget _riga(int indice, Esercizio e) {
    final obiettivo = e.aTempo ? '${e.serieTotali} × ${formattaDurata(e.repTarget)}' : '${e.serieTotali} × ${e.repTarget}';
    final note = e.note?.trim() ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 10, 16, 10),
      decoration: BoxDecoration(color: coloreCard(context), borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          MiniaturaEsercizio(nomeEsercizio: e.nome, numero: indice + 1, aTempo: e.aTempo),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (e.supersetId != 0)
                  const Text(
                    'SUPERSET',
                    style: TextStyle(color: AppColors.accento, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1.3),
                  ),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_nome),
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
                            _riepilogo(),
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
