import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum StileAzione { primaria, secondaria, pericolo }

class AzioneDialogo<T> {
  final String etichetta;
  final IconData icona;
  final T valore;
  final StileAzione stile;

  const AzioneDialogo(this.etichetta, this.icona, this.valore, {this.stile = StileAzione.secondaria});
}

/// Dialogo con pulsanti tutti uguali (stessa altezza e stessa forma a pillola),
/// uno sotto l'altro: cambia solo il colore in base all'importanza.
Future<T?> mostraDialogoAzioni<T>(
  BuildContext context, {
  required String titolo,
  String? messaggio,
  required List<AzioneDialogo<T>> azioni,
  bool chiudibile = false,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: chiudibile,
    builder: (ctx) {
      final forma = const StadiumBorder();
      Widget bottone(AzioneDialogo<T> a) {
        final onPressed = () => Navigator.pop(ctx, a.valore);
        final contenuto = Text(a.etichetta, textAlign: TextAlign.center);
        late final Widget b;
        switch (a.stile) {
          case StileAzione.primaria:
            b = FilledButton.icon(
              onPressed: onPressed,
              icon: Icon(a.icona),
              label: contenuto,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), shape: forma),
            );
            break;
          case StileAzione.pericolo:
            b = OutlinedButton.icon(
              onPressed: onPressed,
              icon: Icon(a.icona),
              label: contenuto,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: forma,
                foregroundColor: Colors.redAccent,
                side: BorderSide(color: Colors.redAccent.withOpacity(0.7)),
              ),
            );
            break;
          case StileAzione.secondaria:
            b = OutlinedButton.icon(
              onPressed: onPressed,
              icon: Icon(a.icona),
              label: contenuto,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: forma,
                side: BorderSide(color: Colors.white.withOpacity(0.25)),
              ),
            );
            break;
        }
        return Padding(padding: const EdgeInsets.only(bottom: 10), child: SizedBox(width: double.infinity, child: b));
      }

      return AlertDialog(
        title: Text(titolo),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (messaggio != null) ...[
                Text(messaggio, style: TextStyle(color: Colors.grey.shade400, height: 1.35)),
                const SizedBox(height: 18),
              ],
              for (final a in azioni) bottone(a),
            ],
          ),
        ),
      );
    },
  );
}
