import 'dart:convert';
import 'package:http/http.dart' as http;

/// Client minimale per l'API di Google Gemini (livello gratuito).
/// Manda l'intera cronologia della chat a ogni richiesta perché l'API è
/// stateless.
///
/// Il modello principale è Gemini 3.8 Flash. Se è sovraccarico (503), insiste
/// qualche volta con pause crescenti e poi passa ai modelli di riserva, tutti
/// della famiglia 3.x. I modelli che non esistono (404) vengono saltati.
class GeminiService {
  static const _modelli = [
    'gemini-3.8-flash',
    'gemini-3.6-flash',
    'gemini-3.5-flash',
    'gemini-3.5-flash-lite',
    'gemini-3.1-flash-lite',
  ];

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
    // Pensiero "low": risposte più veloci e meno soggette a sovraccarico.
    final corpoConPensiero = <String, dynamic>{
      ...corpo,
      'generationConfig': {
        'thinkingConfig': {'thinkingLevel': 'low'},
      },
    };

    String ultimoErrore = 'nessun modello disponibile';

    for (final modello in _modelli) {
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$modello:generateContent',
      );
      final tentativi = modello == _modelli.first ? 3 : 2;
      var conPensiero = true;

      for (var tentativo = 1; tentativo <= tentativi; tentativo++) {
        http.Response risposta;
        try {
          risposta = await http
              .post(
                uri,
                headers: {
                  'Content-Type': 'application/json',
                  'x-goog-api-key': apiKey,
                },
                body: jsonEncode(conPensiero ? corpoConPensiero : corpo),
              )
              .timeout(const Duration(seconds: 45));
        } catch (e) {
          throw Exception('Connessione fallita: controlla la connessione internet del telefono. ($e)');
        }

        if (risposta.statusCode == 200) {
          return _estraiTesto(risposta.body);
        }

        final dettaglio = _dettaglioErrore(risposta.body);
        ultimoErrore = 'Errore Gemini ${risposta.statusCode} ($modello): $dettaglio';

        // Il modello non accetta l'impostazione del pensiero: riprova senza.
        if (risposta.statusCode == 400 && conPensiero) {
          conPensiero = false;
          tentativo--;
          continue;
        }
        // Chiave sbagliata o richiesta non valida: inutile riprovare.
        if (risposta.statusCode == 400 || risposta.statusCode == 401 || risposta.statusCode == 403) {
          throw Exception(ultimoErrore);
        }
        // Modello inesistente o quota finita su questo modello: passa al successivo.
        if (risposta.statusCode == 404 || risposta.statusCode == 429) break;
        // 500/503 e simili: pausa crescente e nuovo tentativo.
        if (tentativo < tentativi) {
          await Future.delayed(Duration(seconds: 2 * tentativo));
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
    // Con il pensiero attivo possono esserci più parti: prendi quelle di testo.
    final testi = <String>[];
    for (final p in parti) {
      if (p is Map<String, dynamic> && p['thought'] != true && p['text'] is String) {
        testi.add(p['text'] as String);
      }
    }
    return testi.isEmpty ? 'Nessuna risposta ricevuta.' : testi.join();
  }
}
