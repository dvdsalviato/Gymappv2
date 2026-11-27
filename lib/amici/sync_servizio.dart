import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database_helper.dart';
import '../state/navigazione.dart';
import '../state/sessione_allenamento.dart';
import '../widgets/dialogo_azioni.dart';
import 'backup_servizio.dart';
import 'firebase_config.dart';

/// Tiene uguali i dati su tutti i dispositivi collegati allo stesso account
/// Google (telefono, browser del PC, iPad...).
///
/// Il cloud contiene sempre l'ultima versione completa dei dati, con un numero
/// di revisione. Ogni dispositivo ricorda con quale revisione è allineato e
/// l'impronta dei suoi dati in quel momento:
/// - qui non è cambiato niente, nel cloud sì → scarica in silenzio;
/// - qui è cambiato qualcosa, nel cloud no → carica;
/// - cambiati tutti e due → chiede quale versione tenere.
///
/// Si controlla all'avvio, quando l'app torna in primo piano, ogni 45 secondi
/// mentre è aperta e alla fine di ogni allenamento. Mai durante un allenamento.
class SyncServizio with WidgetsBindingObserver {
  SyncServizio._();
  static final SyncServizio istanza = SyncServizio._();

  /// Cambia dopo uno scaricamento: l'app ricostruisce le schermate con i dati nuovi.
  final ValueNotifier<int> generazione = ValueNotifier(0);

  bool _avviato = false;
  bool _inCorso = false;
  bool _inPrimoPiano = true;
  bool _conflittoAperto = false;
  Timer? _timer;

  void avvia() {
    if (_avviato) return;
    _avviato = true;
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (_inPrimoPiano) sincronizza();
    });
    // Un attimo dopo l'avvio, quando la prima schermata è pronta.
    Future.delayed(const Duration(seconds: 2), sincronizza);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _inPrimoPiano = true;
      sincronizza();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      // Si esce dall'app: si mandano le modifiche, così le trova l'altro dispositivo.
      if (_inPrimoPiano) sincronizza(soloInvio: true);
      _inPrimoPiano = false;
    }
  }

  Future<bool> _attiva() async {
    if (!firebaseConfigurato) return false;
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('amici_google') ?? false)) return false;
    return prefs.getBool(BackupServizio.chiaveAuto) ?? true;
  }

  bool get _allenamentoInCorso => GestoreSessione.inizioAllenamento != null || GestoreSessione.inPausa != null;

  /// [soloInvio]: non scarica (app che va in background).
  /// [dopoAllenamento]: appena finito un allenamento, anche se lo stato non è ancora azzerato.
  /// [interattivo]: chiamata dalla schermata Account dopo l'accesso: può
  /// scaricare anche se si è dentro una schermata e lo conferma a voce.
  Future<void> sincronizza({bool soloInvio = false, bool dopoAllenamento = false, bool interattivo = false}) async {
    if (_inCorso || _conflittoAperto) return;
    if (!dopoAllenamento && _allenamentoInCorso) return;
    _inCorso = true;
    try {
      if (!interattivo && !await _attiva()) return;
      final backup = BackupServizio.istanza;
      final prefs = await SharedPreferences.getInstance();
      final meta = await backup.metaRemoto();
      final improntaQui = await backup.improntaLocale();
      final revBase = prefs.getInt(BackupServizio.chiaveRev);
      final improntaBase = prefs.getString(BackupServizio.chiaveImpronta);

      // Nel cloud non c'è niente: si carica quello che c'è qui.
      if (meta == null) {
        if (!await _vuoto()) await backup.esegui();
        return;
      }
      final revCloud = BackupServizio.revDi(meta);

      // Prima sincronizzazione di questo dispositivo.
      if (revBase == null || improntaBase == null) {
        final ultimoQui = prefs.getInt(BackupServizio.chiaveUltimo) ?? 0;
        if (await _vuoto()) {
          if (!soloInvio) await _scarica(interattivo: interattivo);
        } else if (ultimoQui >= revCloud) {
          // L'ultimo backup l'ha fatto proprio questo dispositivo.
          await backup.esegui();
        } else if (!soloInvio) {
          await _conflitto(meta, interattivo: interattivo);
        }
        return;
      }

      final cambiatoQui = improntaQui != improntaBase;
      final cambiatoNelCloud = revCloud != revBase;
      if (!cambiatoQui && !cambiatoNelCloud) return;
      if (cambiatoQui && !cambiatoNelCloud) {
        await backup.esegui();
      } else if (!cambiatoQui && cambiatoNelCloud) {
        if (!soloInvio) await _scarica(interattivo: interattivo);
      } else if (!soloInvio) {
        await _conflitto(meta, interattivo: interattivo);
      }
    } catch (_) {
      // Senza rete o con un salvataggio a metà: si riprova al prossimo giro.
    } finally {
      _inCorso = false;
    }
  }

  Future<bool> _vuoto() async {
    final db = DatabaseHelper.instance;
    final dati = await db.esportaTutto();
    return (dati['schede'] ?? const []).isEmpty && (dati['storico'] ?? const []).isEmpty;
  }

  /// Scarica dal cloud e ricostruisce le schermate. Se si è dentro una
  /// schermata (o c'è un dialogo aperto) si aspetta il prossimo giro, per non
  /// cambiare i dati sotto le mani.
  Future<void> _scarica({bool interattivo = false}) async {
    final nav = navigatoreApp.currentState;
    if (!interattivo && (nav == null || nav.canPop() || _allenamentoInCorso)) return;
    await BackupServizio.istanza.ripristina();
    nav?.popUntil((r) => r.isFirst);
    generazione.value++;
  }

  Future<void> _conflitto(Map<String, dynamic> meta, {bool interattivo = false}) async {
    final nav = navigatoreApp.currentState;
    final ctx = nav?.overlay?.context;
    if (nav == null || ctx == null) return;
    if (!interattivo && nav.canPop()) return;
    _conflittoAperto = true;
    String? scelta;
    try {
      final quando = DateTime.fromMillisecondsSinceEpoch(
        (meta['quando'] is num) ? (meta['quando'] as num).toInt() : BackupServizio.revDi(meta),
      );
      String due(int n) => n.toString().padLeft(2, '0');
      final data = '${due(quando.day)}/${due(quando.month)} alle ${due(quando.hour)}:${due(quando.minute)}';
      scelta = await mostraDialogoAzioni<String>(
        ctx,
        titolo: 'Dati diversi su due dispositivi',
        messaggio: 'Hai fatto modifiche qui, ma intanto nel cloud sono arrivati dati da un altro dispositivo '
            '(salvati il $data: ${meta['schede'] ?? 0} schede, ${meta['serie'] ?? 0} serie).\n\n'
            'Quale versione vuoi tenere su tutti i dispositivi? L\'altra verrà sostituita.',
        azioni: const [
          AzioneDialogo('Tieni questa', Icons.smartphone, 'qui', stile: StileAzione.primaria),
          AzioneDialogo('Prendi quella del cloud', Icons.cloud_download_outlined, 'cloud'),
          AzioneDialogo('Decido dopo', Icons.schedule, 'dopo'),
        ],
      );
    } finally {
      _conflittoAperto = false;
    }
    if (scelta == 'qui') {
      await BackupServizio.istanza.esegui();
    } else if (scelta == 'cloud') {
      await _scarica(interattivo: true);
    } else {
      // "Decido dopo": si richiede tra un po', non a ogni controllo.
      _conflittoAperto = true;
      Future.delayed(const Duration(minutes: 10), () => _conflittoAperto = false);
    }
  }

  void ferma() {
    _timer?.cancel();
    _timer = null;
    if (_avviato) WidgetsBinding.instance.removeObserver(this);
    _avviato = false;
  }
}
