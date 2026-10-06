import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_config.dart';

class AmiciErrore implements Exception {
  final String messaggio;
  final int? codice;
  AmiciErrore(this.messaggio, {this.codice});

  @override
  String toString() => messaggio;
}

/// Accesso a Firebase tramite le API REST (nessuna libreria nativa):
/// login anonimo + lettura/scrittura su Firestore.
class FirestoreRest {
  FirestoreRest._();
  static final FirestoreRest istanza = FirestoreRest._();

  static const _chiaveUid = 'amici_uid';
  static const _chiaveRinnovo = 'amici_refresh';

  String? _idToken;
  String? _refreshToken;
  DateTime _scadenza = DateTime.fromMillisecondsSinceEpoch(0);
  String? uid;
  Future<void>? _accessoInCorso;

  String get _base =>
      'https://firestore.googleapis.com/v1/projects/$firebaseProjectId/databases/(default)/documents';

  // ---------------------------------------------------------------- accesso

  Future<void> assicuraAccesso() async {
    if (_idToken != null && DateTime.now().isBefore(_scadenza.subtract(const Duration(minutes: 2)))) {
      return;
    }
    _accessoInCorso ??= _accedi().whenComplete(() => _accessoInCorso = null);
    await _accessoInCorso;
  }

  Future<void> _accedi() async {
    final prefs = await SharedPreferences.getInstance();
    _refreshToken ??= prefs.getString(_chiaveRinnovo);
    uid ??= prefs.getString(_chiaveUid);
    if (_refreshToken != null) {
      final riuscito = await _rinnova(prefs);
      if (riuscito) return;
    }
    await _nuovoAccountAnonimo(prefs);
  }

  Future<bool> _rinnova(SharedPreferences prefs) async {
    http.Response r;
    try {
      r = await http
          .post(
            Uri.parse('https://securetoken.googleapis.com/v1/token?key=$firebaseApiKey'),
            body: {'grant_type': 'refresh_token', 'refresh_token': _refreshToken!},
          )
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      throw AmiciErrore('Connessione assente o lenta. Riprova.');
    }
    if (r.statusCode == 200) {
      final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      _idToken = j['id_token'] as String;
      _refreshToken = j['refresh_token'] as String? ?? _refreshToken;
      uid = j['user_id'] as String? ?? uid;
      final secondi = int.tryParse('${j['expires_in']}') ?? 3600;
      _scadenza = DateTime.now().add(Duration(seconds: secondi));
      await prefs.setString(_chiaveRinnovo, _refreshToken!);
      if (uid != null) await prefs.setString(_chiaveUid, uid!);
      return true;
    }
    if (r.statusCode == 400) return false; // token non più valido: nuovo account
    throw AmiciErrore('Accesso non riuscito (${r.statusCode}).', codice: r.statusCode);
  }

  Future<void> _nuovoAccountAnonimo(SharedPreferences prefs) async {
    http.Response r;
    try {
      r = await http
          .post(
            Uri.parse('https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$firebaseApiKey'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'returnSecureToken': true}),
          )
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      throw AmiciErrore('Connessione assente o lenta. Riprova.');
    }
    if (r.statusCode != 200) {
      var dettaglio = '';
      try {
        final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
        dettaglio = ((j['error'] as Map?)?['message'] ?? '').toString();
      } catch (_) {}
      if (dettaglio.contains('OPERATION_NOT_ALLOWED') || dettaglio.contains('ADMIN_ONLY')) {
        throw AmiciErrore('Attiva l\'accesso "Anonimo" in Firebase > Authentication > Metodo di accesso.');
      }
      if (dettaglio.contains('API key')) {
        throw AmiciErrore('La chiave API di Firebase non è valida: controlla firebase_config.dart.');
      }
      throw AmiciErrore('Accesso non riuscito (${r.statusCode}). $dettaglio');
    }
    final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    _idToken = j['idToken'] as String;
    _refreshToken = j['refreshToken'] as String;
    uid = j['localId'] as String;
    final secondi = int.tryParse('${j['expiresIn']}') ?? 3600;
    _scadenza = DateTime.now().add(Duration(seconds: secondi));
    await prefs.setString(_chiaveRinnovo, _refreshToken!);
    await prefs.setString(_chiaveUid, uid!);
  }

  // ---------------------------------------------------------------- Google

  String _messaggioErrore(http.Response r) {
    try {
      final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      return ((j['error'] as Map?)?['message'] ?? '').toString();
    } catch (_) {
      return '';
    }
  }

  /// Collega l'account Google a quello attuale (stesso uid, quindi stessi
  /// amici). Se l'account Google era già stato usato (es. dopo una
  /// reinstallazione) passa a quel profilo. Restituisce true se l'uid è cambiato.
  Future<bool> collegaGoogle(String googleIdToken, {String? email}) async {
    await assicuraAccesso();
    final uidPrima = uid;
    final url = Uri.parse(
      'https://identitytoolkit.googleapis.com/v1/accounts:signInWithIdp?key=$firebaseApiKey',
    );

    Future<http.Response> chiama(bool collega) async {
      try {
        return await http
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'postBody': 'id_token=$googleIdToken&providerId=google.com',
                'requestUri': 'http://localhost',
                'returnIdpCredential': true,
                'returnSecureToken': true,
                if (collega) 'idToken': _idToken,
              }),
            )
            .timeout(const Duration(seconds: 25));
      } catch (_) {
        throw AmiciErrore('Connessione assente o lenta. Riprova.');
      }
    }

    var r = await chiama(true);
    if (r.statusCode != 200) {
      final dettaglio = _messaggioErrore(r);
      if (dettaglio.contains('FEDERATED_USER_ID_ALREADY_LINKED') || dettaglio.contains('CREDENTIAL_ALREADY_IN_USE')) {
        r = await chiama(false);
      }
    }
    if (r.statusCode != 200) {
      final dettaglio = _messaggioErrore(r);
      if (dettaglio.contains('OPERATION_NOT_ALLOWED')) {
        throw AmiciErrore('Attiva il provider "Google" in Firebase > Authentication > Metodo di accesso.');
      }
      throw AmiciErrore('Accesso con Google non riuscito (${r.statusCode}). $dettaglio');
    }
    final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    _idToken = j['idToken'] as String;
    _refreshToken = j['refreshToken'] as String;
    uid = j['localId'] as String;
    final secondi = int.tryParse('${j['expiresIn']}') ?? 3600;
    _scadenza = DateTime.now().add(Duration(seconds: secondi));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chiaveRinnovo, _refreshToken!);
    await prefs.setString(_chiaveUid, uid!);
    await prefs.setBool('amici_google', true);
    await prefs.setString('amici_email', (j['email'] as String?) ?? email ?? '');
    return uidPrima != null && uidPrima != uid;
  }

  /// Dimentica l'account su questo telefono (i dati online restano).
  Future<void> esciLocale() async {
    _idToken = null;
    _refreshToken = null;
    uid = null;
    _scadenza = DateTime.fromMillisecondsSinceEpoch(0);
    final prefs = await SharedPreferences.getInstance();
    for (final k in [_chiaveRinnovo, _chiaveUid, 'amici_google', 'amici_email', 'amici_nome', 'amici_codice']) {
      await prefs.remove(k);
    }
  }

  // ------------------------------------------------------------------ rete

  Future<http.Response> _chiama(String metodo, Uri url, {Object? corpo}) async {
    await assicuraAccesso();
    for (var tentativo = 0; tentativo < 2; tentativo++) {
      http.Response r;
      try {
        final richiesta = http.Request(metodo, url)
          ..headers['Authorization'] = 'Bearer $_idToken'
          ..headers['Content-Type'] = 'application/json';
        if (corpo != null) richiesta.body = jsonEncode(corpo);
        final flusso = await richiesta.send().timeout(const Duration(seconds: 20));
        r = await http.Response.fromStream(flusso);
      } catch (_) {
        throw AmiciErrore('Connessione assente o lenta. Riprova.');
      }
      if (r.statusCode == 401 && tentativo == 0) {
        _idToken = null;
        await assicuraAccesso();
        continue;
      }
      return r;
    }
    throw AmiciErrore('Accesso non riuscito.');
  }

  AmiciErrore _errore(http.Response r) {
    var dettaglio = '';
    try {
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      if (j is Map && j['error'] is Map) dettaglio = ((j['error'] as Map)['message'] ?? '').toString();
    } catch (_) {}
    switch (r.statusCode) {
      case 403:
        return AmiciErrore('Permesso negato dal server: controlla le regole di Firestore. $dettaglio', codice: 403);
      case 404:
        return AmiciErrore('Non trovato.', codice: 404);
      case 409:
        return AmiciErrore('Esiste già.', codice: 409);
      default:
        return AmiciErrore('Errore del server (${r.statusCode}). $dettaglio', codice: r.statusCode);
    }
  }

  // ------------------------------------------------------------- operazioni

  Future<Map<String, dynamic>?> leggi(String percorso) async {
    final r = await _chiama('GET', Uri.parse('$_base/$percorso'));
    if (r.statusCode == 404) return null;
    if (r.statusCode != 200) throw _errore(r);
    return _documento(jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>);
  }

  /// Scrive un documento (lo crea se non esiste). Con [maschera] aggiorna solo
  /// quei campi.
  Future<void> scrivi(String percorso, Map<String, dynamic> campi, {List<String>? maschera}) async {
    var url = '$_base/$percorso';
    if (maschera != null && maschera.isNotEmpty) {
      url += '?${maschera.map((m) => 'updateMask.fieldPaths=${Uri.encodeQueryComponent(m)}').join('&')}';
    }
    final r = await _chiama('PATCH', Uri.parse(url), corpo: {'fields': _codificaCampi(campi)});
    if (r.statusCode != 200) throw _errore(r);
  }

  /// Crea un documento in una collezione (id automatico, oppure [id]).
  Future<String> crea(String collezione, Map<String, dynamic> campi, {String? id}) async {
    var url = '$_base/$collezione';
    if (id != null) url += '?documentId=${Uri.encodeQueryComponent(id)}';
    final r = await _chiama('POST', Uri.parse(url), corpo: {'fields': _codificaCampi(campi)});
    if (r.statusCode != 200) throw _errore(r);
    final doc = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    return (doc['name'] as String).split('/').last;
  }

  Future<void> elimina(String percorso) async {
    final r = await _chiama('DELETE', Uri.parse('$_base/$percorso'));
    if (r.statusCode != 200 && r.statusCode != 404) throw _errore(r);
  }

  Future<List<Map<String, dynamic>>> interroga(Map<String, dynamic> query, {String genitore = ''}) async {
    final url = genitore.isEmpty ? '$_base:runQuery' : '$_base/$genitore:runQuery';
    final r = await _chiama('POST', Uri.parse(url), corpo: {'structuredQuery': query});
    if (r.statusCode != 200) throw _errore(r);
    final lista = jsonDecode(utf8.decode(r.bodyBytes)) as List;
    final risultato = <Map<String, dynamic>>[];
    for (final voce in lista) {
      if (voce is Map && voce['document'] is Map) {
        risultato.add(_documento(Map<String, dynamic>.from(voce['document'] as Map)));
      }
    }
    return risultato;
  }

  static Map<String, dynamic> filtro(String campo, String operatore, dynamic valore) => {
        'fieldFilter': {
          'field': {'fieldPath': campo},
          'op': operatore,
          'value': _valore(valore),
        },
      };

  // ---------------------------------------------------------- conversione

  static Map<String, dynamic> _documento(Map<String, dynamic> doc) {
    final campi = (doc['fields'] as Map?) ?? const {};
    final risultato = <String, dynamic>{};
    campi.forEach((k, v) {
      risultato['$k'] = _decodifica(Map<String, dynamic>.from(v as Map));
    });
    risultato['_id'] = ((doc['name'] as String?) ?? '').split('/').last;
    return risultato;
  }

  static Map<String, dynamic> _codificaCampi(Map<String, dynamic> campi) =>
      campi.map((k, v) => MapEntry(k, _valore(v)));

  static Map<String, dynamic> _valore(dynamic v) {
    if (v == null) return {'nullValue': null};
    if (v is bool) return {'booleanValue': v};
    if (v is int) return {'integerValue': v.toString()};
    if (v is double) return {'doubleValue': v};
    if (v is String) return {'stringValue': v};
    if (v is List) return {'arrayValue': {'values': v.map(_valore).toList()}};
    if (v is Map) {
      return {'mapValue': {'fields': _codificaCampi(Map<String, dynamic>.from(v))}};
    }
    return {'stringValue': v.toString()};
  }

  static dynamic _decodifica(Map<String, dynamic> v) {
    if (v.containsKey('stringValue')) return v['stringValue'];
    if (v.containsKey('integerValue')) return int.tryParse('${v['integerValue']}') ?? 0;
    if (v.containsKey('doubleValue')) return (v['doubleValue'] as num).toDouble();
    if (v.containsKey('booleanValue')) return v['booleanValue'] == true;
    if (v.containsKey('timestampValue')) return v['timestampValue'];
    if (v.containsKey('arrayValue')) {
      final a = Map<String, dynamic>.from(v['arrayValue'] as Map);
      final valori = (a['values'] as List?) ?? const [];
      return valori.map((e) => _decodifica(Map<String, dynamic>.from(e as Map))).toList();
    }
    if (v.containsKey('mapValue')) {
      final m = Map<String, dynamic>.from(v['mapValue'] as Map);
      final campi = (m['fields'] as Map?) ?? const {};
      return campi.map((k, e) => MapEntry('$k', _decodifica(Map<String, dynamic>.from(e as Map))));
    }
    return null;
  }
}
