import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../amici/amici_servizio.dart';
import '../amici/firestore_rest.dart';
import '../data/statistiche.dart';
import '../data/tempo.dart';
import '../db/database_helper.dart';
import '../services/condivisione_scheda.dart';
import '../services/importa_scheda.dart';
import '../theme/app_theme.dart';
import 'chat_screen.dart';

class _Confronto {
  final String nome;
  final double io;
  final double lui;
  const _Confronto(this.nome, this.io, this.lui);
}

/// Profilo di un amico: confronto di obiettivi, carichi e schede, e chat.
class AmicoScreen extends StatefulWidget {
  final Amicizia amicizia;
  final StatAmico? stat;

  const AmicoScreen({super.key, required this.amicizia, this.stat});

  @override
  State<AmicoScreen> createState() => _AmicoScreenState();
}

class _AmicoScreenState extends State<AmicoScreen> {
  final AmiciServizio _servizio = AmiciServizio.istanza;

  StatAmico? _stat;
  StatisticheUtente? _mie;
  int _mieMedaglie = 0;
  List<Map<String, dynamic>> _mieiRecord = [];
  bool _caricamento = true;
  String? _errore;

  @override
  void initState() {
    super.initState();
    _stat = widget.stat;
    _carica();
  }

  Future<void> _carica() async {
    setState(() {
      _caricamento = true;
      _errore = null;
    });
    try {
      final mie = await caricaStatistiche();
      final record = await DatabaseHelper.instance.getRecordPerEsercizio(limite: 100);
      final prefs = await SharedPreferences.getInstance();
      final medaglie = (prefs.getStringList('medaglie_sbloccate') ?? const <String>[]).length;
      final stat = await _servizio.statisticheAmico(widget.amicizia.uidAltro) ?? _stat;
      if (!mounted) return;
      setState(() {
        _mie = mie;
        _mieiRecord = record;
        _mieMedaglie = medaglie;
        _stat = stat;
        _caricamento = false;
      });
    } on AmiciErrore catch (e) {
      if (!mounted) return;
      setState(() {
        _errore = e.messaggio;
        _caricamento = false;
      });
    }
  }

  void _avviso(String testo) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(testo)));
  }

  Future<void> _rimuovi() async {
    final conferma = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Rimuovere ${widget.amicizia.nomeAltro}?'),
        content: const Text('Non vedrete più le statistiche l\'uno dell\'altro e la chat non sarà più accessibile.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
            child: const Text('Rimuovi'),
          ),
        ],
      ),
    );
    if (conferma != true) return;
    try {
      await _servizio.rimuovi(widget.amicizia.id);
      if (mounted) Navigator.pop(context, true);
    } on AmiciErrore catch (e) {
      _avviso(e.messaggio);
    }
  }

  // ------------------------------------------------------------------- UI

  Widget _etichetta(String t) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 10),
        child: Text(
          t,
          style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 1.4),
        ),
      );

  Widget _scheda({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: coloreSuperficie(context), borderRadius: BorderRadius.circular(28)),
        child: child,
      );

  Widget _riga(String etichetta, int io, int lui, {bool evidenzia = true}) {
    final vinceIo = evidenzia && io > lui;
    final vinceLui = evidenzia && lui > io;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$io',
              textAlign: TextAlign.center,
              style: GoogleFonts.oswald(fontSize: 24, fontWeight: FontWeight.w700, color: vinceIo ? AppColors.accento : null),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              etichetta,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              '$lui',
              textAlign: TextAlign.center,
              style: GoogleFonts.oswald(fontSize: 24, fontWeight: FontWeight.w700, color: vinceLui ? AppColors.accento : null),
            ),
          ),
        ],
      ),
    );
  }

  Widget _confrontoNumeri(StatisticheUtente mie, StatAmico s) {
    return _scheda(
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('TU', textAlign: TextAlign.center, style: TextStyle(color: AppColors.accento, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
              ),
              const Expanded(flex: 2, child: SizedBox.shrink()),
              Expanded(
                child: Text(
                  widget.amicizia.nomeAltro.toUpperCase(),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _riga('ALLENAMENTI', mie.allenamenti, s.allenamenti),
          _riga('SERIE TOTALI', mie.serie, s.serie),
          _riga('SETTIMANE DI FILA', mie.settimane, s.settimane),
          _riga('MEDAGLIE', _mieMedaglie, s.medaglie),
          _riga('QUESTA SETTIMANA', mie.allenamentiSettimana, s.allenSettimana),
          _riga('OBIETTIVO SETTIMANALE', mie.obiettivo, s.obiettivo, evidenzia: false),
        ],
      ),
    );
  }

  String _kg(double v) {
    final t = v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
    return t.replaceAll('.', ',');
  }

  Widget _barra(double valore, double massimo, Color colore, String etichetta) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: massimo <= 0 ? 0 : valore / massimo,
              minHeight: 10,
              backgroundColor: coloreChip(context),
              color: colore,
            ),
          ),
        ),
        SizedBox(
          width: 64,
          child: Text('$etichetta kg', textAlign: TextAlign.end, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _carichi(StatAmico s) {
    final miei = {
      for (final r in _mieiRecord) (r['nome'] as String).toLowerCase(): (r['kg'] as num).toDouble(),
    };
    final comuni = <_Confronto>[];
    for (final r in s.records) {
      final io = miei[r.nome.toLowerCase()];
      if (io != null) comuni.add(_Confronto(r.nome, io, r.kg));
    }
    comuni.sort((a, b) => math.max(b.io, b.lui).compareTo(math.max(a.io, a.lui)));
    final top = comuni.take(8).toList();

    if (top.isEmpty) {
      return _scheda(
        child: Text(
          s.records.isEmpty
              ? 'Nessun carico registrato da ${widget.amicizia.nomeAltro}.'
              : 'Non avete ancora esercizi in comune con un carico registrato.',
          style: TextStyle(color: Colors.grey.shade500),
        ),
      );
    }
    return _scheda(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final c in top)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.nome, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  _barra(c.io, math.max(c.io, c.lui), AppColors.accento, _kg(c.io)),
                  const SizedBox(height: 4),
                  _barra(c.lui, math.max(c.io, c.lui), Colors.white54, _kg(c.lui)),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppColors.accento, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text('Tu', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              const SizedBox(width: 16),
              Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.white54, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(widget.amicizia.nomeAltro, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  void _apriScheda(SchedaImportata s) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(s.nome, style: GoogleFonts.oswald(fontSize: 28, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('di ${widget.amicizia.nomeAltro}', style: TextStyle(color: Colors.grey.shade500)),
              const SizedBox(height: 14),
              for (final e in s.esercizi)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(child: Text(e.nome, style: const TextStyle(fontWeight: FontWeight.w600))),
                      Text(
                        e.aTempo ? '${e.serieTotali} x ${formattaDurata(e.repTarget)}' : '${e.serieTotali} x ${e.repTarget}',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await salvaSchedaImportata(s);
                  _avviso('Scheda "${s.nome}" importata');
                },
                icon: const Icon(Icons.download_done),
                label: const Text('Importa nelle mie schede'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _schede(StatAmico s) {
    final decodificate = <SchedaImportata>[];
    for (final testo in s.schede) {
      final d = decodificaScheda(testo);
      if (d != null) decodificate.add(d);
    }
    if (decodificate.isEmpty) {
      return _scheda(
        child: Text(
          '${widget.amicizia.nomeAltro} non condivide schede (o non ne ha ancora).',
          style: TextStyle(color: Colors.grey.shade500),
        ),
      );
    }
    return Column(
      children: [
        for (final d in decodificate)
          GestureDetector(
            onTap: () => _apriScheda(d),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: coloreSuperficie(context), borderRadius: BorderRadius.circular(22)),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.nome, style: GoogleFonts.oswald(fontSize: 20, fontWeight: FontWeight.w600)),
                        Text('${d.esercizi.length} esercizi', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.grey.shade600),
                ],
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _stat;
    final mie = _mie;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.amicizia.nomeAltro),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'rimuovi') _rimuovi();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'rimuovi', child: Text('Rimuovi amico')),
            ],
          ),
        ],
      ),
      body: _caricamento && s == null
          ? const Center(child: CircularProgressIndicator())
          : _errore != null && s == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_errore!, textAlign: TextAlign.center),
                        const SizedBox(height: 14),
                        FilledButton(onPressed: _carica, child: const Text('Riprova')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _carica,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                    children: [
                      FilledButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ChatScreen(amicizia: widget.amicizia)),
                        ),
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: const Text('Apri chat'),
                      ),
                      if (s == null)
                        Padding(
                          padding: const EdgeInsets.only(top: 18),
                          child: _scheda(
                            child: Text(
                              'Le statistiche di ${widget.amicizia.nomeAltro} non sono ancora disponibili: compariranno dopo il suo primo accesso.',
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          ),
                        )
                      else ...[
                        _etichetta('CONFRONTO'),
                        if (mie != null) _confrontoNumeri(mie, s),
                        _etichetta('CARICHI A CONFRONTO'),
                        _carichi(s),
                        _etichetta('SCHEDE DI ${widget.amicizia.nomeAltro.toUpperCase()}'),
                        _schede(s),
                      ],
                    ],
                  ),
                ),
    );
  }
}
