import 'dart:convert';
import 'package:http/http.dart' as http;

/// Client minimale per l'API di Google Gemini (livello gratuito, modello
/// Flash). Manda l'intera cronologia della chat a ogni richiesta perché
/// l'API è stateless.
class GeminiService {
  static Future<String> generaRisposta({
    required String apiKey,
    required List<Map<String, String>> cronologia,
    String? istruzioniSistema,
  }) async {
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash:generateContent',
    );

    final contents = cronologia
        .map((m) => {
              'role': m['ruolo'],
              'parts': [
                {'text': m['testo']},
              ],
            })
        .toList();

    final corpo = <String, dynamic>{'contents': contents};
    if (istruzioniSistema != null) {
      corpo['systemInstruction'] = {
        'parts': [
          {'text': istruzioniSistema},
        ],
      };
    }

    http.Response risposta;
    try {
      risposta = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'x-goog-api-key': apiKey,
        },
        body: jsonEncode(corpo),
      );
    } catch (e) {
      throw Exception('Connessione fallita: controlla la connessione internet del telefono. ($e)');
    }

    if (risposta.statusCode != 200) {
      // Messaggio leggibile invece del solo codice, per capire subito cosa
      // non va (chiave sbagliata, quota finita, richiesta malformata...).
      String dettaglio = risposta.body;
      try {
        final errore = jsonDecode(risposta.body) as Map<String, dynamic>;
        dettaglio = (errore['error']?['message'] as String?) ?? risposta.body;
      } catch (_) {
        // il corpo non era JSON, teniamo il testo grezzo
      }
      throw Exception('Errore Gemini ${risposta.statusCode}: $dettaglio');
    }

    final dati = jsonDecode(risposta.body) as Map<String, dynamic>;
    final candidati = dati['candidates'] as List?;
    if (candidati == null || candidati.isEmpty) {
      throw Exception('Nessuna risposta dal modello (possibile blocco per sicurezza sui contenuti)');
    }
    final parti = (candidati.first as Map<String, dynamic>)['content']?['parts'] as List?;
    if (parti == null || parti.isEmpty) {
      throw Exception('Risposta vuota dal modello');
    }
    return (parti.first as Map<String, dynamic>)['text'] as String? ?? 'Nessuna risposta ricevuta.';
  }
}
