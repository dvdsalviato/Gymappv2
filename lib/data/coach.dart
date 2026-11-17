import 'catalogo_esercizi.dart';
import 'immagini_esercizi.dart';
import 'progressione.dart';

/// Coach: legge i tuoi allenamenti e dà consigli concreti, senza internet.
/// Tutto si basa su regole semplici e dichiarate (niente "magia"):
/// - stallo: massimale stimato fermo da ~3 settimane;
/// - scarico: tante settimane di fila e prestazioni in calo;
/// - volume: serie a settimana per muscolo previste dalle tue schede (a
///   rotazione, col tuo obiettivo settimanale) fuori dalla zona 10–20;
/// - progressi da celebrare e costanza rispetto al tuo obiettivo.

enum TipoConsiglio { stallo, scarico, volumeBasso, volumeAlto, progresso, costanza, inizio }

class ConsiglioCoach {
  final TipoConsiglio tipo;
  final String titolo;
  final String testo;

  /// Più alto = più importante (si mostra prima).
  final int priorita;

  /// Esercizio a cui si riferisce (per aprirne lo storico), se c'è.
  final String? esercizio;

  const ConsiglioCoach(this.tipo, this.titolo, this.testo, this.priorita, {this.esercizio});

  bool get positivo => tipo == TipoConsiglio.progresso;
}

/// Una serie registrata, come la usa il coach.
class SerieCoach {
  final String nome;
  final String categoria;
  final double carico;
  final int rep;
  final DateTime data;
  const SerieCoach(this.nome, this.categoria, this.carico, this.rep, this.data);
}

class DatiCoach {
  final List<SerieCoach> serie; // dalla più vecchia
  final Set<DateTime> presenze; // giorni di allenamento (a mezzanotte)
  /// Serie previste da ogni scheda attiva, per gruppo muscolare.
  final List<Map<String, int>> seriePerScheda;
  final Set<String> eserciziNelleSchede; // nomi (minuscoli) già nelle schede
  final int obiettivoSettimanale;
  final DateTime oggi;

  const DatiCoach({
    required this.serie,
    required this.presenze,
    required this.seriePerScheda,
    required this.eserciziNelleSchede,
    required this.obiettivoSettimanale,
    required this.oggi,
  });
}

double _stima(double carico, int rep) => rep <= 1 ? carico : carico * (1 + rep / 30);
DateTime _giorno(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime _lunedi(DateTime d) => _giorno(d).subtract(Duration(days: d.weekday - 1));

const _gruppiConVolume = ['Petto', 'Schiena', 'Gambe', 'Spalle', 'Bicipiti', 'Tricipiti'];

/// Tutti i consigli, dal più importante.
List<ConsiglioCoach> analizza(DatiCoach d) {
  final consigli = <ConsiglioCoach>[];
  final oggi = _giorno(d.oggi);

  if (d.serie.isEmpty && d.presenze.isEmpty) {
    return const [
      ConsiglioCoach(
        TipoConsiglio.inizio,
        'Il coach ti sta conoscendo',
        'Registra i primi allenamenti: dopo 2–3 settimane qui trovi consigli su misura '
            '(stalli, volume per muscolo, settimane di scarico).',
        1,
      ),
    ];
  }

  // Massimale stimato migliore per esercizio e per giorno (serve a confrontare
  // serie con carichi e ripetizioni diversi), e la serie vera che lo ha dato.
  final perGiorno = <String, Map<DateTime, double>>{};
  final serieMigliore = <String, Map<DateTime, SerieCoach>>{};
  final repRecenti = <String, List<int>>{};
  for (final s in d.serie) {
    final g = _giorno(s.data);
    final mappa = perGiorno.putIfAbsent(s.nome, () => {});
    final stima = _stima(s.carico, s.rep);
    if (stima > (mappa[g] ?? 0)) {
      mappa[g] = stima;
      serieMigliore.putIfAbsent(s.nome, () => {})[g] = s;
    }
    if (oggi.difference(g).inDays <= 21) repRecenti.putIfAbsent(s.nome, () => []).add(s.rep);
  }

  // ---- Stallo e progressi ----
  final stalli = <(ConsiglioCoach, int)>[];
  final progressi = <(ConsiglioCoach, double)>[];
  perGiorno.forEach((nome, giorni) {
    double migliore(int da, int a) {
      var m = 0.0;
      giorni.forEach((g, v) {
        final eta = oggi.difference(g).inDays;
        if (eta >= da && eta <= a && v > m) m = v;
      });
      return m;
    }

    // La serie vera (kg × ripetizioni) migliore nella finestra, da mostrare.
    String serieVera(int da, int a) {
      SerieCoach? m;
      var stimaM = 0.0;
      giorni.forEach((g, v) {
        final eta = oggi.difference(g).inDays;
        if (eta >= da && eta <= a && v > stimaM) {
          stimaM = v;
          m = serieMigliore[nome]?[g];
        }
      });
      final s = m;
      return s == null ? '-' : '${formatKg(s.carico)} kg × ${s.rep}';
    }

    int sessioni(int da, int a) =>
        giorni.keys.where((g) => oggi.difference(g).inDays >= da && oggi.difference(g).inDays <= a).length;

    final recenti = sessioni(0, 21);
    final prima = sessioni(22, 42);
    if (recenti >= 2 && prima >= 2) {
      final ora = migliore(0, 21);
      final allora = migliore(22, 42);
      if (allora > 0 && ora <= allora * 1.01) {
        final reps = repRecenti[nome] ?? const <int>[];
        final media = reps.isEmpty ? 8 : reps.reduce((a, b) => a + b) / reps.length;
        final cambio = media >= 8
            ? 'passa a 5–6 ripetizioni con un carico più alto'
            : 'passa a 10–12 ripetizioni con un carico più leggero';
        stalli.add((
          ConsiglioCoach(
            TipoConsiglio.stallo,
            '$nome: fermo da circa 3 settimane',
            'Miglior serie delle ultime 3 settimane: ${serieVera(0, 21)}. Nelle 3 prima: ${serieVera(22, 42)}. '
                'Cambia stimolo per 2–3 settimane: $cambio, oppure aggiungi una serie. Poi torna al solito schema.',
            3,
            esercizio: nome,
          ),
          recenti + prima,
        ));
      }
    }

    final mese = migliore(0, 30);
    final precedente = migliore(31, 90);
    if (mese > 0 && precedente > 0 && mese >= precedente * 1.05) {
      final aumento = (mese - precedente) / precedente * 100;
      progressi.add((
        ConsiglioCoach(
          TipoConsiglio.progresso,
          '$nome: stai migliorando',
          'Miglior serie dell\'ultimo mese: ${serieVera(0, 30)} (prima: ${serieVera(31, 90)}), '
              'circa +${aumento.toStringAsFixed(0)}% di forza. Il lavoro sta pagando: continua così.',
          1,
          esercizio: nome,
        ),
        aumento,
      ));
    }
  });
  stalli.sort((a, b) => b.$2.compareTo(a.$2));
  consigli.addAll(stalli.take(2).map((e) => e.$1));
  progressi.sort((a, b) => b.$2.compareTo(a.$2));
  consigli.addAll(progressi.take(2).map((e) => e.$1));

  // ---- Scarico ----
  final settimane = {for (final g in d.presenze) _lunedi(g)};
  var w = _lunedi(oggi);
  if (!settimane.contains(w)) w = w.subtract(const Duration(days: 7));
  var diFila = 0;
  while (settimane.contains(w)) {
    diFila++;
    w = w.subtract(const Duration(days: 7));
  }
  // Calo: esercizi in cui l'ultima volta è andata peggio della precedente (>3%).
  var inCalo = 0;
  perGiorno.forEach((nome, giorni) {
    final date = giorni.keys.where((g) => oggi.difference(g).inDays <= 14).toList()..sort();
    if (date.length < 2) return;
    final ultima = giorni[date.last]!;
    final penultima = giorni[date[date.length - 2]]!;
    if (ultima < penultima * 0.97) inCalo++;
  });
  if ((diFila >= 6 && inCalo >= 3) || diFila >= 8) {
    consigli.add(ConsiglioCoach(
      TipoConsiglio.scarico,
      'È il momento di una settimana di scarico',
      '${diFila >= 8 ? 'Sei a $diFila settimane di fila' : 'Dopo $diFila settimane di fila $inCalo esercizi sono in calo'}. '
          'Per una settimana fai metà delle serie con gli stessi carichi (o il 10% in meno), poi riprendi: '
          'di solito si torna più forti.',
      inCalo >= 3 ? 4 : 2,
    ));
  }

  // ---- Volume per muscolo (previsto dalle schede) ----
  // Le schede si fanno a rotazione: a settimana si fanno "obiettivo" sedute,
  // quindi in media ogni scheda conta obiettivo / numero di schede volte.
  final schede = d.seriePerScheda.where((m) => m.isNotEmpty).toList();
  if (schede.isNotEmpty && d.obiettivoSettimanale > 0) {
    final fattore = d.obiettivoSettimanale / schede.length;
    final bassi = <(String, double)>[];
    final rotazione = '${schede.length == 1 ? 'la tua scheda' : 'le tue ${schede.length} schede a rotazione'} '
        'e ${d.obiettivoSettimanale} allenament${d.obiettivoSettimanale == 1 ? 'o' : 'i'} a settimana';
    for (final gruppo in _gruppiConVolume) {
      final totale = schede.fold<int>(0, (a, m) => a + (m[gruppo] ?? 0));
      if (totale == 0) continue;
      final settimanali = totale * fattore;
      if (settimanali < 10) {
        bassi.add((gruppo, settimanali));
      } else if (settimanali > 25) {
        consigli.add(ConsiglioCoach(
          TipoConsiglio.volumeAlto,
          '$gruppo: forse troppo volume',
          'Con $rotazione fai circa ${settimanali.round()} serie a settimana. Oltre le 20–25 il recupero '
              'diventa difficile: se senti fatica o i carichi calano, togli qualche serie.',
          2,
        ));
      }
    }
    bassi.sort((a, b) => a.$2.compareTo(b.$2));
    for (final (gruppo, n) in bassi.take(2)) {
      final proposta = _esercizioDaProporre(gruppo, d.eserciziNelleSchede);
      consigli.add(ConsiglioCoach(
        TipoConsiglio.volumeBasso,
        '$gruppo: poche serie',
        'Con $rotazione fai circa ${n.round()} serie a settimana: per crescere ne servono almeno 10. '
            '${proposta == null ? 'Aggiungi 1 esercizio da 3–4 serie' : 'Aggiungi "$proposta" (3–4 serie)'} '
            'o una serie in più agli esercizi che già fai.',
        n < 5 ? 3 : 2,
        esercizio: proposta,
      ));
    }
  }

  // ---- Costanza della settimana ----
  final questaSettimana = d.presenze.where((g) => !g.isBefore(_lunedi(oggi))).length;
  final mancano = d.obiettivoSettimanale - questaSettimana;
  final giorniRimasti = 7 - oggi.weekday; // dopo oggi
  if (mancano > 0 && oggi.weekday >= 4) {
    consigli.add(ConsiglioCoach(
      TipoConsiglio.costanza,
      'Obiettivo della settimana: $questaSettimana su ${d.obiettivoSettimanale}',
      mancano > giorniRimasti + 1
          ? 'Quest\'obiettivo ormai è difficile: fai quello che puoi, conta la continuità.'
          : 'Ne ${mancano == 1 ? 'manca 1' : 'mancano $mancano'}: oggi è un buon giorno per allenarti.',
      2,
    ));
  } else if (mancano <= 0 && questaSettimana > 0) {
    consigli.add(ConsiglioCoach(
      TipoConsiglio.progresso,
      'Obiettivo settimanale raggiunto',
      '$questaSettimana allenamenti su ${d.obiettivoSettimanale}. Ottimo: recupera bene.',
      1,
    ));
  }

  consigli.sort((a, b) => b.priorita.compareTo(a.priorita));
  if (consigli.isEmpty) {
    consigli.add(const ConsiglioCoach(
      TipoConsiglio.progresso,
      'Tutto in ordine',
      'Nessuno stallo, volume nella zona giusta, costanza regolare. Continua così.',
      1,
    ));
  }
  return consigli;
}

/// Un esercizio del catalogo per [gruppo] che non hai già nelle schede
/// (preferibilmente con l'immagine, così lo vedi eseguire).
String? _esercizioDaProporre(String gruppo, Set<String> giaPresenti) {
  String? senzaImmagine;
  for (final e in catalogoEsercizi) {
    if (e.categoria != gruppo || e.durataSecondi > 0) continue;
    if (giaPresenti.contains(e.nome.toLowerCase())) continue;
    if (immagineEsercizio(e.nome) != null) return e.nome;
    senzaImmagine ??= e.nome;
  }
  return senzaImmagine;
}
