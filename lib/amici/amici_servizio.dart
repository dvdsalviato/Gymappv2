import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/statistiche.dart';
import '../db/database_helper.dart';
import '../services/condivisione_scheda.dart';
import 'firebase_config.dart';
import 'firestore_rest.dart';

String coppiaId(String a, String b) => a.compareTo(b) < 0 ? '${a}_$b' : '${b}_$a';

class ProfiloAmici {
  final String uid;
  final String nome;
  final String codice;
  const ProfiloAmici(this.uid, this.nome, this.codice);
}

class Amicizia {
  final String id;
  final String uidAltro;
  final String nomeAltro;
  final String stato; // in_attesa | accettata
  final String da;
  final String ultimoTesto;
  final String ultimoDa;
  final int ultimoTs;

  const Amicizia({
    required this.id,
    required this.uidAltro,
    required this.nomeAltro,
    required this.stato,
    required this.da,
    required this.ultimoTesto,
    required this.ultimoDa,
    required this.ultimoTs,
  });
}

class RecordEsercizio {
  final String nome;
  final double kg;
  const RecordEsercizio(this.nome, this.kg);
}

class StatAmico {
  final String nome;
  final int allenamenti;
  final int serie;
  final int settimane;
  final int obiettivo;
  final int allenSettimana;
  final int serieSettimana;
  final int medaglie;
  final List<RecordEsercizio> records;
  final List<String> schede;
  final int aggiornato;

  const StatAmico({
    required this.nome,
    required this.allenamenti,
    required this.serie,
    required this.settimane,
    required this.obiettivo,
    required this.allenSettimana,
    required this.serieSettimana,
    required this.medaglie,
    required this.records,
    required this.schede,
    required this.aggiornato,
  });
}

class Messaggio {
  final String id;
  final String da;
  final String testo;
  final String tipo; // testo | scheda | progressi
  final String payload;
  final int ts;

  const Messaggio({
    required this.id,
    required this.da,
    required this.testo,
    required this.tipo,
    required this.payload,
    required this.ts,
  });
}

/// Logica del servizio "Amici": profilo, richieste, statistiche e chat.
class AmiciServizio {
  AmiciServizio._();
  static final AmiciServizio istanza = AmiciServizio._();

  final FirestoreRest _r = FirestoreRest.istanza;

  static const _chiaveNome = 'amici_nome';
  static const _chiaveCodice = 'amici_codice';
  static const _chiaveUid = 'amici_uid';
  static const _chiaveCondividiSchede = 'amici_condividi_schede';
  static const _alfabeto = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

  int _int(dynamic v) => v is num ? v.toInt() : 0;
  double _num(dynamic v) => v is num ? v.toDouble() : 0.0;
  String _str(dynamic v) => v is String ? v : '';

  // ---------------------------------------------------------------- profilo

  Future<ProfiloAmici?> profiloLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString(_chiaveUid);
    final nome = prefs.getString(_chiaveNome);
    final codice = prefs.getString(_chiaveCodice);
    if (uid == null || nome == null || codice == null) return null;
    return ProfiloAmici(uid, nome, codice);
  }

  Future<bool> condividiSchede() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_chiaveCondividiSchede) ?? true;
  }

  Future<void> impostaCondividiSchede(bool valore) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_chiaveCondividiSchede, valore);
    await sincronizzaMieiDati();
  }

  Future<String> _codiceLibero() async {
    final casuale = Random.secure();
    for (var i = 0; i < 6; i++) {
      final codice = List.generate(6, (_) => _alfabeto[casuale.nextInt(_alfabeto.length)]).join();
      final trovati = await _r.interroga({
        'from': [
          {'collectionId': 'utenti'},
        ],
        'where': FirestoreRest.filtro('codice', 'EQUAL', codice),
        'limit': 1,
      });
      if (trovati.isEmpty) return codice;
    }
    throw AmiciErrore('Non riesco a generare un codice libero. Riprova.');
  }

  /// Crea il profilo amici (primo accesso).
  Future<ProfiloAmici> registra(String nome) async {
    final pulito = nome.trim();
    if (pulito.isEmpty) throw AmiciErrore('Scrivi un nome.');
    await _r.assicuraAccesso();
    final uid = _r.uid!;
    final codice = await _codiceLibero();
    await _r.scrivi('utenti/$uid', {
      'nome': pulito,
      'codice': codice,
      'creato': DateTime.now().millisecondsSinceEpoch,
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chiaveUid, uid);
    await prefs.setString(_chiaveNome, pulito);
    await prefs.setString(_chiaveCodice, codice);
    final profilo = ProfiloAmici(uid, pulito, codice);
    await sincronizzaMieiDati();
    return profilo;
  }

  Future<void> cambiaNome(String nome) async {
    final p = await profiloLocale();
    if (p == null) return;
    final pulito = nome.trim();
    if (pulito.isEmpty) return;
    await _r.scrivi('utenti/${p.uid}', {'nome': pulito}, maschera: ['nome']);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chiaveNome, pulito);
    await sincronizzaMieiDati();
  }

  // -------------------------------------------------------------- amicizie

  Future<Map<String, dynamic>?> cercaPerCodice(String codice) async {
    final trovati = await _r.interroga({
      'from': [
        {'collectionId': 'utenti'},
      ],
      'where': FirestoreRest.filtro('codice', 'EQUAL', codice.trim().toUpperCase()),
      'limit': 1,
    });
    return trovati.isEmpty ? null : trovati.first;
  }

  Future<void> inviaRichiesta(String uidAltro, String nomeAltro) async {
    final p = await profiloLocale();
    if (p == null) throw AmiciErrore('Crea prima il tuo profilo.');
    if (uidAltro == p.uid) throw AmiciErrore('Questo è il tuo codice.');
    final ordinati = [p.uid, uidAltro]..sort();
    try {
      await _r.crea(
        'amicizie',
        {
          'uids': ordinati,
          'da': p.uid,
          'stato': 'in_attesa',
          'nomi': {p.uid: p.nome, uidAltro: nomeAltro},
          'creata': DateTime.now().millisecondsSinceEpoch,
        },
        id: coppiaId(p.uid, uidAltro),
      );
    } on AmiciErrore catch (e) {
      if (e.codice == 409) throw AmiciErrore('Richiesta già inviata, oppure siete già amici.');
      rethrow;
    }
  }

  Future<List<Amicizia>> amicizie() async {
    final p = await profiloLocale();
    if (p == null) return [];
    final docs = await _r.interroga({
      'from': [
        {'collectionId': 'amicizie'},
      ],
      'where': FirestoreRest.filtro('uids', 'ARRAY_CONTAINS', p.uid),
    });
    final lista = <Amicizia>[];
    for (final d in docs) {
      final uids = ((d['uids'] as List?) ?? const []).map((e) => '$e').toList();
      final altro = uids.firstWhere((u) => u != p.uid, orElse: () => '');
      if (altro.isEmpty) continue;
      final nomi = (d['nomi'] as Map?) ?? const {};
      lista.add(Amicizia(
        id: _str(d['_id']),
        uidAltro: altro,
        nomeAltro: _str(nomi[altro]).isEmpty ? 'Amico' : _str(nomi[altro]),
        stato: _str(d['stato']),
        da: _str(d['da']),
        ultimoTesto: _str(d['ultimoTesto']),
        ultimoDa: _str(d['ultimoDa']),
        ultimoTs: _int(d['ultimoTs']),
      ));
    }
    return lista;
  }

  Future<void> accetta(String idAmicizia) =>
      _r.scrivi('amicizie/$idAmicizia', {'stato': 'accettata'}, maschera: ['stato']);

  Future<void> rimuovi(String idAmicizia) => _r.elimina('amicizie/$idAmicizia');

  // ------------------------------------------------------------ statistiche

  /// Pubblica le mie statistiche (visibili solo agli amici accettati).
  Future<void> sincronizzaMieiDati() async {
    if (!firebaseConfigurato) return;
    final p = await profiloLocale();
    if (p == null) return;
    final db = DatabaseHelper.instance;
    final stat = await caricaStatistiche();
    final volumi = await db.getVolumePerCategoria(giorni: 7);
    final serieSettimana = volumi.values.fold<int>(0, (a, b) => a + b);
    final records = await db.getRecordPerEsercizio();
    final prefs = await SharedPreferences.getInstance();
    final medaglie = (prefs.getStringList('medaglie_sbloccate') ?? const <String>[]).length;
    final condividi = await condividiSchede();

    final schede = <String>[];
    if (condividi) {
      for (final s in await db.getSchede()) {
        final id = s.id;
        if (id == null) continue;
        schede.add(codificaScheda(s.nome, await db.getEsercizi(id)));
      }
    }

    await _r.scrivi('statistiche/${p.uid}', {
      'nome': p.nome,
      'allenamenti': stat.allenamenti,
      'serie': stat.serie,
      'settimane': stat.settimane,
      'obiettivo': stat.obiettivo,
      'allenSettimana': stat.allenamentiSettimana,
      'serieSettimana': serieSettimana,
      'medaglie': medaglie,
      'records': [
        for (final r in records)
          {'n': r['nome'] as String, 'kg': (r['kg'] as num).toDouble()},
      ],
      'schede': schede,
      'aggiornato': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Come sopra, ma senza mai dare errori (da usare dopo un allenamento).
  void sincronizzaInBackground() {
    () async {
      try {
        await sincronizzaMieiDati();
      } catch (_) {}
    }();
  }

  Future<StatAmico?> statisticheAmico(String uid) async {
    final d = await _r.leggi('statistiche/$uid');
    if (d == null) return null;
    final records = <RecordEsercizio>[];
    for (final r in (d['records'] as List?) ?? const []) {
      if (r is Map) records.add(RecordEsercizio(_str(r['n']), _num(r['kg'])));
    }
    return StatAmico(
      nome: _str(d['nome']),
      allenamenti: _int(d['allenamenti']),
      serie: _int(d['serie']),
      settimane: _int(d['settimane']),
      obiettivo: _int(d['obiettivo']),
      allenSettimana: _int(d['allenSettimana']),
      serieSettimana: _int(d['serieSettimana']),
      medaglie: _int(d['medaglie']),
      records: records,
      schede: ((d['schede'] as List?) ?? const []).map((e) => '$e').toList(),
      aggiornato: _int(d['aggiornato']),
    );
  }

  // ------------------------------------------------------------------- chat

  Future<void> inviaMessaggio(
    String idAmicizia,
    String testo, {
    String tipo = 'testo',
    String payload = '',
  }) async {
    final p = await profiloLocale();
    if (p == null) throw AmiciErrore('Crea prima il tuo profilo.');
    final ts = DateTime.now().millisecondsSinceEpoch;
    await _r.crea('chat/$idAmicizia/messaggi', {
      'da': p.uid,
      'testo': testo,
      'tipo': tipo,
      'payload': payload,
      'ts': ts,
    });
    var anteprima = testo;
    if (tipo == 'scheda') anteprima = '📋 Scheda: $testo';
    if (tipo == 'progressi') anteprima = '📈 Progressi condivisi';
    if (anteprima.length > 60) anteprima = '${anteprima.substring(0, 60)}…';
    await _r.scrivi(
      'amicizie/$idAmicizia',
      {'ultimoTesto': anteprima, 'ultimoDa': p.uid, 'ultimoTs': ts},
      maschera: ['ultimoTesto', 'ultimoDa', 'ultimoTs'],
    );
  }

  Messaggio _messaggio(Map<String, dynamic> d) => Messaggio(
        id: _str(d['_id']),
        da: _str(d['da']),
        testo: _str(d['testo']),
        tipo: _str(d['tipo']).isEmpty ? 'testo' : _str(d['tipo']),
        payload: _str(d['payload']),
        ts: _int(d['ts']),
      );

  /// Ultimi messaggi (dal più vecchio al più recente).
  Future<List<Messaggio>> ultimiMessaggi(String idAmicizia, {int limite = 40}) async {
    final docs = await _r.interroga(
      {
        'from': [
          {'collectionId': 'messaggi'},
        ],
        'orderBy': [
          {
            'field': {'fieldPath': 'ts'},
            'direction': 'DESCENDING',
          },
        ],
        'limit': limite,
      },
      genitore: 'chat/$idAmicizia',
    );
    final lista = docs.map(_messaggio).toList();
    lista.sort((a, b) => a.ts.compareTo(b.ts));
    return lista;
  }

  /// Messaggi arrivati dopo [dopoTs] (con un margine per gli orologi sfasati).
  Future<List<Messaggio>> nuoviMessaggi(String idAmicizia, int dopoTs) async {
    final docs = await _r.interroga(
      {
        'from': [
          {'collectionId': 'messaggi'},
        ],
        'where': FirestoreRest.filtro('ts', 'GREATER_THAN', dopoTs - 60000),
        'orderBy': [
          {
            'field': {'fieldPath': 'ts'},
            'direction': 'ASCENDING',
          },
        ],
        'limit': 100,
      },
      genitore: 'chat/$idAmicizia',
    );
    return docs.map(_messaggio).toList();
  }

  Future<int> lettoFinoA(String idAmicizia) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('amici_letto_$idAmicizia') ?? 0;
  }

  Future<void> segnaLetto(String idAmicizia, int ts) async {
    final prefs = await SharedPreferences.getInstance();
    final attuale = prefs.getInt('amici_letto_$idAmicizia') ?? 0;
    if (ts > attuale) await prefs.setInt('amici_letto_$idAmicizia', ts);
  }
}
