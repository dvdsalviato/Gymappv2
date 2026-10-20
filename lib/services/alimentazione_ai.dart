import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/alimenti.dart';
import '../data/menu_settimanale.dart';
import 'gemini_service.dart';

/// Cosa è uscito dalla lettura di una frase sui pasti.
class RisultatoPasto {
  final List<VoceCibo> voci;

  /// Vero se la frase è stata letta dall'AI, falso se dal lettore semplice.
  final bool daAi;
  final String? avviso;
  const RisultatoPasto(this.voci, this.daAi, this.avviso);
}

const String _istruzioniPasto = '''
Trasformi la descrizione di un pasto in una lista di alimenti con le quantità.
Rispondi SOLO con un array JSON, senza testo prima o dopo e senza ```.
Ogni elemento ha questa forma:
{"nome": "petto di pollo", "quantita": 120, "unita": "g", "stato": "crudo", "kcal100": 110, "p100": 23, "c100": 0, "g100": 1.6}
- "nome": nome semplice e generico in italiano (per esempio "petto di pollo", "yogurt greco", "birra", "pasta", "riso").
- "quantita": totale in grammi o millilitri, già moltiplicato per il numero di porzioni.
- "unita": "g" oppure "ml" (ml per birra, vino, latte, succhi e altre bevande).
- "stato": "crudo" o "cotto" se è specificato o se ha senso, altrimenti null.
- "kcal100", "p100", "c100", "g100": calorie, proteine, carboidrati e grassi per 100 g (o 100 ml) dell'alimento così come viene mangiato, stimati al meglio.
Se le quantità non sono in grammi, converti con porzioni tipiche italiane: 1 uovo = 55 g; un vasetto di yogurt = 125 g (yogurt greco 150 g);
birra piccola 200 ml, media 400 ml, grande 660 ml, lattina o bottiglia 330 ml; calice di vino 125 ml; fetta di pane 30 g;
cucchiaio di olio 10 g; cucchiaino di zucchero 5 g; mela 150 g; banana 120 g; espresso 30 ml.
Se la quantità non è indicata usa una porzione normale. Non aggiungere alimenti che non sono citati.
''';

/// Estrae il primo JSON (array o oggetto) da una risposta che può contenere altro testo.
dynamic estraiJson(String testo) {
  final t = testo.trim();
  final inizio = t.indexOf(RegExp(r'[\[{]'));
  if (inizio < 0) throw const FormatException('La risposta non contiene dati.');
  final chiusura = t[inizio] == '[' ? ']' : '}';
  final fine = t.lastIndexOf(chiusura);
  if (fine <= inizio) throw const FormatException('La risposta è incompleta.');
  return jsonDecode(t.substring(inizio, fine + 1));
}

List<VoceCibo> _vociDaJson(String risposta) {
  final json = estraiJson(risposta);
  final lista = json is List ? json : (json is Map ? json['alimenti'] : null);
  if (lista is! List) return [];
  final voci = <VoceCibo>[];
  for (final e in lista) {
    if (e is! Map) continue;
    final nome = '${e['nome'] ?? ''}'.trim();
    final quantita = (e['quantita'] as num?)?.toDouble() ?? 0;
    if (nome.isEmpty || quantita <= 0 || quantita > 5000) continue;
    final stato = e['stato'] is String ? e['stato'] as String : null;
    final alimento = trovaAlimento(nome, stato: stato);
    if (alimento != null) {
      voci.add(VoceCibo.daAlimento(alimento, quantita));
      continue;
    }
    final k = (e['kcal100'] as num?)?.toDouble() ?? 0;
    final unita = e['unita'] == 'ml' ? 'ml' : 'g';
    if (k > 0) {
      voci.add(VoceCibo(
        nome: nome,
        quantita: quantita,
        unita: unita,
        kcal100: k,
        p100: (e['p100'] as num?)?.toDouble() ?? 0,
        c100: (e['c100'] as num?)?.toDouble() ?? 0,
        g100: (e['g100'] as num?)?.toDouble() ?? 0,
        stima: true,
      ));
    } else {
      voci.add(VoceCibo(nome: nome, quantita: quantita, unita: unita, nonTrovato: true));
    }
  }
  return voci;
}

Future<String?> _chiaveGemini() async {
  final prefs = await SharedPreferences.getInstance();
  final k = prefs.getString('gemini_api_key');
  return (k == null || k.trim().isEmpty) ? null : k.trim();
}

/// Legge una frase come "120 g di pollo, una birra media e 2 yogurt greco".
/// Usa l'AI se hai la chiave Gemini, altrimenti (o se non risponde) il lettore semplice.
Future<RisultatoPasto> interpretaPasto(String testo) async {
  final chiave = await _chiaveGemini();
  if (chiave == null) {
    return RisultatoPasto(
      vociDaTestoLocale(testo),
      false,
      'Senza la chiave Gemini uso il lettore semplice: capisce frasi come "120 g pollo, 2 yogurt greco". Controlla bene i valori.',
    );
  }
  try {
    final risposta = await GeminiService.generaRisposta(
      apiKey: chiave,
      cronologia: [
        {'ruolo': 'user', 'testo': testo},
      ],
      istruzioniSistema: _istruzioniPasto,
    );
    final voci = _vociDaJson(risposta);
    if (voci.isNotEmpty) return RisultatoPasto(voci, true, null);
    throw const FormatException('Nessun alimento riconosciuto.');
  } catch (e) {
    final dettaglio = '$e'.length > 140 ? '${'$e'.substring(0, 140)}…' : '$e';
    return RisultatoPasto(
      vociDaTestoLocale(testo),
      false,
      'L\'AI non ha risposto ($dettaglio): ho usato il lettore semplice, controlla bene i valori.',
    );
  }
}

/// Chiede all'AI la struttura di un menu di 7 giorni usando solo gli alimenti
/// della tabella; le quantità le ricalcola poi l'app. Restituisce null se non
/// c'è la chiave o se la risposta non è utilizzabile.
Future<List<GiornoMenu>?> generaMenuConAi({
  required int pasti,
  required String tipoDieta,
  required String esclusioni,
}) async {
  final chiave = await _chiaveGemini();
  if (chiave == null) return null;
  final ammessi = [
    for (final a in alimenti)
      if (!alimentoEscluso(a, tipo: tipoDieta, esclusioni: esclusioni)) a.nome,
  ];
  if (ammessi.length < 20) return null;
  final nomi = nomiPasti(pasti);
  final richiesta = '''
Crea un menu di esempio di 7 giorni (da lunedì a domenica) con questi pasti al giorno: ${nomi.join(', ')}.
Usa SOLO gli alimenti di questa lista, scrivendone il nome ESATTAMENTE come in lista:
${ammessi.join('; ')}
Regole:
- Pranzo e cena devono avere una fonte di proteine, una di carboidrati, verdura e olio extravergine d'oliva per condire.
- Pasti semplici e realistici della cucina italiana; varia i giorni, niente giorni uguali.
- Quantità in grammi per un adulto (verranno ricalcolate).
- Tipo di dieta: $tipoDieta.${esclusioni.trim().isEmpty ? '' : ' Evita: $esclusioni.'}
Rispondi SOLO con JSON, senza altro testo, in questa forma:
{"giorni":[{"pasti":[{"nome":"Colazione","alimenti":[{"nome":"Yogurt greco (0% grassi)","g":200}]}]}]}
''';
  try {
    final risposta = await GeminiService.generaRisposta(
      apiKey: chiave,
      cronologia: [
        {'ruolo': 'user', 'testo': richiesta},
      ],
    );
    return giorniDaJsonAi(estraiJson(risposta), tipoDieta: tipoDieta, esclusioni: esclusioni);
  } catch (_) {
    return null;
  }
}
