import '../data/coach.dart';
import '../data/statistiche.dart';
import '../db/database_helper.dart';

/// Raccoglie dal database i dati che servono al coach e restituisce i consigli.
Future<List<ConsiglioCoach>> consigliDelCoach() async {
  final db = DatabaseHelper.instance;
  final righe = await db.getSerieForza();
  final serie = <SerieCoach>[];
  for (final r in righe) {
    final data = DateTime.tryParse(r['data'] as String);
    if (data == null) continue;
    serie.add(SerieCoach(
      r['nome'] as String,
      (r['categoria'] as String?) ?? 'Altro',
      (r['carico'] as num).toDouble(),
      (r['rep'] as num).toInt(),
      data,
    ));
  }
  final esercizi = await db.getEserciziSchedeAttive();
  return analizza(DatiCoach(
    serie: serie,
    presenze: await db.getGiorniPresenza(),
    seriePerScheda: await db.getSeriePrevistePerScheda(),
    eserciziNelleSchede: {for (final e in esercizi) (e['nome'] as String).toLowerCase()},
    obiettivoSettimanale: await leggiObiettivoSettimanale(),
    oggi: DateTime.now(),
  ));
}
