import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'notifica_allenamento.dart';

/// Numero della build installata: lo scrive GitHub Actions al momento della
/// compilazione (--dart-define=BUILD_NUMBER=...). 0 = build locale.
const int buildInstallata = int.fromEnvironment('BUILD_NUMBER');

const String _repo = 'dvdsalviato/gymappv2';

class Aggiornamento {
  final int build;
  final String urlApk;
  final String urlPagina;
  final String note;
  const Aggiornamento(this.build, this.urlApk, this.urlPagina, this.note);
}

/// Controllo aggiornamenti sulle Releases di GitHub (dove la build pubblica
/// gli APK) e notifica quando ce n'è uno nuovo.
class Aggiornamenti {
  Aggiornamenti._();

  static const _chiaveUltimoControllo = 'aggiornamenti_ultimo_controllo';
  static const _chiaveNotificata = 'aggiornamenti_build_notificata';
  static const _idNotifica = 7200;

  /// Ultimo aggiornamento trovato (per il banner in Home).
  static final ValueNotifier<Aggiornamento?> disponibile = ValueNotifier(null);

  /// Cerca l'ultima build pubblicata. Null se non ce n'è una più nuova di
  /// quella installata. Lancia un'eccezione se GitHub non risponde.
  static Future<Aggiornamento?> controlla() async {
    final risposta = await http
        .get(
          Uri.parse('https://api.github.com/repos/$_repo/releases?per_page=10'),
          headers: {'Accept': 'application/vnd.github+json'},
        )
        .timeout(const Duration(seconds: 15));
    if (risposta.statusCode == 404) {
      throw Exception('Releases non raggiungibili: il repository deve essere pubblico.');
    }
    if (risposta.statusCode != 200) {
      throw Exception('GitHub ha risposto ${risposta.statusCode}. Riprova più tardi.');
    }
    final releases = jsonDecode(risposta.body) as List;
    Aggiornamento? migliore;
    for (final r in releases) {
      if (r is! Map<String, dynamic>) continue;
      final tag = (r['tag_name'] as String?) ?? '';
      final numero = int.tryParse(tag.replaceFirst('build-', ''));
      if (numero == null) continue;
      String? apk;
      for (final a in (r['assets'] as List? ?? const [])) {
        if (a is! Map<String, dynamic>) continue;
        final nome = (a['name'] as String?) ?? '';
        // L'APK del telefono, non quello dell'orologio.
        if (nome.endsWith('.apk') && !nome.contains('orologio')) {
          apk = a['browser_download_url'] as String?;
        }
      }
      if (apk == null) continue;
      if (migliore == null || numero > migliore.build) {
        migliore = Aggiornamento(
          numero,
          apk,
          (r['html_url'] as String?) ?? 'https://github.com/$_repo/releases',
          _pulisciNote((r['body'] as String?) ?? ''),
        );
      }
    }
    final trovato = (migliore != null && migliore.build > buildInstallata) ? migliore : null;
    disponibile.value = trovato;
    await _ricorda(trovato);
    return trovato;
  }

  static const _chiaveTrovato = 'aggiornamenti_trovato';

  /// Salva l'aggiornamento trovato, così il banner resta anche senza rete.
  static Future<void> _ricorda(Aggiornamento? a) async {
    final prefs = await SharedPreferences.getInstance();
    if (a == null) {
      await prefs.remove(_chiaveTrovato);
      return;
    }
    await prefs.setString(
      _chiaveTrovato,
      jsonEncode({'build': a.build, 'apk': a.urlApk, 'pagina': a.urlPagina, 'note': a.note}),
    );
  }

  /// Ripropone il banner di un aggiornamento già trovato (se è ancora nuovo).
  static Future<void> _ripristina(SharedPreferences prefs) async {
    final testo = prefs.getString(_chiaveTrovato);
    if (testo == null) return;
    try {
      final m = jsonDecode(testo) as Map<String, dynamic>;
      final build = (m['build'] as num).toInt();
      if (build <= buildInstallata) {
        await prefs.remove(_chiaveTrovato);
        return;
      }
      disponibile.value = Aggiornamento(build, m['apk'] as String, m['pagina'] as String, (m['note'] as String?) ?? '');
    } catch (_) {
      await prefs.remove(_chiaveTrovato);
    }
  }

  /// Toglie dalle note di rilascio le righe tecniche sugli APK.
  static String _pulisciNote(String testo) {
    return testo
        .split('\n')
        .where((r) => !r.trim().startsWith('- gymapp'))
        .map((r) => r.replaceFirst('Commit:', '').trim())
        .where((r) => r.isNotEmpty)
        .join('\n');
  }

  /// All'avvio: al massimo un controllo ogni 6 ore. Se c'è una build nuova
  /// mostra la notifica (una volta sola per build). Silenzioso se va male.
  static Future<void> controllaInSilenzio() async {
    if (kIsWeb) return; // la versione web si aggiorna da sola
    try {
      if (buildInstallata == 0) return; // build di prova, non da Actions
      final prefs = await SharedPreferences.getInstance();
      final ultimo = prefs.getInt(_chiaveUltimoControllo) ?? 0;
      final adesso = DateTime.now().millisecondsSinceEpoch;
      if (adesso - ultimo < const Duration(hours: 6).inMilliseconds) {
        // Controllato da poco: si ripropone il banner se era già noto.
        await _ripristina(prefs);
        return;
      }
      await prefs.setInt(_chiaveUltimoControllo, adesso);
      final nuovo = await controlla();
      if (nuovo == null) return;
      if ((prefs.getInt(_chiaveNotificata) ?? 0) >= nuovo.build) return;
      await prefs.setInt(_chiaveNotificata, nuovo.build);
      final plugin = await NotificaAllenamento.plugin();
      await plugin.show(
        id: _idNotifica,
        title: 'È disponibile un nuovo aggiornamento',
        body: 'Gymapp build ${nuovo.build}: apri l\'app e tocca "Aggiorna".',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'gymapp_aggiornamenti',
            'Aggiornamenti app',
            channelDescription: 'Avvisa quando è uscita una nuova versione di Gymapp',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            icon: 'ic_stat_gym',
            color: Color(0xFF39FF14),
          ),
        ),
      );
    } catch (e) {
      debugPrint('Controllo aggiornamenti non riuscito: $e');
    }
  }

  /// Scarica l'APK con il browser: a download finito si tocca per installare
  /// (si aggiorna sopra, i dati restano).
  static Future<bool> scarica(Aggiornamento a) async {
    final ok = await launchUrl(Uri.parse(a.urlApk), mode: LaunchMode.externalApplication);
    if (ok) return true;
    return launchUrl(Uri.parse(a.urlPagina), mode: LaunchMode.externalApplication);
  }
}

/// Dialogo "Aggiorna app": controlla e, se c'è, propone di scaricare.
Future<void> mostraAggiornaApp(BuildContext context) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const AlertDialog(
      content: Row(
        children: [
          SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
          SizedBox(width: 16),
          Expanded(child: Text('Controllo aggiornamenti…')),
        ],
      ),
    ),
  );
  Aggiornamento? nuovo;
  String? errore;
  try {
    nuovo = await Aggiornamenti.controlla();
  } catch (e) {
    errore = e.toString().replaceFirst('Exception: ', '');
  }
  if (!context.mounted) return;
  Navigator.of(context).pop();
  final trovato = nuovo;
  final messaggioErrore = errore;
  await showDialog<void>(
    context: context,
    builder: (ctx) {
      if (messaggioErrore != null) {
        return AlertDialog(
          title: const Text('Controllo non riuscito'),
          content: Text(messaggioErrore),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Ok'))],
        );
      }
      if (trovato == null) {
        return AlertDialog(
          title: const Text('Sei aggiornato'),
          content: Text(
            buildInstallata == 0
                ? 'Questa è una build di prova: gli aggiornamenti si controllano solo sulle build di GitHub.'
                : 'Hai già l\'ultima versione (build $buildInstallata).',
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Ok'))],
        );
      }
      return AlertDialog(
        title: Text('Aggiornamento disponibile: build ${trovato.build}'),
        content: SingleChildScrollView(
          child: Text(
            '${trovato.note.isEmpty ? '' : '${trovato.note}\n\n'}'
            'Installata: build $buildInstallata.\n'
            'Si scarica l\'APK: a download finito toccalo per installare. Si aggiorna sopra, i tuoi dati restano.',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Più tardi')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Aggiornamenti.scarica(trovato);
            },
            style: FilledButton.styleFrom(minimumSize: const Size(110, 44)),
            child: const Text('Aggiorna'),
          ),
        ],
      );
    },
  );
}
