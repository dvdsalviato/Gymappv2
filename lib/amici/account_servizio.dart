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

  Future<StatoAccount> stato() async {
    final prefs = await SharedPreferences.getInstance();
    return StatoAccount(prefs.getBool('amici_google') ?? false, prefs.getString('amici_email') ?? '');
  }

  /// Accede con Google. Restituisce true se l'account era già stato usato e
  /// questo telefono è passato al profilo esistente (ripristino).
  Future<bool> accedi() async {
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
      if (testo.toLowerCase().contains('cancel')) throw AmiciErrore('Accesso annullato.');
      throw AmiciErrore('Accesso con Google non riuscito: $testo');
    }
    final conto = account;
    if (conto == null) throw AmiciErrore('Accesso non riuscito.');
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
