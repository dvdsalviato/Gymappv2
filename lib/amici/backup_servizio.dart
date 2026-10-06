import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/statistiche.dart';
import '../db/database_helper.dart';
import 'firebase_config.dart';
import 'firestore_rest.dart';

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

  /// Salva tutti i dati sul cloud.
  Future<InfoBackup> esegui() async {
    if (!firebaseConfigurato) throw AmiciErrore('Il servizio online non è configurato.');
    final uid = await _uid();
    final db = DatabaseHelper.instance;
    final dati = await db.esportaTutto();
    final prefs = await SharedPreferences.getInstance();

    final principale = {
      'schede': dati['schede'],
      'esercizi': dati['esercizi'],
      'peso_storico': dati['peso_storico'],
      'profilo': dati['profilo'],
      'extra': {
        'obiettivo': prefs.getInt(chiaveObiettivoSettimanale),
        'medaglie': prefs.getStringList('medaglie_sbloccate') ?? <String>[],
        'condividiSchede': prefs.getBool('amici_condividi_schede') ?? true,
      },
    };
    await _scriviParte(uid, 'principale', principale);

    final storico = _inPezzi(dati['storico'] ?? []);
    for (var i = 0; i < storico.length; i++) {
      await _scriviParte(uid, 'storico_$i', storico[i]);
    }
    final sessioni = _inPezzi(dati['sessioni'] ?? []);
    for (var i = 0; i < sessioni.length; i++) {
      await _scriviParte(uid, 'sessioni_$i', sessioni[i]);
    }

    final ora = DateTime.now().millisecondsSinceEpoch;
    final nSerie = (dati['storico'] ?? []).length;
    await _r.scrivi('backup/$uid', {
      'quando': ora,
      'versione': 1,
      'partiStorico': storico.length,
      'partiSessioni': sessioni.length,
      'schede': (dati['schede'] ?? []).length,
      'serie': nSerie,
      'pesi': (dati['peso_storico'] ?? []).length,
    });
    await prefs.setInt(chiaveUltimo, ora);
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

    final principale = Map<String, dynamic>.from(await _leggiParte(uid, 'principale') as Map);
    List<Map<String, dynamic>> lista(dynamic v) =>
        ((v as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

    final storico = <Map<String, dynamic>>[];
    for (var i = 0; i < n(meta['partiStorico']); i++) {
      storico.addAll(lista(await _leggiParte(uid, 'storico_$i')));
    }
    final sessioni = <Map<String, dynamic>>[];
    for (var i = 0; i < n(meta['partiSessioni']); i++) {
      sessioni.addAll(lista(await _leggiParte(uid, 'sessioni_$i')));
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
  }

  /// Backup automatico dopo un allenamento (silenzioso).
  void backupAutomatico() {
    () async {
      try {
        if (!firebaseConfigurato) return;
        final prefs = await SharedPreferences.getInstance();
        if (!(prefs.getBool('amici_google') ?? false)) return;
        if (!(prefs.getBool(chiaveAuto) ?? true)) return;
        await esegui();
      } catch (_) {}
    }();
  }
}
