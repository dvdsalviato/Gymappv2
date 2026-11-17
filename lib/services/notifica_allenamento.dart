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

  static int _limita(int v, int massimo) => v < 0 ? 0 : (v > massimo ? massimo : v);

  static AndroidNotificationDetails _dettagli({
    DateTime? finoA,
    bool saltabile = false,
    int? progresso,
    int? totale,
  }) {
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
      // Barra di avanzamento (come il brano su Spotify) durante riposo ed
      // esercizi a tempo.
      showProgress: totale != null && totale > 0,
      maxProgress: totale ?? 0,
      progress: _limita(progresso ?? 0, totale ?? 0),
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

  /// Plugin pronto all'uso (inizializzato una sola volta per tutta l'app, così
  /// i pulsanti della notifica dell'allenamento continuano a funzionare).
  static Future<FlutterLocalNotificationsPlugin> plugin() async {
    await _inizializza();
    return _plugin;
  }

  /// Mostra o aggiorna la notifica. [finoA] attiva il conto alla rovescia,
  /// [progresso] su [totale] (secondi) disegna la barra di avanzamento.
  static Future<void> aggiorna({
    required String titolo,
    required String testo,
    DateTime? finoA,
    bool saltabile = false,
    int? progresso,
    int? totale,
  }) async {
    try {
      await _inizializza();
      final dettagli = _dettagli(finoA: finoA, saltabile: saltabile, progresso: progresso, totale: totale);
      if (!_servizioAttivo) {
        _servizioAttivo = true;
        await _android?.startForegroundService(
          id: _id,
          title: titolo,
          body: testo,
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
      await _android?.cancel(id: _id);
    } catch (e) {
      debugPrint('Chiusura notifica: $e');
    }
  }
}
