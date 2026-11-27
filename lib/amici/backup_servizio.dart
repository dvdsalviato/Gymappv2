import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/statistiche.dart';
import '../db/database_helper.dart';
import 'firebase_config.dart';
import 'firestore_rest.dart';
import 'sync_servizio.dart';

class InfoBackup {
  final DateTime quando;
  final int schede;
  final int serie;
  final int pesi;
  const InfoBackup(this.quando, this.schede, this.serie, this.pesi);
}

/// Backup e ripristino dei dati sul cloud, nell'area privata del tuo account.
class BackupServizio {
  BackupServizio._();
  static final BackupServizio istanza = BackupServizio._();

  final FirestoreRest _r = FirestoreRest.istanza;
  static const int _righePerParte = 1500;

  static const chiaveAuto = 'backup_auto';
  static const chiaveUltimo = 'backup_ultimo';

  /// Sincronizzazione: revisione del cloud con cui questo dispositivo è
  /// allineato e impronta dei dati locali in quel momento.
  static const chiaveRev = 'sync_rev';
  static const chiaveImpronta = 'sync_impronta';

  /// Revisione di un backup nel cloud. I backup fatti da versioni vecchie
  /// dell'app non hanno "rev": vale l'ora in cui sono stati fatti.
  static int revDi(Map<String, dynamic> meta) {
    final r = meta['rev'] ?? meta['quando'];
    return r is num ? r.toInt() : 0;
  }

  /// Impronta dei dati che si sincronizzano: se cambia, su questo dispositivo
  /// è stato modificato qualcosa dall'ultima sincronizzazione.
  static String impronta(Map<String, List<Map<String, dynamic>>> dati, int? obiettivo) {
    final contenuto = <String, Object?>{
      for (final t in const ['schede', 'esercizi', 'storico', 'sessioni', 'peso_storico', 'profilo']) t: dati[t] ?? const [],
      'obiettivo': obiettivo,
    };
    return sha1.convert(utf8.encode(jsonEncode(contenuto))).toString();
  }

  /// Impronta dei dati attuali di questo dispositivo.
  Future<String> improntaLocale() async {
    final dati = await DatabaseHelper.instance.esportaTutto();
    final prefs = await SharedPreferences.getInstance();
    return impronta(dati, prefs.getInt(chiaveObiettivoSettimanale));
  }

  /// Dati di sincronizzazione del cloud (null se non c'è ancora nessun backup).
  Future<Map<String, dynamic>?> metaRemoto() async {
    final uid = await _uid();
    return _r.leggi('backup/$uid');
  }

  Future<String> _uid() async {
    await _r.assicuraAccesso();
    final uid = _r.uid;
    if (uid == null) throw AmiciErrore('Account non disponibile.');
    return uid;
  }

  Future<void> _scriviParte(String uid, String nome, Object dati) =>
      _r.scrivi('backup/$uid/parti/$nome', {'dati': jsonEncode(dati)});

  Future<dynamic> _leggiParte(String uid, String nome) async {
    final d = await _r.leggi('backup/$uid/parti/$nome');
    if (d == null) throw AmiciErrore('Il backup è incompleto (manca "$nome").');
    return jsonDecode(d['dati'] as String);
  }

  List<List<Map<String, dynamic>>> _inPezzi(List<Map<String, dynamic>> righe) {
    final pezzi = <List<Map<String, dynamic>>>[];
    for (var i = 0; i < righe.length; i += _righePerParte) {
      pezzi.add(righe.sublist(i, i + _righePerParte > righe.length ? righe.length : i + _righePerParte));
    }
    return pezzi;
  }

  /// Salva tutti i dati sul cloud. Ogni salvataggio ha una revisione nuova e
  /// le sue parti hanno un nome proprio: chi sta scaricando non mescola mai
  /// pezzi di due salvataggi diversi.
  Future<InfoBackup> esegui() async {
    if (!firebaseConfigurato) throw AmiciErrore('Il servizio online non è configurato.');
    final uid = await _uid();
    final db = DatabaseHelper.instance;
    final dati = await db.esportaTutto();
    final prefs = await SharedPreferences.getInstance();
    final obiettivo = prefs.getInt(chiaveObiettivoSettimanale);

    final precedente = await _r.leggi('backup/$uid');
    final revPrecedente = precedente == null ? 0 : revDi(precedente);
    final ora = DateTime.now().millisecondsSinceEpoch;
    final rev = ora > revPrecedente ? ora : revPrecedente + 1;
    final suff = '_r$rev';

    final principale = {
      'schede': dati['schede'],
      'esercizi': dati['esercizi'],
      'peso_storico': dati['peso_storico'],
      'profilo': dati['profilo'],
      'extra': {
        'obiettivo': obiettivo,
        'medaglie': prefs.getStringList('medaglie_sbloccate') ?? <String>[],
        'condividiSchede': prefs.getBool('amici_condividi_schede') ?? true,
      },
    };
    await _scriviParte(uid, 'principale$suff', principale);

    final storico = _inPezzi(dati['storico'] ?? []);
    for (var i = 0; i < storico.length; i++) {
      await _scriviParte(uid, 'storico_$i$suff', storico[i]);
    }
    final sessioni = _inPezzi(dati['sessioni'] ?? []);
    for (var i = 0; i < sessioni.length; i++) {
      await _scriviParte(uid, 'sessioni_$i$suff', sessioni[i]);
    }

    final nSerie = (dati['storico'] ?? []).length;
    await _r.scrivi('backup/$uid', {
      'quando': ora,
      'versione': 2,
      'rev': rev,
      'suff': suff,
      'partiStorico': storico.length,
      'partiSessioni': sessioni.length,
      'schede': (dati['schede'] ?? []).length,
      'serie': nSerie,
      'pesi': (dati['peso_storico'] ?? []).length,
    });
    await prefs.setInt(chiaveUltimo, ora);
    await prefs.setInt(chiaveRev, rev);
    await prefs.setString(chiaveImpronta, impronta(dati, obiettivo));

    // Le parti del salvataggio precedente non servono più (quelle senza
    // revisione restano: le leggono le versioni vecchie dell'app).
    if (precedente != null && precedente['suff'] is String && (precedente['suff'] as String).isNotEmpty) {
      final vecchio = precedente['suff'] as String;
      int n(dynamic v) => v is num ? v.toInt() : 0;
      final nomi = [
        'principale$vecchio',
        for (var i = 0; i < n(precedente['partiStorico']); i++) 'storico_$i$vecchio',
        for (var i = 0; i < n(precedente['partiSessioni']); i++) 'sessioni_$i$vecchio',
      ];
      for (final nome in nomi) {
        try {
          await _r.elimina('backup/$uid/parti/$nome');
        } catch (_) {}
      }
    }
    return InfoBackup(
      DateTime.fromMillisecondsSinceEpoch(ora),
      (dati['schede'] ?? []).length,
      nSerie,
      (dati['peso_storico'] ?? []).length,
    );
  }

  /// Informazioni sul backup presente nel cloud (null se non esiste).
  Future<InfoBackup?> infoRemoto() async {
    final uid = await _uid();
    final d = await _r.leggi('backup/$uid');
    if (d == null) return null;
    int n(dynamic v) => v is num ? v.toInt() : 0;
    return InfoBackup(DateTime.fromMillisecondsSinceEpoch(n(d['quando'])), n(d['schede']), n(d['serie']), n(d['pesi']));
  }

  /// Sostituisce i dati di questo telefono con quelli del backup.
  Future<void> ripristina() async {
    final uid = await _uid();
    final meta = await _r.leggi('backup/$uid');
    if (meta == null) throw AmiciErrore('Non c\'è nessun backup da ripristinare.');
    int n(dynamic v) => v is num ? v.toInt() : 0;
    final suff = meta['suff'] is String ? meta['suff'] as String : '';

    final principale = Map<String, dynamic>.from(await _leggiParte(uid, 'principale$suff') as Map);
    List<Map<String, dynamic>> lista(dynamic v) =>
        ((v as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

    final storico = <Map<String, dynamic>>[];
    for (var i = 0; i < n(meta['partiStorico']); i++) {
      storico.addAll(lista(await _leggiParte(uid, 'storico_$i$suff')));
    }
    final sessioni = <Map<String, dynamic>>[];
    for (var i = 0; i < n(meta['partiSessioni']); i++) {
      sessioni.addAll(lista(await _leggiParte(uid, 'sessioni_$i$suff')));
    }

    await DatabaseHelper.instance.importaTutto({
      'schede': lista(principale['schede']),
      'esercizi': lista(principale['esercizi']),
      'storico': storico,
      'sessioni': sessioni,
      'peso_storico': lista(principale['peso_storico']),
      'profilo': lista(principale['profilo']),
    });

    final extra = Map<String, dynamic>.from((principale['extra'] as Map?) ?? const {});
    final prefs = await SharedPreferences.getInstance();
    if (extra['obiettivo'] is num) await prefs.setInt(chiaveObiettivoSettimanale, (extra['obiettivo'] as num).toInt());
    if (extra['medaglie'] is List) {
      await prefs.setStringList('medaglie_sbloccate', (extra['medaglie'] as List).map((e) => '$e').toList());
    }
    if (extra['condividiSchede'] is bool) await prefs.setBool('amici_condividi_schede', extra['condividiSchede'] as bool);
    await prefs.setInt(chiaveUltimo, DateTime.now().millisecondsSinceEpoch);
    // Ora questo dispositivo è allineato a questa revisione del cloud.
    await prefs.setInt(chiaveRev, revDi(meta));
    await prefs.setString(chiaveImpronta, await improntaLocale());
  }

  /// Dopo un allenamento: manda subito i dati agli altri dispositivi.
  void backupAutomatico() {
    SyncServizio.istanza.sincronizza(dopoAllenamento: true);
  }
}
