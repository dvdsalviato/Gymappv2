import 'dart:async';

import 'package:flutter/material.dart';

import '../data/immagini_esercizi.dart';

/// Mostra come si esegue l'esercizio alternando due foto (inizio e fine del
/// movimento), come una piccola gif. Se per quel nome non c'è un'immagine
/// mostra [segnaposto].
class AnimazioneEsercizio extends StatefulWidget {
  final String nomeEsercizio;
  final Widget segnaposto;

  const AnimazioneEsercizio({
    super.key,
    required this.nomeEsercizio,
    required this.segnaposto,
  });

  @override
  State<AnimazioneEsercizio> createState() => _AnimazioneEsercizioState();
}

class _AnimazioneEsercizioState extends State<AnimazioneEsercizio> {
  Timer? _timer;
  int _fotogramma = 0;
  List<String>? _percorsi;

  @override
  void initState() {
    super.initState();
    _prepara();
  }

  @override
  void didUpdateWidget(covariant AnimazioneEsercizio oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nomeEsercizio != widget.nomeEsercizio) {
      _prepara();
      _precarica();
    }
  }

  void _prepara() {
    _timer?.cancel();
    _fotogramma = 0;
    final base = immagineEsercizio(widget.nomeEsercizio);
    _percorsi = base == null ? null : fotogrammiEsercizio(base);
    if (_percorsi != null) {
      _timer = Timer.periodic(const Duration(milliseconds: 1100), (_) {
        if (mounted) setState(() => _fotogramma = 1 - _fotogramma);
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _precarica();
  }

  /// Carica in anticipo entrambi i fotogrammi per evitare lampeggi.
  void _precarica() {
    final percorsi = _percorsi;
    if (percorsi != null) {
      for (final p in percorsi) {
        precacheImage(AssetImage(p), context);
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final percorsi = _percorsi;
    if (percorsi == null) return widget.segnaposto;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: AspectRatio(
            aspectRatio: 3 / 2,
            child: Container(
              color: Colors.white,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Image.asset(
                  percorsi[_fotogramma],
                  key: ValueKey(percorsi[_fotogramma]),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  gaplessPlayback: true,
                  errorBuilder: (_, __, ___) => widget.segnaposto,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Miniatura quadrata dell'esercizio (primo fotogramma), per le liste.
/// Senza immagine mostra un'icona sul colore delle chip. Se [numero] è
/// indicato compare in un piccolo bollino nell'angolo.
class MiniaturaEsercizio extends StatelessWidget {
  final String nomeEsercizio;
  final double dimensione;
  final int? numero;
  final bool aTempo;

  const MiniaturaEsercizio({
    super.key,
    required this.nomeEsercizio,
    this.dimensione = 52,
    this.numero,
    this.aTempo = false,
  });

  @override
  Widget build(BuildContext context) {
    final scuro = Theme.of(context).brightness == Brightness.dark;
    final fondo = scuro ? const Color(0xFF212126) : const Color(0xFFEDEDF0);
    final base = immagineEsercizio(nomeEsercizio);
    final icona = Icon(
      aTempo ? Icons.timer_outlined : Icons.fitness_center,
      color: const Color(0xFF39FF14),
      size: dimensione * 0.45,
    );
    final immagine = ClipRRect(
      borderRadius: BorderRadius.circular(dimensione * 0.28),
      child: Container(
        width: dimensione,
        height: dimensione,
        color: base == null ? fondo : Colors.white,
        alignment: Alignment.center,
        child: base == null
            ? icona
            : Image.asset(
                fotogrammiEsercizio(base).first,
                width: dimensione,
                height: dimensione,
                fit: BoxFit.cover,
                cacheWidth: (dimensione * 3).round(),
                errorBuilder: (_, __, ___) => icona,
              ),
      ),
    );
    if (numero == null) return immagine;
    return SizedBox(
      width: dimensione + 4,
      height: dimensione + 4,
      child: Stack(
        children: [
          Positioned(left: 0, bottom: 0, child: immagine),
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              constraints: const BoxConstraints(minWidth: 20),
              height: 20,
              padding: const EdgeInsets.symmetric(horizontal: 5),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF39FF14),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: scuro ? const Color(0xFF151519) : Colors.white, width: 2),
              ),
              child: Text(
                '$numero',
                style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w800, height: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
