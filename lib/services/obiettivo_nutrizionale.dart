import 'package:shared_preferences/shared_preferences.dart';
import '../data/fabbisogno.dart';
import '../db/database_helper.dart';

/// Calorie e macro giornalieri consigliati per te, calcolati con i dati del
/// profilo. Restituisce null se mancano i dati, se hai meno di 18 anni o se
/// i valori non sembrano sensati.
Future<Fabbisogno?> caricaObiettivoNutrizionale() async {
  final profilo = await DatabaseHelper.instance.getProfilo();
  final kg = (profilo?['peso_kg'] as num?)?.toDouble();
  final cm = (profilo?['altezza_cm'] as num?)?.toDouble();
  final eta = (profilo?['eta'] as num?)?.toInt();
  if (kg == null || cm == null || eta == null) return null;
  if (eta < 18 || eta > 100 || kg < 30 || kg > 300 || cm < 120 || cm > 230) return null;
  var obiettivo = profilo?['obiettivo'] as String?;
  if (obiettivo == 'Dimagrimento' && dimagrimentoSconsigliato(kg, cm)) obiettivo = 'Mantenimento';

  final prefs = await SharedPreferences.getInstance();
  var livello = prefs.getInt('fabbisogno_attivita');
  if (livello == null) {
    final presenze = await DatabaseHelper.instance.getGiorniPresenza();
    final limite = DateTime.now().subtract(const Duration(days: 28));
    livello = livelloAttivitaDaAllenamenti(presenze.where((d) => d.isAfter(limite)).length / 4);
  }
  return calcolaFabbisogno(
    kg: kg,
    cm: cm,
    eta: eta,
    sesso: profilo?['sesso'] as String?,
    livelloAttivita: livello,
    obiettivo: obiettivo,
  );
}
