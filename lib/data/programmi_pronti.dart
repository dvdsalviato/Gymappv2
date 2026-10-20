import 'catalogo_esercizi.dart';

/// Programmi di allenamento pronti da aggiungere alle proprie schede.
/// Le ripetizioni indicate sono il valore da raggiungere in tutte le serie
/// (la progressione di carico si basa su quello); per gli esercizi a tempo
/// il numero è in secondi.

class EsercizioProgramma {
  final String nome;
  final int serie;
  final int rep;
  final int riposo;

  /// Stesso numero in più esercizi di fila = superset.
  final int superset;
  const EsercizioProgramma(this.nome, this.serie, this.rep, this.riposo, [this.superset = 0]);
}

class GiornoProgramma {
  final String nome;
  final List<EsercizioProgramma> esercizi;
  const GiornoProgramma(this.nome, this.esercizi);
}

class Programma {
  final String id;
  final String nome;
  final String descrizione;
  final String livello; // Principiante, Intermedio, Avanzato
  final String obiettivo; // Generale, Forza, Massa
  final String attrezzatura; // Palestra, Manubri, Corpo libero
  final List<int> giorni; // allenamenti a settimana adatti
  final List<GiornoProgramma> schede;
  const Programma({
    required this.id,
    required this.nome,
    required this.descrizione,
    required this.livello,
    required this.obiettivo,
    required this.attrezzatura,
    required this.giorni,
    required this.schede,
  });

  int get numeroEsercizi => schede.fold(0, (a, s) => a + s.esercizi.length);
}

/// Gli esercizi di un giorno nel formato che serve per crearli nel database
/// (categoria e "a tempo" si ricavano dal catalogo).
List<Map<String, Object?>> eserciziPerDatabase(GiornoProgramma giorno) {
  final risultato = <Map<String, Object?>>[];
  for (final e in giorno.esercizi) {
    EsercizioCatalogo? voce;
    for (final c in catalogoEsercizi) {
      if (c.nome == e.nome) {
        voce = c;
        break;
      }
    }
    risultato.add({
      'nome': e.nome,
      'serie': e.serie,
      'rep': e.rep,
      'riposo': e.riposo,
      'categoria': voce?.categoria ?? 'Altro',
      'aTempo': (voce?.durataSecondi ?? 0) > 0,
      'superset': e.superset,
    });
  }
  return risultato;
}

const List<Programma> programmiPronti = [
  Programma(
    id: 'fullbody3',
    nome: 'Full Body 3 giorni',
    descrizione: 'Due schede da alternare (A, B, A… poi B, A, B…) in tre allenamenti a settimana. '
        'Il punto di partenza ideale: movimenti di base, poco tempo, buoni risultati.',
    livello: 'Principiante',
    obiettivo: 'Generale',
    attrezzatura: 'Palestra',
    giorni: [3],
    schede: [
      GiornoProgramma('Full Body A', [
        EsercizioProgramma('Squat con bilanciere', 3, 8, 150),
        EsercizioProgramma('Panca piana con manubri', 3, 10, 120),
        EsercizioProgramma('Rematore con manubrio', 3, 10, 90),
        EsercizioProgramma('Shoulder press con manubri', 2, 10, 90),
        EsercizioProgramma('Plank', 3, 30, 60),
      ]),
      GiornoProgramma('Full Body B', [
        EsercizioProgramma('Stacco rumeno', 3, 10, 150),
        EsercizioProgramma('Chest press macchina', 3, 10, 90),
        EsercizioProgramma('Lat machine avanti', 3, 10, 90),
        EsercizioProgramma('Leg press', 3, 12, 120),
        EsercizioProgramma('Curl con manubri alternato', 2, 12, 60, 1),
        EsercizioProgramma('Push down ai cavi (corda)', 2, 12, 60, 1),
      ]),
    ],
  ),
  Programma(
    id: 'fullbody2',
    nome: 'Minimo efficace 2 giorni',
    descrizione: 'Se riesci ad allenarti solo due volte a settimana: due schede complete con i fondamentali. '
        'Meglio poco ma costante.',
    livello: 'Principiante',
    obiettivo: 'Generale',
    attrezzatura: 'Palestra',
    giorni: [2],
    schede: [
      GiornoProgramma('Minimo A', [
        EsercizioProgramma('Squat con bilanciere', 3, 8, 150),
        EsercizioProgramma('Panca piana con bilanciere', 3, 8, 150),
        EsercizioProgramma('Rematore con bilanciere', 3, 8, 120),
        EsercizioProgramma('Plank', 3, 40, 60),
      ]),
      GiornoProgramma('Minimo B', [
        EsercizioProgramma('Stacco rumeno', 3, 8, 150),
        EsercizioProgramma('Military press con bilanciere', 3, 8, 120),
        EsercizioProgramma('Trazioni assistite (macchina)', 3, 8, 120),
        EsercizioProgramma('Affondi con manubri', 2, 10, 90),
        EsercizioProgramma('Cable crunch (crunch ai cavi)', 3, 12, 60),
      ]),
    ],
  ),
  Programma(
    id: 'upperlower4',
    nome: 'Upper / Lower 4 giorni',
    descrizione: 'Parte alta e parte bassa, ciascuna due volte a settimana. '
        'Ottimo equilibrio tra frequenza e recupero per chi ha già qualche mese di allenamento.',
    livello: 'Intermedio',
    obiettivo: 'Massa',
    attrezzatura: 'Palestra',
    giorni: [4],
    schede: [
      GiornoProgramma('Upper A', [
        EsercizioProgramma('Panca piana con bilanciere', 4, 8, 150),
        EsercizioProgramma('Rematore con bilanciere', 4, 8, 120),
        EsercizioProgramma('Shoulder press con manubri', 3, 10, 90),
        EsercizioProgramma('Lat machine avanti', 3, 10, 90),
        EsercizioProgramma('Curl con bilanciere EZ', 3, 12, 60, 1),
        EsercizioProgramma('Push down ai cavi (corda)', 3, 12, 60, 1),
      ]),
      GiornoProgramma('Lower A', [
        EsercizioProgramma('Squat con bilanciere', 4, 8, 180),
        EsercizioProgramma('Stacco rumeno', 3, 10, 150),
        EsercizioProgramma('Leg press', 3, 12, 120),
        EsercizioProgramma('Leg curl sdraiato', 3, 12, 75),
        EsercizioProgramma('Calf raise in piedi', 4, 12, 60),
      ]),
      GiornoProgramma('Upper B', [
        EsercizioProgramma('Panca inclinata con manubri', 4, 10, 120),
        EsercizioProgramma('Trazioni presa larga', 4, 8, 150),
        EsercizioProgramma('Rematore ai cavi seduto', 3, 12, 90),
        EsercizioProgramma('Alzate laterali con manubri', 3, 15, 60),
        EsercizioProgramma('Face pull', 3, 15, 60),
        EsercizioProgramma('Croci ai cavi (cable crossover)', 3, 12, 75),
      ]),
      GiornoProgramma('Lower B', [
        EsercizioProgramma('Stacco da terra', 3, 5, 180),
        EsercizioProgramma('Squat bulgaro', 3, 10, 120),
        EsercizioProgramma('Hip thrust', 3, 10, 120),
        EsercizioProgramma('Leg extension', 3, 12, 75),
        EsercizioProgramma('Calf raise seduto', 4, 15, 60),
        EsercizioProgramma('Cable crunch (crunch ai cavi)', 3, 12, 60),
      ]),
    ],
  ),
  Programma(
    id: 'ppl',
    nome: 'Push Pull Legs',
    descrizione: 'Spinte, tirate e gambe in tre schede. Tre allenamenti a settimana, '
        'oppure sei se lo ripeti due volte (per chi recupera bene).',
    livello: 'Intermedio',
    obiettivo: 'Massa',
    attrezzatura: 'Palestra',
    giorni: [3, 6],
    schede: [
      GiornoProgramma('Push', [
        EsercizioProgramma('Panca piana con bilanciere', 4, 8, 150),
        EsercizioProgramma('Shoulder press con manubri', 3, 10, 90),
        EsercizioProgramma('Panca inclinata con manubri', 3, 10, 90),
        EsercizioProgramma('Alzate laterali con manubri', 4, 15, 60),
        EsercizioProgramma('Push down ai cavi (corda)', 3, 12, 60),
        EsercizioProgramma('Estensioni sopra la testa ai cavi', 3, 12, 60),
      ]),
      GiornoProgramma('Pull', [
        EsercizioProgramma('Trazioni presa larga', 4, 8, 150),
        EsercizioProgramma('Rematore con bilanciere', 4, 8, 120),
        EsercizioProgramma('Lat machine presa stretta', 3, 10, 90),
        EsercizioProgramma('Face pull', 3, 15, 60),
        EsercizioProgramma('Curl con bilanciere EZ', 3, 10, 60),
        EsercizioProgramma('Curl a martello', 3, 12, 60),
      ]),
      GiornoProgramma('Legs', [
        EsercizioProgramma('Squat con bilanciere', 4, 8, 180),
        EsercizioProgramma('Stacco rumeno', 3, 10, 150),
        EsercizioProgramma('Leg press', 3, 12, 120),
        EsercizioProgramma('Leg curl sdraiato', 3, 12, 75),
        EsercizioProgramma('Calf raise in piedi', 4, 12, 60),
        EsercizioProgramma('Sollevamento gambe alla sbarra', 3, 12, 60),
      ]),
    ],
  ),
  Programma(
    id: 'cinqueper5',
    nome: '5×5 Forza',
    descrizione: 'Il classico per costruire forza: pochi esercizi, cinque serie da cinque, '
        'carico che sale a ogni allenamento. Alterna le schede A e B su tre giorni.',
    livello: 'Principiante',
    obiettivo: 'Forza',
    attrezzatura: 'Palestra',
    giorni: [3],
    schede: [
      GiornoProgramma('5x5 A', [
        EsercizioProgramma('Squat con bilanciere', 5, 5, 180),
        EsercizioProgramma('Panca piana con bilanciere', 5, 5, 180),
        EsercizioProgramma('Rematore con bilanciere', 5, 5, 180),
      ]),
      GiornoProgramma('5x5 B', [
        EsercizioProgramma('Squat con bilanciere', 5, 5, 180),
        EsercizioProgramma('Military press con bilanciere', 5, 5, 150),
        EsercizioProgramma('Stacco da terra', 1, 5, 240),
      ]),
    ],
  ),
  Programma(
    id: 'split5',
    nome: 'Split 5 giorni',
    descrizione: 'Un gruppo muscolare al giorno: petto, schiena, gambe, spalle e braccia. '
        'Molto volume per ogni muscolo, richiede tempo e buon recupero.',
    livello: 'Avanzato',
    obiettivo: 'Massa',
    attrezzatura: 'Palestra',
    giorni: [5],
    schede: [
      GiornoProgramma('Petto', [
        EsercizioProgramma('Panca piana con bilanciere', 4, 8, 150),
        EsercizioProgramma('Panca inclinata con manubri', 4, 10, 120),
        EsercizioProgramma('Croci ai cavi (cable crossover)', 3, 12, 75),
        EsercizioProgramma('Dip alle parallele (petto)', 3, 10, 90),
        EsercizioProgramma('Pec deck', 3, 12, 60),
      ]),
      GiornoProgramma('Schiena', [
        EsercizioProgramma('Trazioni presa larga', 4, 8, 150),
        EsercizioProgramma('Rematore con bilanciere', 4, 8, 120),
        EsercizioProgramma('Lat machine presa stretta', 3, 10, 90),
        EsercizioProgramma('Rematore ai cavi seduto', 3, 12, 90),
        EsercizioProgramma('Straight arm pulldown', 3, 12, 60),
        EsercizioProgramma('Shrug con manubri', 3, 12, 60),
      ]),
      GiornoProgramma('Gambe', [
        EsercizioProgramma('Squat con bilanciere', 4, 8, 180),
        EsercizioProgramma('Leg press', 4, 12, 120),
        EsercizioProgramma('Stacco rumeno', 3, 10, 120),
        EsercizioProgramma('Leg extension', 3, 15, 75),
        EsercizioProgramma('Leg curl sdraiato', 3, 12, 75),
        EsercizioProgramma('Calf raise in piedi', 4, 12, 60),
      ]),
      GiornoProgramma('Spalle', [
        EsercizioProgramma('Military press con bilanciere', 4, 8, 150),
        EsercizioProgramma('Alzate laterali con manubri', 4, 15, 60),
        EsercizioProgramma('Alzate posteriori (rear delt fly)', 3, 15, 60),
        EsercizioProgramma('Face pull', 3, 15, 60),
        EsercizioProgramma('Shrug con bilanciere', 3, 12, 60),
      ]),
      GiornoProgramma('Braccia', [
        EsercizioProgramma('Curl con bilanciere EZ', 4, 10, 75, 1),
        EsercizioProgramma('French press con bilanciere EZ', 4, 10, 75, 1),
        EsercizioProgramma('Curl a martello', 3, 12, 60, 2),
        EsercizioProgramma('Push down ai cavi (corda)', 3, 12, 60, 2),
        EsercizioProgramma('Cable crunch (crunch ai cavi)', 3, 15, 60),
      ]),
    ],
  ),
  Programma(
    id: 'manubri3',
    nome: 'Manubri a casa 3 giorni',
    descrizione: 'Servono solo dei manubri (e una panca, se ce l\'hai). '
        'Due schede da alternare, adatte anche a chi si allena in casa.',
    livello: 'Principiante',
    obiettivo: 'Generale',
    attrezzatura: 'Manubri',
    giorni: [3],
    schede: [
      GiornoProgramma('Manubri A', [
        EsercizioProgramma('Goblet squat', 4, 12, 90),
        EsercizioProgramma('Floor press', 4, 10, 90),
        EsercizioProgramma('Rematore con manubrio', 4, 10, 90),
        EsercizioProgramma('Shoulder press con manubri', 3, 10, 75),
        EsercizioProgramma('Curl con manubri alternato', 3, 12, 60, 1),
        EsercizioProgramma('Estensioni sopra la testa con manubrio', 3, 12, 60, 1),
      ]),
      GiornoProgramma('Manubri B', [
        EsercizioProgramma('Stacco rumeno con manubri', 4, 10, 90),
        EsercizioProgramma('Squat bulgaro', 3, 10, 90),
        EsercizioProgramma('Piegamenti (push-up)', 3, 15, 60),
        EsercizioProgramma('Rematore con due manubri', 3, 12, 75),
        EsercizioProgramma('Alzate laterali con manubri', 3, 15, 60),
        EsercizioProgramma('Plank', 3, 40, 45),
      ]),
    ],
  ),
  Programma(
    id: 'corpolibero3',
    nome: 'Corpo libero 3 giorni',
    descrizione: 'Nessun attrezzo: solo il tuo peso. Due schede da alternare, '
        'per cominciare ovunque tu sia.',
    livello: 'Principiante',
    obiettivo: 'Generale',
    attrezzatura: 'Corpo libero',
    giorni: [3],
    schede: [
      GiornoProgramma('Corpo libero A', [
        EsercizioProgramma('Piegamenti (push-up)', 4, 12, 60),
        EsercizioProgramma('Squat a corpo libero', 4, 15, 60),
        EsercizioProgramma('Affondi inversi', 3, 10, 60),
        EsercizioProgramma('Plank', 3, 40, 45),
      ]),
      GiornoProgramma('Corpo libero B', [
        EsercizioProgramma('Pike push-up', 3, 8, 75),
        EsercizioProgramma('Ponte glutei', 4, 15, 60),
        EsercizioProgramma('Piegamenti piedi rialzati', 3, 10, 60),
        EsercizioProgramma('Dead bug', 3, 12, 45),
        EsercizioProgramma('Wall sit', 3, 40, 60),
      ]),
    ],
  ),
];
