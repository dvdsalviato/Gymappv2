import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_config.dart';
import 'firestore_rest.dart';

class StatoAccount {
  final bool collegato;
  final String email;
  const StatoAccount(this.collegato, this.email);
}

/// Accesso con l'account Google, collegato al profilo amici.
class AccountServizio {
  AccountServizio._();
  static final AccountServizio istanza = AccountServizio._();

  bool _inizializzato = false;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _eventiWeb;
  final StreamController<Object> _esitiWeb = StreamController<Object>.broadcast();

  /// Sul web l'accesso parte dal pulsante ufficiale di Google: qui arrivano
  /// gli esiti (bool = ripristinato, oppure un AmiciErrore).
  Stream<Object> get esitiWeb => _esitiWeb.stream;

  /// Prepara Google Sign-In nel browser (va chiamato prima di mostrare il pulsante).
  Future<void> preparaWeb() async {
    if (!kIsWeb || _inizializzato) return;
    await GoogleSignIn.instance.initialize(clientId: googleWebClientId);
    _inizializzato = true;
    _eventiWeb = GoogleSignIn.instance.authenticationEvents.listen((evento) async {
      if (evento is GoogleSignInAuthenticationEventSignIn) {
        try {
          _esitiWeb.add(await _completa(evento.user));
        } catch (e) {
          _esitiWeb.add(e is AmiciErrore ? e : AmiciErrore('Accesso con Google non riuscito.\n\n$e'));
        }
      }
    }, onError: (Object e) {
      final t = e.toString().toLowerCase();
      if (t.contains('cancel')) return;
      _esitiWeb.add(AmiciErrore('Accesso con Google non riuscito.\n\nDettagli tecnici:\n$e\n\n'
          'Controlla che gymapp27.web.app sia tra le "Origini JavaScript autorizzate" del client OAuth Web.'));
    });
  }

  Future<StatoAccount> stato() async {
    final prefs = await SharedPreferences.getInstance();
    return StatoAccount(prefs.getBool('amici_google') ?? false, prefs.getString('amici_email') ?? '');
  }

  /// Accede con Google. Restituisce true se l'account era già stato usato e
  /// questo telefono è passato al profilo esistente (ripristino).
  Future<bool> accedi() async {
    if (kIsWeb) {
      throw AmiciErrore('Sul web usa il pulsante "Accedi con Google" qui sopra.');
    }
    if (!googleConfigurato) {
      throw AmiciErrore('Manca l\'ID client Google in lib/amici/firebase_config.dart.');
    }
    if (!_inizializzato) {
      await GoogleSignIn.instance.initialize(serverClientId: googleWebClientId);
      _inizializzato = true;
    }
    GoogleSignInAccount? account;
    try {
      account = await GoogleSignIn.instance.authenticate();
    } catch (e) {
      final testo = e.toString();
      final minuscolo = testo.toLowerCase();
      if (minuscolo.contains('cancelled by the user') ||
          minuscolo.contains('canceled by the user') ||
          minuscolo.contains('user cancel')) {
        throw AmiciErrore('Accesso annullato.');
      }
      // Google a volte segnala come "annullato" anche un errore di configurazione:
      // mostro il testo vero per capire cosa non va.
      throw AmiciErrore(
        'Accesso con Google non riuscito.\n\nDettagli tecnici:\n$testo\n\n'
        'Di solito dipende da SHA-1, nome pacchetto o ID client Web non corrispondenti in Firebase.',
      );
    }
    final conto = account;
    if (conto == null) throw AmiciErrore('Accesso non riuscito.');
    return _completa(conto);
  }

  Future<bool> _completa(GoogleSignInAccount conto) async {
    final autenticazione = await conto.authentication;
    final idToken = autenticazione.idToken;
    if (idToken == null) {
      throw AmiciErrore('Google non ha restituito il token di accesso. Controlla l\'ID client e lo SHA-1 in Firebase.');
    }
    final ripristinato = await FirestoreRest.istanza.collegaGoogle(idToken, email: conto.email);
    if (ripristinato) await _ripristinaProfilo();
    return ripristinato;
  }

  /// Dopo il passaggio a un profilo esistente, recupera nome e codice amico.
  Future<void> _ripristinaProfilo() async {
    final r = FirestoreRest.istanza;
    final uid = r.uid;
    final prefs = await SharedPreferences.getInstance();
    if (uid == null) return;
    await prefs.setString('amici_uid', uid);
    final d = await r.leggi('utenti/$uid');
    if (d != null && d['nome'] is String && d['codice'] is String) {
      await prefs.setString('amici_nome', d['nome'] as String);
      await prefs.setString('amici_codice', d['codice'] as String);
    } else {
      await prefs.remove('amici_nome');
      await prefs.remove('amici_codice');
    }
  }

  Future<void> esci() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    await FirestoreRest.istanza.esciLocale();
  }
}
