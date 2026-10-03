import 'dart:convert';
import 'package:http/http.dart' as http;

/// Client minimale per l'API di Google Gemini (livello gratuito).
/// Manda l'intera cronologia della chat a ogni richiesta perché l'API è
/// stateless.
///
/// Quando un modello è sovraccarico (errore 503) o ha finito la quota (429)
/// riprova dopo una breve pausa e poi passa al modello successivo della
/// lista. I modelli che non esistono (404) vengono saltati.
class GeminiService {
  static const _modelli = [
    'gemini-3.8-flash',
    'gemini-2.5-flash',
    'gemini-2.5-flash-lite',
    'gemini-2.0-flash',
  ];

  static const _tentativiPerModello = 2;

  static Future<String> generaRisposta({
    required String apiKey,
    required List<Map<String, String>> cronologia,
    String? istruzioniSistema,
  }) async {
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
    final corpoJson = jsonEncode(corpo);

    String ultimoErrore = 'nessun modello disponibile';

    for (final modello in _modelli) {
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$modello:generateContent',
      );

      for (var tentativo = 1; tentativo <= _tentativiPerModello; tentativo++) {
        http.Response risposta;
        try {
          risposta = await http
              .post(
                uri,
                headers: {
                  'Content-Type': 'application/json',
                  'x-goog-api-key': apiKey,
                },
                body: corpoJson,
              )
              .timeout(const Duration(seconds: 40));
        } catch (e) {
          throw Exception('Connessione fallita: controlla la connessione internet del telefono. ($e)');
        }

        if (risposta.statusCode == 200) {
          return _estraiTesto(risposta.body);
        }

        final dettaglio = _dettaglioErrore(risposta.body);
        ultimoErrore = 'Errore Gemini ${risposta.statusCode} ($modello): $dettaglio';

        // Chiave sbagliata o richiesta non valida: inutile riprovare.
        if (risposta.statusCode == 400 || risposta.statusCode == 401 || risposta.statusCode == 403) {
          throw Exception(ultimoErrore);
        }
        // Modello inesistente: passa subito al successivo.
        if (risposta.statusCode == 404) break;
        // Quota finita su questo modello: prova un altro.
        if (risposta.statusCode == 429) break;
        // 500/503 e simili: breve pausa e secondo tentativo.
        if (tentativo < _tentativiPerModello) {
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    }

    throw Exception('$ultimoErrore\nProva di nuovo tra qualche minuto.');
  }

  static String _dettaglioErrore(String corpo) {
    try {
      final errore = jsonDecode(corpo) as Map<String, dynamic>;
      return (errore['error']?['message'] as String?) ?? corpo;
    } catch (_) {
      return corpo;
    }
  }

  static String _estraiTesto(String corpo) {
    final dati = jsonDecode(corpo) as Map<String, dynamic>;
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
