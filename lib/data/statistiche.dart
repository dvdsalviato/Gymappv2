import 'package:shared_preferences/shared_preferences.dart';
import '../db/database_helper.dart';

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

  const StatisticheUtente({
    required this.presenze,
    required this.allenamenti,
    required this.serie,
    required this.settimane,
    required this.pesi,
    required this.obiettivo,
    required this.allenamentiSettimana,
  });
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
  return StatisticheUtente(
    presenze: presenze,
    allenamenti: presenze.length,
    serie: serie,
    settimane: settimaneConsecutive(presenze, obiettivo, oggi),
    pesi: pesi.length,
    obiettivo: obiettivo,
    allenamentiSettimana: contaSettimana(presenze, lunediDi(oggi)),
  );
}
