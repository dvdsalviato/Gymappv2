import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../amici/backup_servizio.dart';
import '../data/progressione.dart';
import '../data/statistiche.dart';
import '../data/tempo.dart';
import '../db/database_helper.dart';
import '../models/esercizio.dart';
import '../models/storico.dart';
import '../services/notifica_allenamento.dart';
import '../state/sessione_allenamento.dart';
import '../theme/app_theme.dart';
import '../widgets/animazione_esercizio.dart';

/// Modalità TABELLA (in prova): tutto l'allenamento in una pagina, come
/// Strong o Hevy. Ogni serie è una riga con kg e ripetizioni già proposti:
/// si spunta e viene salvata subito, poi parte il recupero. Si salta da un
/// esercizio all'altro, si aggiungono o tolgono serie, si corregge al volo.
///
/// È tutta in questo file (più scelta_modalita.dart): se non piace basta
/// spegnerla dal Profilo, oppure togliere i due file.
class AllenamentoTabellaScreen extends StatefulWidget {
  final List<Esercizio> esercizi;
  final String nomeScheda;
  const AllenamentoTabellaScreen({super.key, required this.esercizi, required this.nomeScheda});

  @override
  State<AllenamentoTabellaScreen> createState() => _AllenamentoTabellaScreenState();
}

class _Riga {
  final TextEditingController kg;
  final TextEditingController rep;
  final String? prima; // "75×9" dell'ultima volta
  bool fatta = false;
  int? storicoId;
  _Riga(String kgIniziale, String repIniziali, this.prima)
      : kg = TextEditingController(text: kgIniziale),
        rep = TextEditingController(text: repIniziali);

  void dispose() {
    kg.dispose();
    rep.dispose();
  }
}

class _Blocco {
  final Esercizio esercizio;
  final List<_Riga> righe;
  double? record; // carico massimo prima di oggi
  _Blocco(this.esercizio, this.righe);
}

class _AllenamentoTabellaScreenState extends State<AllenamentoTabellaScreen> {
  final List<_Blocco> _blocchi = [];
  bool _caricato = false;
  late final DateTime _inizio;
  Timer? _tick;

  // Recupero in corso
  DateTime? _fineRecupero;
  int _recuperoTotale = 0;
  String _dopo = '';

  @override
  void initState() {
    super.initState();
    _inizio = DateTime.now();
    GestoreSessione.inPausa = null;
    GestoreSessione.inizioAllenamento = _inizio;
    _prepara();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _ogniSecondo());
  }

  @override
  void dispose() {
    _tick?.cancel();
    for (final b in _blocchi) {
      for (final r in b.righe) {
        r.dispose();
      }
    }
    NotificaAllenamento.chiudi();
    super.dispose();
  }

  String _fmt(double v) => formatKg(v);

  Future<void> _prepara() async {
    final db = DatabaseHelper.instance;
    for (final e in widget.esercizi) {
      if (e.id == null) continue;
      final ultima = await db.getSerieUltimaVolta(e.id!);
      final record = await db.getRecordPersonale(e.id!);
      // Carico proposto: come nella modalità guidata, dalla prima serie dell'ultima volta.
      String kgProposto = '';
      if (!e.aTempo && ultima.isNotEmpty) {
        final p = ultima.first;
        final s = suggerisciCarico(p.carico, p.rep, e.repTarget, nome: e.nome);
        kgProposto = _fmt(s?.carico ?? p.carico);
      }
      final righe = <_Riga>[
        for (var i = 0; i < e.serieTotali; i++)
          _Riga(
            kgProposto,
            '${e.repTarget}',
            i < ultima.length
                ? (e.aTempo
                    ? formattaDurata(ultima[i].rep)
                    : '${_fmt(ultima[i].carico)}×${ultima[i].rep}')
                : null,
          ),
      ];
      _blocchi.add(_Blocco(e, righe)..record = record?.carico);
    }
    if (mounted) setState(() => _caricato = true);
    _aggiornaNotifica();
  }

  int get _fatte => _blocchi.fold(0, (a, b) => a + b.righe.where((r) => r.fatta).length);
  int get _totali => _blocchi.fold(0, (a, b) => a + b.righe.length);

  int get _restanti {
    final f = _fineRecupero;
    if (f == null) return 0;
    final s = f.difference(DateTime.now()).inMilliseconds / 1000;
    return s <= 0 ? 0 : s.ceil();
  }

  void _ogniSecondo() {
    if (!mounted) return;
    if (_fineRecupero != null && _restanti == 0) {
      _fineRecupero = null;
      HapticFeedback.heavyImpact();
      NotificaAllenamento.aggiorna(titolo: 'Recupero finito', testo: _dopo.isEmpty ? widget.nomeScheda : 'Ora: $_dopo');
    } else if (_fineRecupero != null) {
      _aggiornaNotifica();
    }
    setState(() {}); // aggiorna cronometro e barra del recupero
  }

  void _aggiornaNotifica() {
    final f = _fineRecupero;
    if (f != null) {
      NotificaAllenamento.aggiorna(
        titolo: 'Recupero',
        testo: _dopo.isEmpty ? widget.nomeScheda : 'Poi: $_dopo',
        finoA: f,
        progresso: _recuperoTotale - _restanti,
        totale: _recuperoTotale,
      );
    } else {
      NotificaAllenamento.aggiorna(titolo: widget.nomeScheda, testo: '$_fatte di $_totali serie fatte');
    }
  }

  /// La prossima serie da fare (per dire "Poi: …" durante il recupero).
  String _prossima() {
    for (final b in _blocchi) {
      for (var i = 0; i < b.righe.length; i++) {
        if (!b.righe[i].fatta) return '${b.esercizio.nome} · serie ${i + 1}';
      }
    }
    return '';
  }

  Future<void> _spunta(_Blocco b, _Riga r, int numero) async {
    final db = DatabaseHelper.instance;
    if (r.fatta) {
      // Tolta la spunta: la serie si cancella dallo storico.
      final id = r.storicoId;
      if (id != null) await db.deleteStorico(id);
      setState(() {
        r.fatta = false;
        r.storicoId = null;
      });
      _aggiornaNotifica();
      return;
    }
    final e = b.esercizio;
    final carico = e.aTempo ? 0.0 : double.tryParse(r.kg.text.replaceAll(',', '.'));
    final rep = int.tryParse(r.rep.text);
    if (carico == null || rep == null || rep <= 0 || e.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.aTempo ? 'Inserisci i secondi' : 'Inserisci kg e ripetizioni')),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    final id = await db.insertStorico(StoricoEntry(
      esercizioId: e.id!,
      serieNumero: numero,
      carico: carico,
      rep: rep,
      data: DateTime.now().toIso8601String(),
    ));
    if (!mounted) return;
    final record = b.record;
    final nuovoRecord = !e.aTempo && carico > 0 && (record == null || carico > record);
    setState(() {
      r.fatta = true;
      r.storicoId = id;
      if (nuovoRecord) b.record = carico;
      // Le serie dopo, se vuote, prendono gli stessi valori.
      final i = b.righe.indexOf(r);
      for (var j = i + 1; j < b.righe.length; j++) {
        final altra = b.righe[j];
        if (altra.fatta) continue;
        if (altra.kg.text.isEmpty) altra.kg.text = r.kg.text;
      }
      _dopo = _prossima();
      _recuperoTotale = e.riposoSecondi;
      _fineRecupero = e.riposoSecondi > 0 ? DateTime.now().add(Duration(seconds: e.riposoSecondi)) : null;
    });
    HapticFeedback.mediumImpact();
    if (nuovoRecord) {
      contaRecord();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('🏆 Nuovo record su ${e.nome}: ${_fmt(carico)} kg!')),
      );
    }
    _aggiornaNotifica();
  }

  void _cambiaRecupero(int delta) {
    final f = _fineRecupero;
    if (f == null) return;
    setState(() {
      _fineRecupero = f.add(Duration(seconds: delta));
      _recuperoTotale = (_recuperoTotale + delta).clamp(1, 3600).toInt();
      if (_restanti == 0) _fineRecupero = null;
    });
    _aggiornaNotifica();
  }

  void _saltaRecupero() {
    setState(() => _fineRecupero = null);
    _aggiornaNotifica();
  }

  void _aggiungiSerie(_Blocco b) {
    final ultima = b.righe.isEmpty ? null : b.righe.last;
    setState(() => b.righe.add(_Riga(ultima?.kg.text ?? '', ultima?.rep.text ?? '${b.esercizio.repTarget}', null)));
  }

  void _togliSerie(_Blocco b, _Riga r) {
    if (r.fatta) return;
    setState(() {
      b.righe.remove(r);
      r.dispose();
    });
  }

  Future<void> _termina() async {
    final fatte = _fatte;
    if (fatte > 0) {
      await DatabaseHelper.instance.insertSessione(widget.esercizi.first.schedaId);
      BackupServizio.istanza.backupAutomatico();
    }
    GestoreSessione.inizioAllenamento = null;
    _tick?.cancel();
    await NotificaAllenamento.chiudi();
    if (!mounted) return;
    final durata = DateTime.now().difference(_inizio);
    final volume = _blocchi.fold<double>(
      0,
      (a, b) => a +
          (b.esercizio.aTempo
              ? 0
              : b.righe.where((r) => r.fatta).fold<double>(
                    0,
                    (x, r) => x +
                        (double.tryParse(r.kg.text.replaceAll(',', '.')) ?? 0) * (int.tryParse(r.rep.text) ?? 0),
                  )),
    );
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(fatte > 0 ? 'Allenamento completato 💪' : 'Allenamento chiuso'),
        content: Text(
          fatte > 0
              ? '${widget.nomeScheda}\n${durata.inMinutes} minuti · $fatte serie · ${volume.round()} kg di volume.\n\n'
                  'Il riepilogo completo e i confronti li trovi in Progressi.'
              : 'Nessuna serie registrata.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
            child: const Text('Ok'),
          ),
        ],
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _esci() async {
    final scelta = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Terminare l\'allenamento?'),
        content: Text(
          _fatte == 0
              ? 'Non hai ancora registrato serie.'
              : 'Le $_fatte serie spuntate sono già salvate.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'continua'), child: const Text('Continua')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'termina'),
            style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
            child: const Text('Termina'),
          ),
        ],
      ),
    );
    if (scelta == 'termina') await _termina();
  }

  String _cronometro() {
    final d = DateTime.now().difference(_inizio);
    String due(int n) => n.toString().padLeft(2, '0');
    return d.inHours > 0
        ? '${d.inHours}:${due(d.inMinutes % 60)}:${due(d.inSeconds % 60)}'
        : '${due(d.inMinutes)}:${due(d.inSeconds % 60)}';
  }

  Widget _campo(TextEditingController c, {required bool decimali, required bool attivo}) {
    return SizedBox(
      height: 40,
      child: TextField(
        controller: c,
        enabled: attivo,
        textAlign: TextAlign.center,
        keyboardType: decimali ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.number,
        inputFormatters: [
          decimali ? FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')) : FilteringTextInputFormatter.digitsOnly,
        ],
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8)),
      ),
    );
  }

  Widget _blocco(_Blocco b) {
    final e = b.esercizio;
    final completato = b.righe.isNotEmpty && b.righe.every((r) => r.fatta);
    final grigio = TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w700, fontSize: 12);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      decoration: BoxDecoration(
        color: coloreCard(context),
        borderRadius: BorderRadius.circular(22),
        border: completato ? Border.all(color: AppColors.accento.withValues(alpha: 0.6)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MiniaturaEsercizio(nomeEsercizio: e.nome, dimensione: 42, aTempo: e.aTempo),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.nome, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    Text(
                      'Recupero ${e.riposoSecondi} s${b.record != null && !e.aTempo ? ' · record ${_fmt(b.record!)} kg' : ''}',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (completato) Icon(Icons.check_circle, color: AppColors.accento),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              SizedBox(width: 30, child: Text('#', style: grigio)),
              Expanded(flex: 3, child: Text('PRIMA', style: grigio)),
              if (!e.aTempo) Expanded(flex: 3, child: Text('KG', style: grigio, textAlign: TextAlign.center)),
              Expanded(flex: 3, child: Text(e.aTempo ? 'SEC' : 'RIP', style: grigio, textAlign: TextAlign.center)),
              const SizedBox(width: 48),
            ],
          ),
          for (var i = 0; i < b.righe.length; i++)
            GestureDetector(
              onLongPress: () => _togliSerie(b, b.righe[i]),
              child: Container(
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.symmetric(vertical: 2),
                decoration: BoxDecoration(
                  color: b.righe[i].fatta ? AppColors.accento.withValues(alpha: 0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 30,
                      child: Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(b.righe[i].prima ?? '–', style: TextStyle(color: Colors.grey.shade500)),
                    ),
                    if (!e.aTempo)
                      Expanded(
                        flex: 3,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: _campo(b.righe[i].kg, decimali: true, attivo: !b.righe[i].fatta),
                        ),
                      ),
                    Expanded(
                      flex: 3,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: _campo(b.righe[i].rep, decimali: false, attivo: !b.righe[i].fatta),
                      ),
                    ),
                    SizedBox(
                      width: 48,
                      child: IconButton(
                        onPressed: () => _spunta(b, b.righe[i], i + 1),
                        icon: Icon(
                          b.righe[i].fatta ? Icons.check_circle : Icons.radio_button_unchecked,
                          color: b.righe[i].fatta ? AppColors.accento : Colors.grey.shade500,
                          size: 28,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          TextButton.icon(
            onPressed: () => _aggiungiSerie(b),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Aggiungi serie'),
          ),
        ],
      ),
    );
  }

  Widget _barraRecupero() {
    final restanti = _restanti;
    final totale = _recuperoTotale <= 0 ? 1 : _recuperoTotale;
    final m = restanti ~/ 60;
    final s = (restanti % 60).toString().padLeft(2, '0');
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      decoration: BoxDecoration(
        color: coloreSuperficie(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 12)],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text('RECUPERO', style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                const SizedBox(width: 10),
                Text('$m:$s', style: GoogleFonts.oswald(fontSize: 26, fontWeight: FontWeight.w700)),
                const Spacer(),
                TextButton(onPressed: () => _cambiaRecupero(-15), child: const Text('−15')),
                TextButton(onPressed: () => _cambiaRecupero(15), child: const Text('+15')),
                TextButton(onPressed: _saltaRecupero, child: const Text('Salta')),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: 1 - restanti / totale,
                minHeight: 6,
                color: AppColors.accento,
                backgroundColor: AppColors.accento.withValues(alpha: 0.15),
              ),
            ),
            if (_dopo.isNotEmpty) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Poi: $_dopo', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _esci();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.close), onPressed: _esci, tooltip: 'Esci'),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.nomeScheda, overflow: TextOverflow.ellipsis),
              Text(
                '${_cronometro()} · $_fatte/$_totali serie',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton(
                onPressed: _termina,
                style: FilledButton.styleFrom(minimumSize: const Size(90, 40)),
                child: const Text('Fine'),
              ),
            ),
          ],
        ),
        body: !_caricato
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Spunta ✓ per salvare la serie: parte il recupero. Tieni premuta una serie non fatta per toglierla.',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                    ),
                  ),
                  for (final b in _blocchi) _blocco(b),
                ],
              ),
        bottomNavigationBar: _fineRecupero == null ? null : _barraRecupero(),
      ),
    );
  }
}
