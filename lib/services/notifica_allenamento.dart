import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Notifica fissa dell'allenamento in corso (con servizio in primo piano, così
/// il cronometro del riposo continua anche a schermo spento). Android la
/// inoltra anche allo smartwatch collegato.
///
/// Ogni chiamata è protetta: se qualcosa non funziona (permesso negato,
/// configurazione mancante) l'allenamento prosegue normalmente, senza notifica.
class NotificaAllenamento {
  NotificaAllenamento._();

  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _inizializzato = false;
  static bool _servizioAttivo = false;

  static const int _id = 4242;
  static const String azioneSaltaRiposo = 'salta_riposo';

  /// Chiamata quando si tocca un pulsante della notifica.
  static void Function(String azione)? onAzione;

  static AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  static Future<void> _inizializza() async {
    if (_inizializzato) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_gym'),
      ),
      onDidReceiveNotificationResponse: (risposta) {
        final azione = risposta.actionId;
        if (azione != null && azione.isNotEmpty) onAzione?.call(azione);
      },
    );
    await _android?.requestNotificationsPermission();
    _inizializzato = true;
  }

  static AndroidNotificationDetails _dettagli({DateTime? finoA, bool saltabile = false}) {
    return AndroidNotificationDetails(
      'gymapp_allenamento',
      'Allenamento in corso',
      channelDescription: 'Mostra la scheda in esecuzione e il timer del riposo',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: true,
      playSound: false,
      enableVibration: false,
      visibility: NotificationVisibility.public,
      icon: 'ic_stat_gym',
      color: const Color(0xFF39FF14),
      showWhen: finoA != null,
      usesChronometer: finoA != null,
      chronometerCountDown: finoA != null,
      when: finoA?.millisecondsSinceEpoch,
      actions: saltabile
          ? const <AndroidNotificationAction>[
              AndroidNotificationAction(
                azioneSaltaRiposo,
                'Salta riposo',
                showsUserInterface: true,
                cancelNotification: false,
              ),
            ]
          : null,
    );
  }

  /// Mostra o aggiorna la notifica. [finoA] attiva il conto alla rovescia.
  static Future<void> aggiorna({
    required String titolo,
    required String testo,
    DateTime? finoA,
    bool saltabile = false,
  }) async {
    try {
      await _inizializza();
      final dettagli = _dettagli(finoA: finoA, saltabile: saltabile);
      if (!_servizioAttivo) {
        _servizioAttivo = true;
        await _android?.startForegroundService(
          _id,
          titolo,
          testo,
          notificationDetails: dettagli,
          startType: AndroidServiceStartType.startNotSticky,
        );
      } else {
        await _plugin.show(
          id: _id,
          title: titolo,
          body: testo,
          notificationDetails: NotificationDetails(android: dettagli),
        );
      }
    } catch (e) {
      _servizioAttivo = false;
      debugPrint('Notifica allenamento non disponibile: $e');
    }
  }

  /// Toglie la notifica e ferma il servizio.
  static Future<void> chiudi() async {
    if (!_servizioAttivo) return;
    _servizioAttivo = false;
    try {
      await _android?.stopForegroundService();
      await _android?.cancel(_id);
    } catch (e) {
      debugPrint('Chiusura notifica: $e');
    }
  }
}
