import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../db/database_helper.dart';
import 'notifica_allenamento.dart';

/// Impostazioni dei promemoria: giorni della settimana (1 = lunedì) e orario.
class ImpostazioniPromemoria {
  final Set<int> giorni;
  final TimeOfDay ora;

  /// Notifica della domenica sera con l'invito a guardare progressi e coach.
  final bool riepilogo;
  const ImpostazioniPromemoria(this.giorni, this.ora, {this.riepilogo = false});

  bool get attivi => giorni.isNotEmpty || riepilogo;
}

/// Promemoria settimanali di allenamento ("Oggi tocca a LEGS") nei giorni e
/// all'ora scelti. Si ripetono ogni settimana; il testo con la scheda da fare
/// si aggiorna ogni volta che apri l'app.
class Promemoria {
  Promemoria._();

  static const _chiaveGiorni = 'promemoria_giorni';
  static const _chiaveOra = 'promemoria_ora';
  static const _chiaveRiepilogo = 'riepilogo_domenica';
  static const _idRiepilogo = 7100;
  static const _idBase = 7000; // 7001..7007, uno per giorno della settimana
  static bool _fusoPronto = false;

  static Future<ImpostazioniPromemoria> carica() async {
    final prefs = await SharedPreferences.getInstance();
    final giorni = (prefs.getStringList(_chiaveGiorni) ?? const <String>[])
        .map(int.tryParse)
        .whereType<int>()
        .where((g) => g >= 1 && g <= 7)
        .toSet();
    final testoOra = prefs.getString(_chiaveOra) ?? '18:00';
    final parti = testoOra.split(':');
    final ora = TimeOfDay(
      hour: int.tryParse(parti.first) ?? 18,
      minute: parti.length > 1 ? (int.tryParse(parti[1]) ?? 0) : 0,
    );
    return ImpostazioniPromemoria(giorni, ora, riepilogo: prefs.getBool(_chiaveRiepilogo) ?? false);
  }

  static Future<void> salva(ImpostazioniPromemoria imp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_chiaveGiorni, [for (final g in imp.giorni) '$g']);
    final h = imp.ora.hour.toString().padLeft(2, '0');
    final m = imp.ora.minute.toString().padLeft(2, '0');
    await prefs.setString(_chiaveOra, '$h:$m');
    await prefs.setBool(_chiaveRiepilogo, imp.riepilogo);
    await ripianifica();
  }

  /// Fuso orario locale: si cerca quello con lo stesso scarto da UTC del
  /// telefono, preferendo Europe/Rome.
  static void _preparaFuso() {
    if (_fusoPronto) return;
    tzdata.initializeTimeZones();
    final scarto = DateTime.now().timeZoneOffset;
    tz.Location? scelto;
    try {
      final roma = tz.getLocation('Europe/Rome');
      if (tz.TZDateTime.now(roma).timeZoneOffset == scarto) scelto = roma;
    } catch (_) {
      scelto = null;
    }
    if (scelto == null) {
      for (final l in tz.timeZoneDatabase.locations.values) {
        if (tz.TZDateTime.now(l).timeZoneOffset == scarto) {
          scelto = l;
          break;
        }
      }
    }
    tz.setLocalLocation(scelto ?? tz.UTC);
    _fusoPronto = true;
  }

  /// Prossima occorrenza del giorno [giorno] (1 = lunedì) all'ora indicata.
  static tz.TZDateTime _prossima(int giorno, TimeOfDay ora) {
    final adesso = tz.TZDateTime.now(tz.local);
    for (var k = 0; k <= 7; k++) {
      final d = tz.TZDateTime(tz.local, adesso.year, adesso.month, adesso.day + k, ora.hour, ora.minute);
      if (d.weekday == giorno && d.isAfter(adesso)) return d;
    }
    return tz.TZDateTime(tz.local, adesso.year, adesso.month, adesso.day + 7, ora.hour, ora.minute);
  }

  /// La scheda che tocca (quella dopo l'ultima fatta, nel tuo ordine).
  static Future<String?> _prossimaScheda() async {
    final db = DatabaseHelper.instance;
    final schede = await db.getSchede();
    final conteggi = await db.contaEserciziPerScheda();
    final ultime = await db.getUltimaSessionePerScheda();
    final valide = schede.where((s) => s.id != null && (conteggi[s.id] ?? 0) > 0).toList();
    if (valide.isEmpty) return null;
    var indice = -1;
    DateTime? recente;
    for (var i = 0; i < valide.length; i++) {
      final d = ultime[valide[i].id];
      if (d != null && (recente == null || d.isAfter(recente))) {
        recente = d;
        indice = i;
      }
    }
    return valide[(indice + 1) % valide.length].nome;
  }

  /// Cancella e ripianifica tutti i promemoria in base alle impostazioni.
  /// Non fa nulla (e non chiede permessi) se i promemoria sono spenti.
  static Future<void> ripianifica() async {
    try {
      final imp = await carica();
      final prefs = await SharedPreferences.getInstance();
      final eranoAttivi = prefs.getBool('promemoria_pianificati') ?? false;
      if (!imp.attivi && !eranoAttivi) return;

      final plugin = await NotificaAllenamento.plugin();
      for (var g = 1; g <= 7; g++) {
        await plugin.cancel(id: _idBase + g);
      }
      await plugin.cancel(id: _idRiepilogo);
      await prefs.setBool('promemoria_pianificati', imp.attivi);
      if (!imp.attivi) return;

      _preparaFuso();
      final scheda = await _prossimaScheda();
      final testo = scheda == null
          ? 'È il momento di allenarti: scegli la scheda e parti!'
          : 'Oggi tocca a $scheda. Apri Gymapp e parti!';
      const dettagli = NotificationDetails(
        android: AndroidNotificationDetails(
          'gymapp_promemoria',
          'Promemoria allenamento',
          channelDescription: 'Ti ricorda di allenarti nei giorni scelti',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: 'ic_stat_gym',
          color: Color(0xFF39FF14),
        ),
      );
      for (final g in imp.giorni) {
        await plugin.zonedSchedule(
          id: _idBase + g,
          title: 'Giorno di allenamento 💪',
          body: testo,
          scheduledDate: _prossima(g, imp.ora),
          notificationDetails: dettagli,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      }
      if (imp.riepilogo) {
        await plugin.zonedSchedule(
          id: _idRiepilogo,
          title: 'Com\'è andata la settimana?',
          body: 'Il coach ha guardato i tuoi allenamenti: progressi, stalli e consigli per la prossima.',
          scheduledDate: _prossima(DateTime.sunday, const TimeOfDay(hour: 19, minute: 0)),
          notificationDetails: dettagli,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      }
    } catch (e) {
      debugPrint('Promemoria non pianificati: $e');
    }
  }
}
