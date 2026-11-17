import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../db/database_helper.dart';
import '../models/scheda.dart';
import '../theme/app_theme.dart';

/// Schede archiviate: non compaiono più tra le schede, ma il loro storico
/// (serie, record, grafici) resta. Da qui si ripristinano o si eliminano
/// definitivamente.
///
/// Chiude restituendo true se qualcosa è cambiato.
class ArchivioScreen extends StatefulWidget {
  const ArchivioScreen({super.key});

  @override
  State<ArchivioScreen> createState() => _ArchivioScreenState();
}

class _ArchivioScreenState extends State<ArchivioScreen> {
  List<Scheda> _schede = [];
  Map<int, int> _esercizi = {};
  Map<int, DateTime> _ultime = {};
  bool _loading = true;
  bool _cambiato = false;

  @override
  void initState() {
    super.initState();
    _carica();
  }

  Future<void> _carica() async {
    final db = DatabaseHelper.instance;
    final lista = await db.getSchede(archiviate: true);
    final esercizi = await db.contaEserciziPerScheda();
    final ultime = await db.getUltimaSessionePerScheda();
    if (!mounted) return;
    setState(() {
      _schede = lista;
      _esercizi = esercizi;
      _ultime = ultime;
      _loading = false;
    });
  }

  Future<void> _ripristina(Scheda s) async {
    await DatabaseHelper.instance.archiviaScheda(s.id!, archivia: false);
    _cambiato = true;
    await _carica();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('"${s.nome}" è di nuovo tra le tue schede')),
    );
  }

  Future<void> _elimina(Scheda s) async {
    final serie = await DatabaseHelper.instance.contaSerieScheda(s.id!);
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminare per sempre?'),
        content: Text(
          serie == 0
              ? '"${s.nome}" verrà eliminata definitivamente.'
              : '"${s.nome}" verrà eliminata definitivamente. Le $serie serie già fatte restano '
                  'nello storico: record e grafici non si perdono.',
        ),
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
    await DatabaseHelper.instance.deleteScheda(s.id!);
    _cambiato = true;
    await _carica();
  }

  String _quando(DateTime? d) {
    if (d == null) return 'mai fatta';
    final giorni = DateTime.now().difference(d).inDays;
    if (giorni < 1) return 'fatta oggi';
    if (giorni < 14) return 'fatta $giorni giorni fa';
    if (giorni < 60) return 'fatta ${giorni ~/ 7} settimane fa';
    return 'fatta ${giorni ~/ 30} mesi fa';
  }

  Widget _card(Scheda s) {
    final n = _esercizi[s.id] ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(18, 14, 8, 14),
      decoration: BoxDecoration(color: coloreSuperficie(context), borderRadius: BorderRadius.circular(24)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.oswald(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                Text(
                  '${n == 1 ? '1 esercizio' : '$n esercizi'} · ${_quando(_ultime[s.id])}',
                  style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Ripristina',
            onPressed: () => _ripristina(s),
            icon: Icon(Icons.unarchive_outlined, color: AppColors.accento),
          ),
          IconButton(
            tooltip: 'Elimina definitivamente',
            onPressed: () => _elimina(s),
            icon: Icon(Icons.delete_outline, color: Colors.red.shade300),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _cambiato);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Archivio')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _schede.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'Nessuna scheda archiviata.\nDal dettaglio di una scheda puoi archiviarla: '
                        'sparisce dall\'elenco ma lo storico resta.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade500, height: 1.4),
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Text(
                          'Le schede archiviate non compaiono tra le tue schede, ma record, grafici e '
                          'storico restano disponibili.',
                          style: TextStyle(color: Colors.grey.shade500, height: 1.35),
                        ),
                      ),
                      for (final s in _schede) _card(s),
                    ],
                  ),
      ),
    );
  }
}
