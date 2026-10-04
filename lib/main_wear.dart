import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import 'package:watch_connectivity/watch_connectivity.dart';

/// App per smartwatch Wear OS: mostra l'allenamento che sta andando sul
/// telefono (esercizio, serie, countdown) e permette "Vai" e "Salta riposo".
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
    ts: 0,
  );

  factory _Stato.da(Map<String, dynamic> m) {
    int intero(dynamic v) => v is num ? v.toInt() : 0;
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
    });
    if (_fine != null && !_ticker.isActive) {
      _ticker.start();
    } else if (_fine == null && _ticker.isActive) {
      _ticker.stop();
    }
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

  Future<void> _invia(String azione) async {
    HapticFeedback.mediumImpact();
    try {
      await _watch.sendMessage({'azione': azione});
    } catch (_) {}
  }

  String _orologio(int secondi) {
    final m = secondi ~/ 60;
    final s = (secondi % 60).toString().padLeft(2, '0');
    return '$m:$s';
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

  Widget _schermataVuota(double lato) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.asset('assets/logo.png', width: lato * 0.34, height: lato * 0.34, fit: BoxFit.cover),
        ),
        const SizedBox(height: 8),
        const Text(
          'GYMAPP',
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
              _pulsante('SALTA', Icons.skip_next, () => _invia('salta_riposo')),
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(s.titolo, textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, height: 1.15)),
            const SizedBox(height: 6),
            Text(s.testo, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _lime, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text('Finisci la serie\nsul telefono', textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 10)),
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
            if (s.vai) _pulsante('VAI', Icons.play_arrow, () => _invia('vai')),
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
            child: _contenuto(lato - margine * 2),
          );
        },
      ),
    );
  }
}
