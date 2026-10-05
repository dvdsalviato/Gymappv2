import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:watch_connectivity/watch_connectivity.dart';

/// App per smartwatch Wear OS: mostra l'allenamento che sta andando sul
/// telefono (esercizio, serie, countdown) e permette "Vai", "Salta riposo" e
/// di registrare la serie con carico e ripetizioni.
/// Si compila con: flutter build apk --release --target lib/main_wear.dart
const Color _lime = Color(0xFF39FF14);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const OrologioApp());
}

class OrologioApp extends StatelessWidget {
  const OrologioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gymapp',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _lime,
          brightness: Brightness.dark,
          primary: _lime,
          onPrimary: Colors.black,
        ),
      ),
      home: const OrologioHome(),
    );
  }
}

class _Stato {
  final bool attivo;
  final String fase;
  final String titolo;
  final String testo;
  final int restMs;
  final int totaleMs;
  final bool saltabile;
  final bool vai;
  final bool registra;
  final double carico;
  final int rep;
  final double consiglio;
  final int ts;

  const _Stato({
    required this.attivo,
    required this.fase,
    required this.titolo,
    required this.testo,
    required this.restMs,
    required this.totaleMs,
    required this.saltabile,
    required this.vai,
    required this.registra,
    required this.carico,
    required this.rep,
    required this.consiglio,
    required this.ts,
  });

  static const vuoto = _Stato(
    attivo: false,
    fase: '',
    titolo: '',
    testo: '',
    restMs: 0,
    totaleMs: 0,
    saltabile: false,
    vai: false,
    registra: false,
    carico: 0,
    rep: 0,
    consiglio: 0,
    ts: 0,
  );

  factory _Stato.da(Map<String, dynamic> m) {
    int intero(dynamic v) => v is num ? v.toInt() : 0;
    double decimale(dynamic v) => v is num ? v.toDouble() : 0.0;
    String testo(dynamic v) => v is String ? v : '';
    return _Stato(
      attivo: m['attivo'] == true,
      fase: testo(m['fase']),
      titolo: testo(m['titolo']),
      testo: testo(m['testo']),
      restMs: intero(m['restMs']),
      totaleMs: intero(m['totaleMs']),
      saltabile: m['saltabile'] == true,
      vai: m['vai'] == true,
      registra: m['registra'] == true,
      carico: decimale(m['carico']),
      rep: intero(m['rep']),
      consiglio: decimale(m['consiglio']),
      ts: intero(m['ts']),
    );
  }
}

class OrologioHome extends StatefulWidget {
  const OrologioHome({super.key});

  @override
  State<OrologioHome> createState() => _OrologioHomeState();
}

class _OrologioHomeState extends State<OrologioHome> with SingleTickerProviderStateMixin {
  final WatchConnectivity _watch = WatchConnectivity();
  StreamSubscription<Map<String, dynamic>>? _subMessaggi;
  StreamSubscription<Map<String, dynamic>>? _subContesto;
  late final Ticker _ticker;

  _Stato _stato = _Stato.vuoto;
  DateTime? _fine;
  int _totaleMs = 0;
  bool _fineSegnalata = false;
  int _tsApplicato = 0;
  bool _schermoAcceso = false;

  // Editor di carico e ripetizioni
  bool _modificando = false;
  double _carico = 0;
  int _rep = 10;
  int _iPasso = 0;
  static const List<double> _passi = [2.5, 1.0, 0.5, 5.0];

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _subMessaggi = _watch.messageStream.listen((m) => _applica(m));
    _subContesto = _watch.contextStream.listen((m) => _applica(m, daContesto: true));
    _ripristina();
  }

  @override
  void dispose() {
    _subMessaggi?.cancel();
    _subContesto?.cancel();
    _ticker.dispose();
    if (_schermoAcceso) WakelockPlus.disable();
    super.dispose();
  }

  /// All'apertura recupera l'ultimo stato mandato dal telefono.
  Future<void> _ripristina() async {
    try {
      final contesti = await _watch.receivedApplicationContexts;
      Map<String, dynamic>? ultimo;
      var tsMax = -1;
      for (final c in contesti) {
        final t = c['ts'];
        final ts = t is num ? t.toInt() : 0;
        if (ts > tsMax) {
          tsMax = ts;
          ultimo = c;
        }
      }
      if (ultimo != null && mounted) _applica(ultimo, daContesto: true);
    } catch (_) {}
  }

  void _applica(Map<String, dynamic> m, {bool daContesto = false}) {
    if (!mounted) return;
    final nuovo = _Stato.da(m);
    if (daContesto) {
      if (nuovo.ts <= _tsApplicato) return;
    } else if (nuovo.ts != 0 && nuovo.ts < _tsApplicato) {
      return;
    }
    var rest = nuovo.restMs;
    if (daContesto && nuovo.ts > 0) {
      final trascorsi = DateTime.now().millisecondsSinceEpoch - nuovo.ts;
      if (trascorsi > 0 && trascorsi < 6 * 3600 * 1000) rest -= trascorsi;
    }
    _tsApplicato = nuovo.ts;
    setState(() {
      _stato = nuovo;
      _fineSegnalata = false;
      _totaleMs = nuovo.totaleMs;
      _fine = (nuovo.attivo && nuovo.totaleMs > 0 && rest > 0)
          ? DateTime.now().add(Duration(milliseconds: rest))
          : null;
      if (!nuovo.attivo || nuovo.fase != 'inCorso') _modificando = false;
    });
    if (_fine != null && !_ticker.isActive) {
      _ticker.start();
    } else if (_fine == null && _ticker.isActive) {
      _ticker.stop();
    }
    _aggiornaSchermo(nuovo.attivo);
  }

  /// Durante l'allenamento lo schermo resta acceso, così l'app non si chiude
  /// quando l'orologio andrebbe in standby.
  void _aggiornaSchermo(bool attivo) {
    if (attivo == _schermoAcceso) return;
    _schermoAcceso = attivo;
    try {
      if (attivo) {
        WakelockPlus.enable();
      } else {
        WakelockPlus.disable();
      }
    } catch (_) {}
  }

  int get _restanteMs {
    final f = _fine;
    if (f == null) return 0;
    final ms = f.difference(DateTime.now()).inMilliseconds;
    return ms < 0 ? 0 : ms;
  }

  void _onTick(Duration _) {
    final f = _fine;
    if (f == null) return;
    if (!_fineSegnalata && !DateTime.now().isBefore(f)) {
      _fineSegnalata = true;
      Vibration.hasVibrator().then((ok) {
        if (ok == true) Vibration.vibrate(duration: 500);
      });
      if (_ticker.isActive) _ticker.stop();
    }
    if (mounted) setState(() {});
  }

  Future<void> _invia(Map<String, dynamic> messaggio) async {
    HapticFeedback.mediumImpact();
    try {
      await _watch.sendMessage(messaggio);
    } catch (_) {}
  }

  void _apriEditor() {
    setState(() {
      _carico = _stato.carico;
      _rep = _stato.rep > 0 ? _stato.rep : 10;
      _modificando = true;
    });
  }

  void _confermaSerie() {
    _invia({'azione': 'registra', 'carico': _carico, 'rep': _rep});
    setState(() => _modificando = false);
  }

  String _orologio(int secondi) {
    final m = secondi ~/ 60;
    final s = (secondi % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _kg(double v) {
    final t = v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
    return t.replaceAll('.', ',');
  }

  Widget _pulsante(String testo, IconData icona, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 40,
      child: FilledButton.icon(
        onPressed: onTap,
        icon: Icon(icona, size: 18),
        label: Text(testo),
        style: FilledButton.styleFrom(
          backgroundColor: _lime,
          foregroundColor: Colors.black,
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Widget _anello(double d) {
    final tot = _totaleMs <= 0 ? 1 : _totaleMs;
    final progresso = (_restanteMs / tot).clamp(0.0, 1.0).toDouble();
    final secondi = (_restanteMs / 1000).ceil();
    return SizedBox(
      width: d,
      height: d,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: progresso,
              strokeWidth: 7,
              strokeCap: StrokeCap.round,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation(_lime),
            ),
          ),
          Text(
            _orologio(secondi),
            style: TextStyle(fontSize: d * 0.26, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _conAnello() {
    return LayoutBuilder(
      builder: (context, box) {
        final d = math.min(box.maxWidth, box.maxHeight);
        return Center(child: _anello(d));
      },
    );
  }

  Widget _tondo(IconData icona, VoidCallback onTap) {
    return SizedBox(
      width: 34,
      height: 34,
      child: IconButton.filledTonal(
        padding: EdgeInsets.zero,
        iconSize: 18,
        onPressed: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        icon: Icon(icona),
      ),
    );
  }

  Widget _rigaStepper({
    required String etichetta,
    required String valore,
    required VoidCallback meno,
    required VoidCallback piu,
    VoidCallback? sulValore,
  }) {
    return SizedBox(
      height: 42,
      child: Row(
        children: [
          _tondo(Icons.remove, meno),
          Expanded(
            child: GestureDetector(
              onTap: sulValore,
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(valore, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, height: 1.0)),
                  Text(etichetta, style: const TextStyle(fontSize: 9, color: Colors.grey, height: 1.2)),
                ],
              ),
            ),
          ),
          _tondo(Icons.add, piu),
        ],
      ),
    );
  }

  Widget _editor() {
    final passo = _passi[_iPasso];
    final consiglio = _stato.consiglio;
    return Column(
      children: [
        _rigaStepper(
          etichetta: 'KG  ±${_kg(passo)}',
          valore: _kg(_carico),
          meno: () => setState(() => _carico = math.max(0, _carico - passo)),
          piu: () => setState(() => _carico = _carico + passo),
          sulValore: () => setState(() => _iPasso = (_iPasso + 1) % _passi.length),
        ),
        if (consiglio > 0 && consiglio != _carico)
          GestureDetector(
            onTap: () => setState(() => _carico = consiglio),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                'Consigliato ${_kg(consiglio)}  ›',
                style: const TextStyle(color: _lime, fontSize: 10, fontWeight: FontWeight.w700),
              ),
            ),
          )
        else
          const SizedBox(height: 6),
        _rigaStepper(
          etichetta: 'REPS',
          valore: '$_rep',
          meno: () => setState(() => _rep = math.max(0, _rep - 1)),
          piu: () => setState(() => _rep = _rep + 1),
        ),
        const Spacer(),
        _pulsante('FATTO', Icons.check, _confermaSerie),
      ],
    );
  }

  Widget _schermataVuota(double lato) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.asset('assets/logo.png', width: lato * 0.34, height: lato * 0.34, fit: BoxFit.cover),
        ),
        const SizedBox(height: 8),
        const Text(
          'GYMAPP',
          textAlign: TextAlign.center,
          style: TextStyle(color: _lime, fontWeight: FontWeight.w800, letterSpacing: 2, fontSize: 15),
        ),
        const SizedBox(height: 4),
        const Text(
          'Avvia un allenamento\nsul telefono',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 11),
        ),
      ],
    );
  }

  Widget _contenuto(double lato) {
    final s = _stato;
    if (!s.attivo) return _schermataVuota(lato);
    if (_modificando) return _editor();

    switch (s.fase) {
      case 'pausa':
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.pause_circle_outline, color: _lime, size: 40),
            const SizedBox(height: 6),
            const Text('IN PAUSA', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.5)),
            const SizedBox(height: 4),
            Text(s.testo, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.grey, fontSize: 11)),
          ],
        );
      case 'riposo':
        return Column(
          children: [
            const Text('RIPOSO', style: TextStyle(color: _lime, fontWeight: FontWeight.w800, letterSpacing: 1.5, fontSize: 12)),
            const SizedBox(height: 4),
            Expanded(child: _conAnello()),
            const SizedBox(height: 4),
            Text(s.testo, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.grey, fontSize: 10)),
            if (s.saltabile) ...[
              const SizedBox(height: 6),
              _pulsante('SALTA', Icons.skip_next, () => _invia({'azione': 'salta_riposo'})),
            ],
          ],
        );
      case 'inCorso':
        if (s.totaleMs > 0) {
          return Column(
            children: [
              Text(s.titolo, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 4),
              Expanded(child: _conAnello()),
              const SizedBox(height: 4),
              Text(s.testo, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.grey, fontSize: 10)),
            ],
          );
        }
        return Column(
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(s.titolo, textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, height: 1.15)),
                    const SizedBox(height: 6),
                    Text(s.testo, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _lime, fontSize: 11, fontWeight: FontWeight.w600)),
                    if (s.consiglio > 0) ...[
                      const SizedBox(height: 4),
                      Text('Consigliato ${_kg(s.consiglio)} kg',
                          style: const TextStyle(color: Colors.grey, fontSize: 10)),
                    ],
                  ],
                ),
              ),
            ),
            if (s.registra) _pulsante('FINE SERIE', Icons.check, _apriEditor),
          ],
        );
      default: // pronto
        return Column(
          children: [
            Text(s.titolo, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.grey, fontSize: 11)),
            Expanded(
              child: Center(
                child: Text(s.testo, textAlign: TextAlign.center, maxLines: 4, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, height: 1.2)),
              ),
            ),
            if (s.vai) _pulsante('VAI', Icons.play_arrow, () => _invia({'azione': 'vai'})),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, c) {
          final lato = math.min(c.maxWidth, c.maxHeight);
          final margine = lato * 0.13;
          return Padding(
            padding: EdgeInsets.all(margine),
            // SizedBox.expand: il contenuto occupa tutto lo spazio e resta centrato.
            child: SizedBox.expand(child: _contenuto(lato - margine * 2)),
          );
        },
      ),
    );
  }
}
