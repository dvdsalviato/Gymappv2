import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/progressione.dart';
import '../data/tempo.dart';
import '../models/riepilogo.dart';
import '../services/notifica_allenamento.dart';
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

class _WorkoutScreenState extends State<WorkoutScreen> with SingleTickerProviderStateMixin {
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
  RiepilogoSessione? _riepilogo;

  // Countdown del riposo: l'anello è guidato da un AnimationController (si
  // muove a ogni fotogramma, quindi è fluido); la fine è decisa da un timer
  // sull'ora esatta di scadenza, che funziona anche a schermo spento.
  late final AnimationController _riposoCtrl;
  Timer? _timerFine;
  DateTime? _fineRiposo;
  int _ultimoSecondoMostrato = -1;
  bool _dialogPausa = false;
  String _firmaNotifica = '';
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
    _riposoCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..addListener(_onTickRiposo);
    NotificaAllenamento.onAzione = (azione) {
      if (azione == NotificaAllenamento.azioneSaltaRiposo &&
          mounted &&
          _fase == FaseAllenamento.riposo &&
          !_dialogPausa) {
        _saltaRiposo();
      }
    };
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
    _sincronizzaNotifica();
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _sincronizzaNotifica();
  }

  @override
  void dispose() {
    NotificaAllenamento.onAzione = null;
    _fermaTimerRiposo(sincronizza: false);
    _riposoCtrl.dispose();
    NotificaAllenamento.chiudi();
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
      ultimaVolta = await DatabaseHelper.instance.getSerieUltimaVolta(
        esercizioId,
        prima: GestoreSessione.inizioAllenamento,
      );
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
    final aTempo = _coda.first.esercizio.aTempo;
    setState(() {
      _fase = FaseAllenamento.inCorso;
      if (aTempo) {
        _secondiTotali = _coda.first.esercizio.repTarget;
        _secondiRimanenti = _secondiTotali;
      }
    });
    if (aTempo) _avviaTimerRiposo();
  }

  Future<void> _premiFineSerie() async {
    final risultato = await showModalBottomSheet<Map<String, num>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RegistraSerieSheet(
        caricoIniziale: _caricoInserito,
        repIniziali: _repInseriti,
        consiglio: _calcolaConsiglio(_esercizioCorrente, _numeroSerie),
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

  double _secondiResiduiPrecisi() {
    final fine = _fineRiposo;
    if (fine == null) return _secondiRimanenti.toDouble();
    final ms = fine.difference(DateTime.now()).inMilliseconds;
    return ms <= 0 ? 0.0 : ms / 1000.0;
  }

  void _onTickRiposo() {
    final s = _secondiResiduiPrecisi().ceil();
    if (s != _ultimoSecondoMostrato) {
      _ultimoSecondoMostrato = s;
      if (s > 0 && s <= 3 && (_fase == FaseAllenamento.riposo || _fase == FaseAllenamento.inCorso)) {
        HapticFeedback.lightImpact();
      }
    }
  }

  void _avviaTimerRiposo() {
    _fermaTimerRiposo(sincronizza: false);
    final totaleMs = _secondiTotali * 1000;
    var rimanentiMs = _secondiRimanenti * 1000;
    if (rimanentiMs > totaleMs) rimanentiMs = totaleMs;
    if (rimanentiMs < 0) rimanentiMs = 0;
    _fineRiposo = DateTime.now().add(Duration(milliseconds: rimanentiMs));
    _ultimoSecondoMostrato = -1;
    if (totaleMs > 0) {
      _riposoCtrl.duration = Duration(milliseconds: totaleMs);
      _riposoCtrl.forward(from: 1 - rimanentiMs / totaleMs);
    }
    _timerFine = Timer(Duration(milliseconds: rimanentiMs), _fineRiposoTerminato);
    _sincronizzaNotifica();
  }

  void _fermaTimerRiposo({bool sincronizza = true}) {
    _timerFine?.cancel();
    _timerFine = null;
    _riposoCtrl.stop();
    _fineRiposo = null;
    if (sincronizza) _sincronizzaNotifica();
  }

  void _vibraFine() {
    Vibration.hasVibrator().then((haVibrazione) {
      if (haVibrazione == true) {
        Vibration.vibrate(duration: 1000);
      }
    });
  }

  /// Scade il countdown: fine del riposo oppure fine di un esercizio a tempo.
  void _fineRiposoTerminato() {
    _fermaTimerRiposo(sincronizza: false);
    if (!mounted) return;
    if (_fase == FaseAllenamento.riposo) {
      _vibraFine();
      _avanza();
    } else if (_fase == FaseAllenamento.inCorso && _esercizioCorrente.aTempo) {
      _vibraFine();
      _completaSerieATempo(_secondiTotali);
    }
  }

  /// Registra una serie a tempo (nello storico il tempo fatto va nelle "rep")
  /// e passa al riposo, come per una serie normale.
  Future<void> _completaSerieATempo(int secondiFatti) async {
    final esercizioId = _esercizioCorrente.id;
    if (esercizioId != null) {
      await DatabaseHelper.instance.insertStorico(
        StoricoEntry(
          esercizioId: esercizioId,
          serieNumero: _numeroSerie,
          carico: 0,
          rep: secondiFatti,
          data: DateTime.now().toIso8601String(),
        ),
      );
    }
    if (!mounted) return;
    _caricoInserito = 0;
    _repInseriti = secondiFatti;
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

  void _terminaPrima() {
    final fatti = _secondiTotali - _secondiResiduiPrecisi().ceil();
    _fermaTimerRiposo(sincronizza: false);
    _completaSerieATempo(fatti < 1 ? 1 : fatti);
  }

  /// Tiene allineata la notifica fissa con quello che stai facendo.
  void _sincronizzaNotifica() {
    if (!mounted) return;
    String titolo;
    String testo;
    DateTime? finoA;
    var saltabile = false;

    if (_fase == FaseAllenamento.completato || _coda.isEmpty) {
      if (_firmaNotifica != 'fine') {
        _firmaNotifica = 'fine';
        NotificaAllenamento.chiudi();
      }
      return;
    }
    if (_dialogPausa) {
      titolo = 'Allenamento in pausa';
      testo = widget.nomeScheda;
    } else if (_fase == FaseAllenamento.riposo) {
      final p = _prossimoEsercizio;
      titolo = 'Riposo';
      testo = p == null
          ? 'Ultimo recupero, poi hai finito!'
          : 'Poi: ${p.nome} · serie $_prossimaSerieNumero di ${p.serieTotali}';
      finoA = _fineRiposo;
      saltabile = true;
    } else if (_fase == FaseAllenamento.inCorso) {
      final e = _esercizioCorrente;
      titolo = e.nome;
      if (e.aTempo) {
        testo = 'Serie $_numeroSerie di ${e.serieTotali} · ${formattaDurata(e.repTarget)}';
        finoA = _fineRiposo;
      } else {
        testo = 'Serie $_numeroSerie di ${e.serieTotali} · obiettivo ${e.repTarget} reps';
      }
    } else {
      final v = _coda[_cursore < _coda.length ? _cursore : 0];
      titolo = widget.nomeScheda;
      testo = 'Prossimo: ${v.esercizio.nome} · serie ${v.numeroSerie} di ${v.esercizio.serieTotali}';
    }
    final firma = '$_fase|$titolo|$testo|${finoA?.millisecondsSinceEpoch}|$saltabile';
    if (firma == _firmaNotifica) return;
    _firmaNotifica = firma;
    NotificaAllenamento.aggiorna(titolo: titolo, testo: testo, finoA: finoA, saltabile: saltabile);
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
    final serie = await DatabaseHelper.instance.getSerieUltimaVolta(
      id,
      prima: GestoreSessione.inizioAllenamento,
    );
    if (mounted) {
      setState(() => _prossimaUltimaVolta = serie);
    }
  }

  void _saltaRiposo() {
    _fermaTimerRiposo(sincronizza: false);
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
      await _caricaRiepilogo();
      if (!mounted) return;
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
    if (_fase == FaseAllenamento.riposo || (_fase == FaseAllenamento.inCorso && _esercizioCorrente.aTempo)) {
      _secondiRimanenti = _secondiResiduiPrecisi().ceil();
    }
    _dialogPausa = true;
    _fermaTimerRiposo();
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

    _dialogPausa = false;
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
    } else if (scelta == 'riprendi' &&
        (_fase == FaseAllenamento.riposo || (_fase == FaseAllenamento.inCorso && _esercizioCorrente.aTempo))) {
      // Il countdown era stato fermato per mostrare il dialogo: lo
      // rimettiamo in moto da dove si trovava.
      _avviaTimerRiposo();
    } else {
      _sincronizzaNotifica();
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

  /// Anello che scende in modo fluido (riposo ed esercizi a tempo).
  Widget _anelloCountdown({required String etichetta, bool orologio = false, double dimensione = 200}) {
    return SizedBox(
      width: dimensione,
      height: dimensione,
      child: AnimatedBuilder(
        animation: _riposoCtrl,
        builder: (context, _) {
          final residuo = _secondiResiduiPrecisi();
          final progresso = _secondiTotali == 0 ? 0.0 : (residuo / _secondiTotali).clamp(0.0, 1.0);
          final secondi = residuo.ceil();
          final testo = orologio ? formattaOrologio(secondi) : '$secondi';
          return Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: dimensione,
                height: dimensione,
                child: CircularProgressIndicator(
                  value: progresso.toDouble(),
                  strokeWidth: 10,
                  strokeCap: StrokeCap.round,
                  backgroundColor: coloreChip(context),
                  valueColor: const AlwaysStoppedAnimation(AppColors.accento),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: Text(
                      testo,
                      key: ValueKey<String>(testo),
                      style: GoogleFonts.oswald(fontSize: orologio ? 54 : 60, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(etichetta, style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _iconaEsercizio({IconData icona = Icons.fitness_center}) {
    return Center(
      child: Container(
        width: 130,
        height: 130,
        decoration: BoxDecoration(color: coloreChip(context), shape: BoxShape.circle),
        child: Icon(icona, size: 56, color: AppColors.accento),
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
          _iconaEsercizio(icona: voce.esercizio.aTempo ? Icons.timer_outlined : Icons.fitness_center),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _chip(voce.esercizio.aTempo
                  ? 'Durata ${formattaDurata(voce.esercizio.repTarget)}'
                  : 'Obiettivo ${voce.esercizio.repTarget} reps'),
              if (_caricamentoUltimo)
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              else ...[
                if (_recordPersonale != null && !voce.esercizio.aTempo)
                  _chip('🏆 Record: ${_recordPersonale!.carico} kg'),
              ],
            ],
          ),
          const SizedBox(height: 16),
          _ultimaVoltaCard(_ultimaVolta, voce.numeroSerie, aTempo: voce.esercizio.aTempo),
          ..._consiglioWidget(voce.esercizio, voce.numeroSerie),
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
    final e = _esercizioCorrente;
    final aTempo = e.aTempo;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _suggerimento(aTempo
              ? 'Tieni duro! Il timer scende da solo: a zero passi al recupero.'
              : 'Stai dando il massimo! Premi Fine quando hai completato la serie.'),
          const SizedBox(height: 20),
          _hero('SERIE $_numeroSerie DI ${e.serieTotali}', e.nome, e.note),
          const SizedBox(height: 20),
          if (aTempo)
            Center(child: _anelloCountdown(etichetta: 'rimanenti', orologio: true, dimensione: 230))
          else
            _iconaEsercizio(),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _chip(aTempo ? 'Durata ${formattaDurata(e.repTarget)}' : 'Obiettivo ${e.repTarget} reps'),
              if (!aTempo && _recordPersonale != null) _chip('🏆 Record: ${_recordPersonale!.carico} kg'),
            ],
          ),
          const SizedBox(height: 16),
          _ultimaVoltaCard(_ultimaVolta, _numeroSerie, aTempo: aTempo),
          ..._consiglioWidget(e, _numeroSerie),
          const SizedBox(height: 32),
          if (aTempo)
            OutlinedButton.icon(
              onPressed: _terminaPrima,
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('Termina ora'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                shape: const StadiumBorder(),
              ),
            )
          else
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
          Center(child: _anelloCountdown(etichetta: 'secondi')),
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
                    _prossimoEsercizio!.aTempo
                        ? 'Serie $_prossimaSerieNumero di ${_prossimoEsercizio!.serieTotali} · ${formattaDurata(_prossimoEsercizio!.repTarget)}'
                        : 'Serie $_prossimaSerieNumero di ${_prossimoEsercizio!.serieTotali} · Obiettivo ${_prossimoEsercizio!.repTarget} reps',
                    style: TextStyle(color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  _ultimaVoltaCard(
                    _prossimaUltimaVolta,
                    _prossimaSerieNumero,
                    compatta: true,
                    aTempo: _prossimoEsercizio?.aTempo ?? false,
                  ),
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

  Future<void> _caricaRiepilogo() async {
    final inizio = GestoreSessione.inizioAllenamento ?? DateTime.now().subtract(const Duration(hours: 2));
    try {
      final righe = await DatabaseHelper.instance.getEserciziDaData(inizio);
      final esercizi = righe.map((r) {
        final max = (r['carico_max'] as num).toDouble();
        final prima = (r['record_prima'] as num?)?.toDouble();
        return EsercizioRiepilogo(
          r['nome'] as String,
          r['categoria'] as String,
          r['serie'] as int,
          max,
          (r['volume'] as num?)?.toDouble() ?? 0,
          prima != null && max > prima,
          aTempo: (r['a_tempo'] as int?) == 1,
          secondi: (r['rep_tot'] as num?)?.toInt() ?? 0,
        );
      }).toList();
      _riepilogo = RiepilogoSessione(widget.nomeScheda, DateTime.now().difference(inizio), esercizi);
    } catch (_) {
      _riepilogo = null;
    }
  }

  /// Carico consigliato per la serie che stai per fare.
  Suggerimento? _calcolaConsiglio(Esercizio esercizio, int numeroSerie) {
    if (esercizio.aTempo) return null;
    final target = esercizio.repTarget;
    if (numeroSerie > 1 && _caricoInserito > 0 && identical(esercizio, _coda.first.esercizio)) {
      return suggerisciCarico(_caricoInserito, _repInseriti, target);
    }
    for (final s in _ultimaVolta) {
      if (s.serieNumero == numeroSerie) return suggerisciCarico(s.carico, s.rep, target);
    }
    return null;
  }

  List<Widget> _consiglioWidget(Esercizio esercizio, int numeroSerie) {
    final c = _calcolaConsiglio(esercizio, numeroSerie);
    if (c == null) return [];
    return [
      const SizedBox(height: 10),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.accento.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.accento.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            Icon(c.aumento ? Icons.trending_up : Icons.lightbulb_outline, color: AppColors.accento, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Consigliato: ${formatKg(c.carico)} kg',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(c.testo, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    ];
  }

  String _durataTesto(Duration d) {
    String due(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    return h > 0 ? '$h:${due(m)}:${due(s)}' : '${due(m)}:${due(s)}';
  }

  String _volumeTesto(double v) {
    final n = v.round().toString();
    final conPunti = n.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
    return '$conPunti kg';
  }

  Future<void> _copiaRiepilogo(RiepilogoSessione r) async {
    final righe = <String>[
      'Gymapp - ${r.nomeScheda}',
      'Durata ${_durataTesto(r.durata)} · ${r.serie} serie · ${_volumeTesto(r.volume)}',
      if (r.record > 0) 'Record battuti: ${r.record}',
      if (r.muscoliLavorati.isNotEmpty) 'Muscoli: ${r.muscoliLavorati.join(', ')}',
      '',
      for (final e in r.esercizi)
        '- ${e.nome}: ${_dettaglioRiepilogo(e)}${e.record ? ' (record)' : ''}',
      '',
      'Do it better 💪',
    ];
    await Clipboard.setData(ClipboardData(text: righe.join('\n')));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Riepilogo copiato: incollalo dove vuoi')),
      );
    }
  }

  String _dettaglioRiepilogo(EsercizioRiepilogo e) {
    if (e.aTempo) return '${e.serie} serie · ${formattaDurata(e.secondi)}';
    return '${e.serie} serie · ${formatKg(e.caricoMax)} kg';
  }

  Widget _statRiepilogo(String valore, String etichetta) {
    return Expanded(
      child: Column(
        children: [
          Text(valore, style: GoogleFonts.oswald(fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(etichetta, style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _cardRiepilogo(RiepilogoSessione r) {
    final muscoliLavorati = r.muscoliLavorati;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: coloreSuperficie(context),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppColors.accento.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset('assets/logo.png', width: 48, height: 48, fit: BoxFit.cover),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ALLENAMENTO COMPLETATO',
                      style: TextStyle(color: AppColors.accento, fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 1.3),
                    ),
                    Text(
                      r.nomeScheda,
                      style: GoogleFonts.oswald(fontSize: 24, fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _statRiepilogo(_durataTesto(r.durata), 'DURATA'),
              _statRiepilogo('${r.serie}', 'SERIE'),
              _statRiepilogo(_volumeTesto(r.volume), 'VOLUME'),
              _statRiepilogo('${r.record}', 'RECORD'),
            ],
          ),
          if (muscoliLavorati.isNotEmpty) ...[
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in muscoliLavorati)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.accento.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(m, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          for (final e in r.esercizi)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(child: Text(e.nome, style: const TextStyle(fontWeight: FontWeight.w600))),
                  Text(
                    _dettaglioRiepilogo(e),
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                  ),
                  if (e.record) const Padding(padding: EdgeInsets.only(left: 6), child: Text('🏆')),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCompletato() {
    final r = _riepilogo;
    if (r == null || r.esercizi.isEmpty) {
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
    return SingleChildScrollView(
      child: Column(
        children: [
          _suggerimento('Grande, allenamento completato! Sei una macchina 💪'),
          const SizedBox(height: 16),
          _cardRiepilogo(r),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _copiaRiepilogo(r),
            icon: const Icon(Icons.copy),
            label: const Text('Copia riepilogo'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: const StadiumBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Torna alla scheda'),
          ),
          const SizedBox(height: 40),
        ],
      ),
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
  Widget _ultimaVoltaCard(List<StoricoEntry> serie, int serieCorrente, {bool compatta = false, bool aTempo = false}) {
    if (_caricamentoUltimo && !compatta) return const SizedBox.shrink();

    final sfondo = compatta ? coloreChip(context) : coloreSuperficie(context);

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

    StoricoEntry? questa;
    for (final s in serie) {
      if (s.serieNumero == serieCorrente) questa = s;
    }
    final altre = serie.where((s) => s.serieNumero != serieCorrente).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
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
          if (questa != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Serie ${questa.serieNumero}',
                  style: const TextStyle(color: AppColors.accento, fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(width: 12),
                Text(
                  aTempo ? formattaDurata(questa.rep) : '${_numeroBreve(questa.carico)} kg × ${questa.rep}',
                  style: GoogleFonts.oswald(fontSize: 28, fontWeight: FontWeight.w700),
                ),
              ],
            )
          else
            Text(
              'Serie $serieCorrente: non l\'hai fatta l\'ultima volta',
              style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600),
            ),
          if (altre.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                for (final s in altre)
                  Text(
                    aTempo
                        ? 'Serie ${s.serieNumero}: ${formattaDurata(s.rep)}'
                        : 'Serie ${s.serieNumero}: ${_numeroBreve(s.carico)} kg × ${s.rep}',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
              ],
            ),
          ],
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
  final Suggerimento? consiglio;

  const _RegistraSerieSheet({
    required this.caricoIniziale,
    required this.repIniziali,
    this.consiglio,
  });

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
          if (widget.consiglio != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
              decoration: BoxDecoration(
                color: AppColors.accento.withOpacity(0.12),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.accento.withOpacity(0.6)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline, color: AppColors.accento, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.consiglio!.testo,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _caricoKey.currentState?.imposta(widget.consiglio!.carico),
                    child: Text('Usa ${formatKg(widget.consiglio!.carico)}'),
                  ),
                ],
              ),
            ),
          ],
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
