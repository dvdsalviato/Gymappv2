import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vibration/vibration.dart';
import '../db/database_helper.dart';
import '../models/esercizio.dart';
import '../models/storico.dart';
import '../state/sessione_allenamento.dart';
import '../theme/app_theme.dart';
import '../widgets/campo_numero.dart';

class WorkoutScreen extends StatefulWidget {
  final List<Esercizio> esercizi;
  final String nomeScheda;
  final SessioneAllenamentoInPausa? ripresaDa;

  const WorkoutScreen({
    super.key,
    required this.esercizi,
    required this.nomeScheda,
    this.ripresaDa,
  });

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  late List<VoceCoda> _coda;
  FaseAllenamento _fase = FaseAllenamento.pronto;
  bool _sessioneRegistrata = false;

  // Indice usato solo nella schermata "pronto" per sfogliare gli esercizi
  // in coda con le frecce avanti/indietro, senza cambiare quale sia
  // davvero l'esercizio attivo finché non si preme "Vai".
  int _cursore = 0;

  StoricoEntry? _ultimoStorico;
  StoricoEntry? _recordPersonale;
  List<StoricoEntry> _ultimaVolta = [];
  bool _caricamentoUltimo = true;

  Timer? _timer;
  int _secondiRimanenti = 0;
  int _secondiTotali = 0;

  double _caricoInserito = 0;
  int _repInseriti = 0;

  Esercizio? _prossimoEsercizio;
  int _prossimaSerieNumero = 1;
  List<StoricoEntry> _prossimaUltimaVolta = [];
  bool _allenamentoTerminaDopoRiposo = false;

  Esercizio get _esercizioCorrente => _coda.first.esercizio;
  int get _numeroSerie => _coda.first.numeroSerie;

  @override
  void initState() {
    super.initState();
    if (widget.ripresaDa != null) {
      GestoreSessione.inizioAllenamento ??= DateTime.now();
      _coda = List.of(widget.ripresaDa!.coda);
      _fase = widget.ripresaDa!.fase;
      if (_fase == FaseAllenamento.riposo) {
        _secondiTotali = widget.ripresaDa!.secondiTotali;
        _secondiRimanenti = widget.ripresaDa!.secondiRimanenti;
      }
    } else {
      GestoreSessione.inizioAllenamento = DateTime.now();
      _coda = widget.esercizi.map((e) => VoceCoda(e, 1)).toList();
    }
    _caricaUltimoStorico();
    if (_fase == FaseAllenamento.riposo) {
      _preparaProssima();
      _avviaTimerRiposo();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    // Se non è stato messo in pausa, l'allenamento è finito (o abbandonato).
    if (GestoreSessione.inPausa == null) GestoreSessione.inizioAllenamento = null;
    super.dispose();
  }

  /// Carica ultima serie e record personale per un esercizio specifico
  /// (usato sia per l'esercizio attivo, sia mentre si sfogliano gli altri
  /// con le frecce nella schermata "pronto").
  Future<void> _caricaDatiPer(Esercizio esercizio) async {
    setState(() => _caricamentoUltimo = true);
    final esercizioId = esercizio.id;
    StoricoEntry? ultimo;
    StoricoEntry? record;
    List<StoricoEntry> ultimaVolta = [];
    if (esercizioId != null) {
      ultimo = await DatabaseHelper.instance.getUltimoStorico(esercizioId);
      record = await DatabaseHelper.instance.getRecordPersonale(esercizioId);
      ultimaVolta = await DatabaseHelper.instance.getSerieUltimaVolta(esercizioId);
    }
    if (!mounted) return;
    setState(() {
      _ultimaVolta = ultimaVolta;
      _ultimoStorico = ultimo;
      _recordPersonale = record;
      _caricamentoUltimo = false;
      _caricoInserito = ultimo?.carico ?? 0;
      _repInseriti = ultimo?.rep ?? 0;
    });
  }

  Future<void> _caricaUltimoStorico() => _caricaDatiPer(_esercizioCorrente);

  void _cambiaCursore(int delta) {
    final nuovo = (_cursore + delta).clamp(0, _coda.length - 1);
    if (nuovo == _cursore) return;
    setState(() => _cursore = nuovo);
    _caricaDatiPer(_coda[_cursore].esercizio);
  }

  void _premiVai() {
    if (_cursore != 0) {
      final voce = _coda.removeAt(_cursore);
      _coda.insert(0, voce);
    }
    _cursore = 0;
    setState(() => _fase = FaseAllenamento.inCorso);
  }

  Future<void> _premiFineSerie() async {
    final risultato = await showModalBottomSheet<Map<String, num>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RegistraSerieSheet(
        caricoIniziale: _caricoInserito,
        repIniziali: _repInseriti,
      ),
    );
    if (risultato == null) return;

    final carico = (risultato['carico'] ?? 0).toDouble();
    final rep = (risultato['rep'] ?? 0).toInt();
    final recordPrecedente = _recordPersonale;

    final esercizioId = _esercizioCorrente.id;
    if (esercizioId != null) {
      await DatabaseHelper.instance.insertStorico(
        StoricoEntry(
          esercizioId: esercizioId,
          serieNumero: _numeroSerie,
          carico: carico,
          rep: rep,
          data: DateTime.now().toIso8601String(),
        ),
      );
    }
    _caricoInserito = carico;
    _repInseriti = rep;

    final nuovoRecord = carico > 0 && (recordPrecedente == null || carico > recordPrecedente.carico);
    if (nuovoRecord && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('🏆 Nuovo record personale: $carico kg!')),
      );
    }

    _preparaProssima();

    final riposo = _esercizioCorrente.riposoSecondi;
    if (riposo <= 0) {
      _avanza();
      return;
    }

    setState(() {
      _fase = FaseAllenamento.riposo;
      _secondiTotali = riposo;
      _secondiRimanenti = riposo;
    });
    _avviaTimerRiposo();
  }

  void _avviaTimerRiposo() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => _secondiRimanenti--);
      if (_secondiRimanenti > 0 && _secondiRimanenti <= 3) {
        HapticFeedback.lightImpact();
      }
      if (_secondiRimanenti <= 0) {
        t.cancel();
        Vibration.hasVibrator().then((haVibrazione) {
          if (haVibrazione == true) {
            Vibration.vibrate(duration: 1000);
          }
        });
        _avanza();
      }
    });
  }

  void _preparaProssima() {
    final voceCorrente = _coda.first;
    final ultimaSerieEsercizio = voceCorrente.numeroSerie >= voceCorrente.esercizio.serieTotali;

    if (ultimaSerieEsercizio) {
      if (_coda.length > 1) {
        _prossimoEsercizio = _coda[1].esercizio;
        _prossimaSerieNumero = _coda[1].numeroSerie;
      } else {
        _allenamentoTerminaDopoRiposo = true;
        _prossimoEsercizio = null;
        return;
      }
    } else {
      _prossimoEsercizio = voceCorrente.esercizio;
      _prossimaSerieNumero = voceCorrente.numeroSerie + 1;
    }
    _allenamentoTerminaDopoRiposo = false;
    _caricaProssimoStorico();
  }

  Future<void> _caricaProssimoStorico() async {
    final id = _prossimoEsercizio?.id;
    if (id == null) {
      _prossimaUltimaVolta = [];
      return;
    }
    final serie = await DatabaseHelper.instance.getSerieUltimaVolta(id);
    if (mounted) {
      setState(() => _prossimaUltimaVolta = serie);
    }
  }

  void _saltaRiposo() {
    _timer?.cancel();
    _avanza();
  }

  Future<void> _avanza() async {
    final voceCorrente = _coda.first;
    final esercizioPrecedente = voceCorrente.esercizio;
    final ultimaSerieEsercizio = voceCorrente.numeroSerie >= voceCorrente.esercizio.serieTotali;

    if (ultimaSerieEsercizio) {
      _coda.removeAt(0);
    } else {
      voceCorrente.numeroSerie++;
    }

    if (_coda.isEmpty) {
      if (!_sessioneRegistrata) {
        _sessioneRegistrata = true;
        await DatabaseHelper.instance.insertSessione(widget.esercizi.first.schedaId);
      }
      setState(() => _fase = FaseAllenamento.completato);
      return;
    }

    // Stesso esercizio (prossima serie) -> parte in automatico come prima.
    // Esercizio diverso -> torna sulla schermata "pronto", dove ci sono
    // anche le frecce per sfogliare gli esercizi rimasti.
    final stessoEsercizio = identical(_coda.first.esercizio, esercizioPrecedente);

    setState(() {
      _cursore = 0;
      _fase = stessoEsercizio ? FaseAllenamento.inCorso : FaseAllenamento.pronto;
    });
    await _caricaUltimoStorico();
  }

  Future<void> _mettiInPausa() async {
    _timer?.cancel();
    final scelta = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Allenamento in pausa'),
        content: const Text('Cosa vuoi fare?'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context, 'home'),
            icon: const Icon(Icons.home_outlined),
            label: const Text('Home'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, 'riprendi'),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Riprendi'),
          ),
        ],
      ),
    );

    if (scelta == 'home') {
      final fasePausata = _fase == FaseAllenamento.riposo ? FaseAllenamento.riposo : FaseAllenamento.pronto;
      GestoreSessione.inPausa = SessioneAllenamentoInPausa(
        coda: _coda,
        nomeScheda: widget.nomeScheda,
        fase: fasePausata,
        secondiRimanenti: fasePausata == FaseAllenamento.riposo ? _secondiRimanenti : 0,
        secondiTotali: fasePausata == FaseAllenamento.riposo ? _secondiTotali : 0,
      );
      if (mounted) Navigator.pop(context);
    } else if (scelta == 'riprendi' && _fase == FaseAllenamento.riposo) {
      // Il countdown era stato fermato per mostrare il dialogo: lo
      // rimettiamo in moto da dove si trovava.
      _avviaTimerRiposo();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _mettiInPausa();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Allenamento'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.pause),
              tooltip: 'Metti in pausa',
              onPressed: _mettiInPausa,
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _buildContenuto(),
          ),
        ),
      ),
    );
  }

  Widget _suggerimento(String testo) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: coloreChip(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        testo,
        style: TextStyle(
          color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade400 : Colors.grey.shade700,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  Widget _buildContenuto() {
    switch (_fase) {
      case FaseAllenamento.completato:
        return _buildCompletato();
      case FaseAllenamento.riposo:
        return _buildRiposo();
      case FaseAllenamento.inCorso:
        return _buildInCorso();
      case FaseAllenamento.pronto:
        return _buildPronto();
    }
  }

  Widget _iconaEsercizio() {
    return Center(
      child: Container(
        width: 130,
        height: 130,
        decoration: BoxDecoration(color: coloreChip(context), shape: BoxShape.circle),
        child: const Icon(Icons.fitness_center, size: 56, color: AppColors.accento),
      ),
    );
  }

  Widget _buildPronto() {
    final voce = _coda[_cursore];
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _suggerimento('Pronto? Premi VAI quando parti con la serie!'),
          const SizedBox(height: 20),
          _hero('SERIE ${voce.numeroSerie} DI ${voce.esercizio.serieTotali}', voce.esercizio.nome, voce.esercizio.note),
          const SizedBox(height: 20),
          _iconaEsercizio(),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _chip('Obiettivo ${voce.esercizio.repTarget} reps'),
              if (_caricamentoUltimo)
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              else ...[
                if (_recordPersonale != null)
                  _chip('🏆 Record: ${_recordPersonale!.carico} kg'),
              ],
            ],
          ),
          const SizedBox(height: 16),
          _ultimaVoltaCard(_ultimaVolta, voce.numeroSerie),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _premiVai,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Vai'),
          ),
          if (_coda.length > 1) ...[
            const SizedBox(height: 20),
            Text(
              'Esercizio ${_cursore + 1} di ${_coda.length}',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _cursore > 0 ? () => _cambiaCursore(-1) : null,
                  icon: const Icon(Icons.chevron_left, size: 34),
                  tooltip: 'Esercizio precedente',
                ),
                const SizedBox(width: 24),
                IconButton(
                  onPressed: _cursore < _coda.length - 1 ? () => _cambiaCursore(1) : null,
                  icon: const Icon(Icons.chevron_right, size: 34),
                  tooltip: 'Esercizio successivo',
                ),
              ],
            ),
          ],
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildInCorso() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _suggerimento('Stai dando il massimo! Premi Fine quando hai completato la serie.'),
          const SizedBox(height: 20),
          _hero('SERIE $_numeroSerie DI ${_esercizioCorrente.serieTotali}', _esercizioCorrente.nome, _esercizioCorrente.note),
          const SizedBox(height: 20),
          _iconaEsercizio(),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _chip('Obiettivo ${_esercizioCorrente.repTarget} reps'),
              if (_recordPersonale != null)
                _chip('🏆 Record: ${_recordPersonale!.carico} kg'),
            ],
          ),
          const SizedBox(height: 16),
          _ultimaVoltaCard(_ultimaVolta, _numeroSerie),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _premiFineSerie,
            icon: const Icon(Icons.check),
            label: const Text('Fine serie'),
          ),
          const SizedBox(height: 72),
        ],
      ),
    );
  }

  Widget _buildRiposo() {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _suggerimento('Bel lavoro! Recupera le energie, si riparte tra poco.'),
          const SizedBox(height: 20),
          const Text(
            'RIPOSO',
            style: TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.bold,
              fontSize: 16,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: 200,
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 200,
                  height: 200,
                  child: CircularProgressIndicator(
                    value: _secondiTotali == 0 ? 0 : _secondiRimanenti / _secondiTotali,
                    strokeWidth: 10,
                    backgroundColor: coloreChip(context),
                    valueColor: const AlwaysStoppedAnimation(AppColors.accento),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$_secondiRimanenti',
                      style: const TextStyle(fontSize: 52, fontWeight: FontWeight.bold),
                    ),
                    Text('secondi', style: TextStyle(color: Colors.grey.shade600)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (_prossimoEsercizio != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: coloreCard(context),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  const Text(
                    'PROSSIMA SERIE',
                    style: TextStyle(
                      color: AppColors.accento,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _prossimoEsercizio!.nome,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Serie $_prossimaSerieNumero di ${_prossimoEsercizio!.serieTotali} · Obiettivo ${_prossimoEsercizio!.repTarget} reps',
                    style: TextStyle(color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  _ultimaVoltaCard(_prossimaUltimaVolta, _prossimaSerieNumero, compatta: true),
                ],
              ),
            ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _saltaRiposo,
            child: const Text('Salta riposo'),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildCompletato() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _suggerimento('Grande, allenamento completato! Sei una macchina 💪'),
        const SizedBox(height: 24),
        const Icon(Icons.check_circle, color: AppColors.accento, size: 72),
        const SizedBox(height: 16),
        const Text(
          'Allenamento completato!',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 32),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Torna alla scheda'),
        ),
      ],
    );
  }

  Widget _hero(String serie, String nome, String? note) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.accento,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            serie,
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w700,
              fontSize: 14,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            nome,
            style: GoogleFonts.oswald(
              color: Colors.black,
              fontSize: 30,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
          if (note != null && note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '📝 $note',
              style: const TextStyle(color: Colors.black87, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  String _numeroBreve(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  String _dataBreve(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return '';
    const giorni = ['lun', 'mar', 'mer', 'gio', 'ven', 'sab', 'dom'];
    return '${giorni[d.weekday - 1]} ${d.day}/${d.month}';
  }

  /// Riquadro con TUTTE le serie dell'ultima volta in cui hai fatto questo
  /// esercizio; la serie che stai per fare (o che stai facendo) è evidenziata.
  Widget _ultimaVoltaCard(List<StoricoEntry> serie, int serieCorrente, {bool compatta = false}) {
    if (_caricamentoUltimo && !compatta) return const SizedBox.shrink();

    final sfondo = compatta ? coloreChip(context) : coloreCard(context);

    if (serie.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: sfondo, borderRadius: BorderRadius.circular(20)),
        child: Row(
          mainAxisAlignment: compatta ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            const Icon(Icons.trending_up, color: AppColors.accento, size: 20),
            const SizedBox(width: 10),
            Text(
              'Prima volta con questo esercizio',
              style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    final righe = <Widget>[];
    for (final s in serie) {
      final attuale = s.serieNumero == serieCorrente;
      righe.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              SizedBox(
                width: 72,
                child: Text(
                  'Serie ${s.serieNumero}',
                  style: TextStyle(
                    color: attuale ? AppColors.accento : Colors.grey.shade500,
                    fontWeight: attuale ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ),
              Text(
                '${_numeroBreve(s.carico)} kg × ${s.rep}',
                style: TextStyle(
                  color: attuale ? AppColors.accento : null,
                  fontWeight: attuale ? FontWeight.bold : FontWeight.w500,
                  fontSize: attuale ? 18 : 15,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(color: sfondo, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ULTIMA VOLTA · ${_dataBreve(serie.first.data)}',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          ...righe,
        ],
      ),
    );
  }

  Widget _chip(String testo) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: coloreChip(context),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(testo, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}

class _RegistraSerieSheet extends StatefulWidget {
  final double caricoIniziale;
  final int repIniziali;

  const _RegistraSerieSheet({required this.caricoIniziale, required this.repIniziali});

  @override
  State<_RegistraSerieSheet> createState() => _RegistraSerieSheetState();
}

class _RegistraSerieSheetState extends State<_RegistraSerieSheet> {
  final _caricoKey = GlobalKey<CampoNumeroState>();
  final _repKey = GlobalKey<CampoNumeroState>();

  void _conferma() {
    final carico = _caricoKey.currentState?.valore ?? 0;
    final rep = _repKey.currentState?.valore ?? 0;
    Navigator.pop(context, {'carico': carico, 'rep': rep});
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        // Sopra la tastiera, oppure sopra i tasti/barra di navigazione Android.
        bottom: (MediaQuery.of(context).viewInsets.bottom > MediaQuery.of(context).viewPadding.bottom
                ? MediaQuery.of(context).viewInsets.bottom
                : MediaQuery.of(context).viewPadding.bottom) +
            28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Registra la serie', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            'Trascina su/giù, usa le frecce o tocca due volte il numero per scriverlo',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              CampoNumero(
                key: _caricoKey,
                etichetta: 'Carico (kg)',
                valoreIniziale: widget.caricoIniziale,
                step: 0.5,
                decimali: true,
              ),
              CampoNumero(
                key: _repKey,
                etichetta: 'Reps',
                valoreIniziale: widget.repIniziali.toDouble(),
                step: 1,
              ),
            ],
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: _conferma,
            icon: const Icon(Icons.check),
            label: const Text('Conferma serie'),
          ),
        ],
      ),
    );
  }
}
