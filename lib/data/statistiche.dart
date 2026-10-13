import 'package:shared_preferences/shared_preferences.dart';
import '../db/database_helper.dart';
import 'muscoli.dart';

const chiaveObiettivoSettimanale = 'obiettivo_settimanale';
const obiettivoPredefinito = 3;

DateTime lunediDi(DateTime d) => DateTime(d.year, d.month, d.day - (d.weekday - 1));

/// Quanti giorni di allenamento ci sono nella settimana che inizia a [lunedi].
int contaSettimana(Set<DateTime> presenze, DateTime lunedi) {
  var n = 0;
  for (var i = 0; i < 7; i++) {
    if (presenze.contains(DateTime(lunedi.year, lunedi.month, lunedi.day + i))) n++;
  }
  return n;
}

/// Settimane consecutive in cui hai raggiunto l'obiettivo. La settimana in
/// corso conta se l'hai già raggiunto; se non ancora, non interrompe la serie.
int settimaneConsecutive(Set<DateTime> presenze, int obiettivo, DateTime oggi) {
  var lunedi = lunediDi(oggi);
  var serie = 0;
  if (contaSettimana(presenze, lunedi) >= obiettivo) serie++;
  for (var i = 0; i < 520; i++) {
    lunedi = DateTime(lunedi.year, lunedi.month, lunedi.day - 7);
    if (contaSettimana(presenze, lunedi) >= obiettivo) {
      serie++;
    } else {
      break;
    }
  }
  return serie;
}

/// Giorni consecutivi più lunghi con almeno un allenamento.
int giorniConsecutiviMax(Set<DateTime> presenze) {
  if (presenze.isEmpty) return 0;
  final ordinati = presenze.toList()..sort();
  var massimo = 1;
  var corrente = 1;
  for (var i = 1; i < ordinati.length; i++) {
    final prec = ordinati[i - 1];
    final atteso = DateTime(prec.year, prec.month, prec.day + 1);
    if (ordinati[i] == atteso) {
      corrente++;
      if (corrente > massimo) massimo = corrente;
    } else {
      corrente = 1;
    }
  }
  return massimo;
}

/// Il massimo numero di allenamenti fatti in un singolo mese di calendario.
int maxAllenamentiInUnMese(Set<DateTime> presenze) {
  final mesi = <String, int>{};
  for (final d in presenze) {
    final chiave = '${d.year}-${d.month}';
    mesi[chiave] = (mesi[chiave] ?? 0) + 1;
  }
  var massimo = 0;
  for (final v in mesi.values) {
    if (v > massimo) massimo = v;
  }
  return massimo;
}

/// Quante volte ti sei allenato sia il sabato sia la domenica seguente.
int weekendCompleti(Set<DateTime> presenze) {
  var n = 0;
  for (final d in presenze) {
    if (d.weekday == DateTime.saturday && presenze.contains(DateTime(d.year, d.month, d.day + 1))) n++;
  }
  return n;
}

int domenicheAllenate(Set<DateTime> presenze) => presenze.where((d) => d.weekday == DateTime.sunday).length;

/// Gruppi muscolari per le medaglie "giorni di ...".
const Map<String, Set<String>> gruppiMuscolari = {
  'gambe': {'quadricipiti', 'femorali', 'glutei', 'polpacci'},
  'petto': {'pettorali'},
  'schiena': {'dorsali', 'trapezio', 'lombari'},
  'spalle': {'deltoidi'},
  'braccia': {'bicipiti', 'tricipiti'},
  'core': {'addominali'},
};

class StatisticheUtente {
  final Set<DateTime> presenze;
  final int allenamenti;
  final int serie;
  final int settimane;
  final int pesi;
  final int obiettivo;
  final int allenamentiSettimana;
  final double volumeKg;
  final int record;
  final int mattiniero;
  final int nottambulo;
  final int serieATempo;
  final int muscoliSettimana;
  final int amici;
  final int eserciziDiversi;
  final int maxSerieGiorno;
  final double maxVolumeGiorno;
  final int schede;
  final int consecutivi;
  final int maxMese;
  final int weekend;
  final int domeniche;

  /// Giorni di allenamento in cui hai lavorato ogni gruppo muscolare.
  final Map<String, int> giorniGruppo;

  const StatisticheUtente({
    this.eserciziDiversi = 0,
    this.maxSerieGiorno = 0,
    this.maxVolumeGiorno = 0,
    this.schede = 0,
    this.consecutivi = 0,
    this.maxMese = 0,
    this.weekend = 0,
    this.domeniche = 0,
    this.giorniGruppo = const {},
    this.volumeKg = 0,
    this.record = 0,
    this.mattiniero = 0,
    this.nottambulo = 0,
    this.serieATempo = 0,
    this.muscoliSettimana = 0,
    this.amici = 0,
    required this.presenze,
    required this.allenamenti,
    required this.serie,
    required this.settimane,
    required this.pesi,
    required this.obiettivo,
    required this.allenamentiSettimana,
  });
}

/// Conta un record personale battuto (per le medaglie).
Future<void> contaRecord() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt('record_totali', (prefs.getInt('record_totali') ?? 0) + 1);
}

Future<int> leggiObiettivoSettimanale() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getInt(chiaveObiettivoSettimanale) ?? obiettivoPredefinito;
}

Future<void> salvaObiettivoSettimanale(int valore) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt(chiaveObiettivoSettimanale, valore);
}

Future<StatisticheUtente> caricaStatistiche() async {
  final db = DatabaseHelper.instance;
  final presenze = await db.getGiorniPresenza();
  final serie = await db.getTotaleSerie();
  final pesi = await db.getPesi();
  final obiettivo = await leggiObiettivoSettimanale();
  final oggi = DateTime.now();
  final prefs = await SharedPreferences.getInstance();

  final volume = await db.getVolumeTotale();
  final mattina = await db.getGiorniConOra(0, 6);
  final sera = await db.getGiorniConOra(22, 23);
  final aTempo = await db.getSerieATempo();
  final recenti = await db.getEserciziRecenti(giorni: 7);
  final muscoliSet = <String>{};
  for (final r in recenti) {
    final m = muscoloDi(r['nome'] as String, r['categoria'] as String);
    if (m != null) muscoliSet.add(m);
  }

  final eserciziDiversi = await db.getEserciziDistinti();
  final totaliGiorno = await db.getTotaliGiornalieri();
  var maxSerieGiorno = 0;
  var maxVolumeGiorno = 0.0;
  for (final r in totaliGiorno) {
    final nSerie = (r['serie'] as num?)?.toInt() ?? 0;
    final vol = (r['volume'] as num?)?.toDouble() ?? 0;
    if (nSerie > maxSerieGiorno) maxSerieGiorno = nSerie;
    if (vol > maxVolumeGiorno) maxVolumeGiorno = vol;
  }
  final schede = (await db.getSchede()).length;
  final giorniPerGruppo = <String, Set<String>>{};
  for (final r in await db.getGiorniEsercizi()) {
    final muscolo = muscoloDi(r['nome'] as String, r['categoria'] as String);
    if (muscolo == null) continue;
    for (final g in gruppiMuscolari.entries) {
      if (g.value.contains(muscolo)) {
        giorniPerGruppo.putIfAbsent(g.key, () => <String>{}).add(r['giorno'] as String);
      }
    }
  }

  return StatisticheUtente(
    eserciziDiversi: eserciziDiversi,
    maxSerieGiorno: maxSerieGiorno,
    maxVolumeGiorno: maxVolumeGiorno,
    schede: schede,
    consecutivi: giorniConsecutiviMax(presenze),
    maxMese: maxAllenamentiInUnMese(presenze),
    weekend: weekendCompleti(presenze),
    domeniche: domenicheAllenate(presenze),
    giorniGruppo: {for (final e in giorniPerGruppo.entries) e.key: e.value.length},
    volumeKg: volume,
    record: prefs.getInt('record_totali') ?? 0,
    mattiniero: mattina,
    nottambulo: sera,
    serieATempo: aTempo,
    muscoliSettimana: muscoliSet.length,
    amici: prefs.getInt('amici_conteggio') ?? 0,
    presenze: presenze,
    allenamenti: presenze.length,
    serie: serie,
    settimane: settimaneConsecutive(presenze, obiettivo, oggi),
    pesi: pesi.length,
    obiettivo: obiettivo,
    allenamentiSettimana: contaSettimana(presenze, lunediDi(oggi)),
  );
}
