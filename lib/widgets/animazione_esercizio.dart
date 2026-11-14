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
