import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:file_picker/file_picker.dart';

import '../data/immagini_esercizi.dart';
import 'selettore_catalogo.dart';
import '../theme/app_theme.dart';

/// Mostra come si esegue l'esercizio alternando due foto (inizio e fine del
/// movimento), come una piccola gif. Se per quel nome non c'è un'immagine
/// mostra [segnaposto].
class AnimazioneEsercizio extends StatefulWidget {
  final String nomeEsercizio;
  final Widget segnaposto;

  /// Se vero, toccando l'immagine si apre a schermo intero.
  final bool ingrandibile;

  const AnimazioneEsercizio({
    super.key,
    required this.nomeEsercizio,
    required this.segnaposto,
    this.ingrandibile = true,
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
    // Se c'è una tua foto/GIF si mostra quella: niente alternanza dei fotogrammi.
    final base = immagineCaricata(widget.nomeEsercizio) != null ? null : immagineEsercizio(widget.nomeEsercizio);
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

  /// Immagine a tutto schermo, con il nome dell'esercizio. Si chiude toccando.
  void _schermoIntero() {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Chiudi',
      barrierColor: Colors.black.withValues(alpha: 0.92),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, _, __) => SafeArea(
        child: GestureDetector(
          onTap: () => Navigator.pop(ctx),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close, color: Colors.white, size: 30),
                    tooltip: 'Chiudi',
                  ),
                ),
                const Spacer(),
                Text(
                  widget.nomeEsercizio,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 16),
                InteractiveViewer(
                  maxScale: 4,
                  child: AnimazioneEsercizio(
                    nomeEsercizio: widget.nomeEsercizio,
                    segnaposto: widget.segnaposto,
                    ingrandibile: false,
                  ),
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () async {
                    final cambiata = await cambiaImmagineEsercizio(ctx, widget.nomeEsercizio);
                    if (!cambiata) return;
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) {
                      setState(_prepara);
                      _precarica();
                    }
                  },
                  icon: const Icon(Icons.swap_horiz, color: Colors.white70),
                  label: const Text(
                    'Immagine sbagliata? Cambiala',
                    style: TextStyle(color: Colors.white70, decoration: TextDecoration.none),
                  ),
                ),
                Text(
                  'Pizzica per ingrandire · tocca per chiudere',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.none,
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
      transitionBuilder: (ctx, animazione, _, figlio) => FadeTransition(
        opacity: animazione,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1).animate(
            CurvedAnimation(parent: animazione, curve: Curves.easeOut),
          ),
          child: figlio,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final caricata = immagineCaricata(widget.nomeEsercizio);
    final percorsi = _percorsi;
    if (caricata == null && percorsi == null) return widget.segnaposto;
    final immagine = caricata != null ? _immagineCaricata(caricata) : _immagine(percorsi!);
    if (!widget.ingrandibile) return immagine;
    return GestureDetector(
      onTap: _schermoIntero,
      child: Stack(
        children: [
          immagine,
          Positioned(
            right: 10,
            bottom: 10,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.open_in_full, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Foto o GIF caricata da te (le GIF si animano da sole).
  Widget _immagineCaricata(Uint8List dati) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: AspectRatio(
            aspectRatio: 3 / 2,
            child: Container(
              color: coloreCard(context),
              child: Image.memory(
                dati,
                fit: BoxFit.contain,
                width: double.infinity,
                height: double.infinity,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => widget.segnaposto,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _immagine(List<String> percorsi) {
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
    final caricata = immagineCaricata(nomeEsercizio);
    final base = caricata != null ? null : immagineEsercizio(nomeEsercizio);
    final icona = Icon(
      aTempo ? Icons.timer_outlined : Icons.fitness_center,
      color: AppColors.accento,
      size: dimensione * 0.45,
    );
    final immagine = ClipRRect(
      borderRadius: BorderRadius.circular(dimensione * 0.28),
      child: Container(
        width: dimensione,
        height: dimensione,
        color: caricata != null ? fondo : (base == null ? fondo : Colors.white),
        alignment: Alignment.center,
        child: caricata != null
            ? Image.memory(
                caricata,
                width: dimensione,
                height: dimensione,
                fit: BoxFit.cover,
                cacheWidth: (dimensione * 3).round(),
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => icona,
              )
            : base == null
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
                color: AppColors.accento,
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


/// Fa scegliere l'immagine giusta per un esercizio: dal catalogo, nessuna,
/// oppure di nuovo quella automatica. Vero se è cambiato qualcosa.
Future<bool> cambiaImmagineEsercizio(BuildContext context, String nomeEsercizio) async {
  final azione = await showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add_photo_alternate_outlined),
              title: const Text('Carica una tua foto o GIF'),
              subtitle: const Text('Dalla galleria: anche un video convertito in GIF'),
              onTap: () => Navigator.pop(ctx, 'carica'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Scegli dal catalogo'),
              subtitle: const Text('Cerca l\'esercizio con il movimento giusto'),
              onTap: () => Navigator.pop(ctx, 'catalogo'),
            ),
            ListTile(
              leading: const Icon(Icons.hide_image_outlined),
              title: const Text('Nessuna immagine'),
              onTap: () => Navigator.pop(ctx, 'nessuna'),
            ),
            if (immagineSceltaAMano(nomeEsercizio))
              ListTile(
                leading: const Icon(Icons.auto_fix_high),
                title: const Text('Torna a quella automatica'),
                onTap: () => Navigator.pop(ctx, 'automatica'),
              ),
          ],
        ),
      ),
    ),
  );
  if (azione == null || !context.mounted) return false;
  if (azione == 'nessuna') {
    await scegliImmagine(nomeEsercizio, null);
    return true;
  }
  if (azione == 'automatica') {
    await ripristinaImmagine(nomeEsercizio);
    return true;
  }
  if (azione == 'carica') return _caricaDaGalleria(context, nomeEsercizio);
  final scelto = await mostraCatalogoEsercizi(context);
  if (scelto == null || !context.mounted) return false;
  final base = immagineDelCatalogo(scelto.nome);
  if (base == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('"${scelto.nome}" non ha un\'immagine: scegline un altro')),
    );
    return false;
  }
  await scegliImmagine(nomeEsercizio, base);
  return true;
}


/// Dimensione massima di una foto/GIF caricata (resta nel database dell'app).
const int _maxByteImmagine = 8 * 1024 * 1024;

/// Fa scegliere una foto o una GIF dalla galleria e la salva per l'esercizio.
Future<bool> _caricaDaGalleria(BuildContext context, String nomeEsercizio) async {
  final risultato = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
  if (risultato == null || risultato.files.isEmpty || !context.mounted) return false;
  final file = risultato.files.single;
  final dati = file.bytes;
  if (dati == null || dati.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Non riesco a leggere il file: riprova con un\'altra immagine')),
    );
    return false;
  }
  if (dati.length > _maxByteImmagine) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('File troppo grande (massimo 8 MB): prova una GIF più corta o più piccola')),
    );
    return false;
  }
  final estensione = (file.extension ?? '').toLowerCase();
  final tipo = estensione == 'gif' ? 'image/gif' : (estensione == 'png' ? 'image/png' : 'image/jpeg');
  await caricaImmagine(nomeEsercizio, dati, tipo);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Immagine salvata per "$nomeEsercizio"')),
    );
  }
  return true;
}
