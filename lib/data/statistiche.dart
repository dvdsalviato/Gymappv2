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

  const StatisticheUtente({
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

  return StatisticheUtente(
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
