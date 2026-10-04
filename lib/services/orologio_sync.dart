import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:watch_connectivity/watch_connectivity.dart';

/// Collegamento telefono -> orologio (Wear OS): manda lo stato dell'allenamento
/// e riceve i comandi premuti sull'orologio. Se non c'è nessun orologio
/// collegato non fa nulla.
class OrologioSync {
  OrologioSync._();

  static final WatchConnectivity _watch = WatchConnectivity();
  static StreamSubscription<Map<String, dynamic>>? _sub;

  /// Chiamata quando dall'orologio arriva un comando (es. "salta_riposo", "vai").
  static void Function(String azione)? onAzione;

  /// Comincia ad ascoltare i comandi dell'orologio.
  static void avvia() {
    if (_sub != null) return;
    try {
      _sub = _watch.messageStream.listen(
        (messaggio) {
          final azione = messaggio['azione'];
          if (azione is String) onAzione?.call(azione);
        },
        onError: (Object e) => debugPrint('Orologio: $e'),
      );
    } catch (e) {
      debugPrint('Orologio non disponibile: $e');
    }
  }

  /// Invia lo stato dell'allenamento all'orologio.
  static Future<void> invia(Map<String, dynamic> stato) async {
    try {
      final dati = <String, dynamic>{...stato, 'ts': DateTime.now().millisecondsSinceEpoch};
      if (!await _watch.isReachable) {
        // Nessun orologio raggiungibile adesso: lascia comunque l'ultimo stato
        // salvato, così lo trova quando si ricollega.
        await _watch.updateApplicationContext(dati);
        return;
      }
      await _watch.sendMessage(dati);
      await _watch.updateApplicationContext(dati);
    } catch (e) {
      debugPrint('Orologio: invio non riuscito: $e');
    }
  }
}
