import 'dart:math' as math;

/// Stima del fabbisogno calorico e dei macronutrienti. Sono stime con un
/// margine d'errore importante: non sono una dieta né un consiglio medico.

const List<String> nomiAttivita = ['Sedentario', 'Leggero', 'Moderato', 'Intenso'];
const List<String> descrizioniAttivita = [
  'Poco movimento, lavoro seduto',
  '1-3 allenamenti a settimana',
  '3-5 allenamenti a settimana',
  '6-7 allenamenti o lavoro fisico',
];
const List<double> fattoriAttivita = [1.2, 1.375, 1.55, 1.725];

class Fabbisogno {
  /// Calorie a riposo (metabolismo basale stimato).
  final double bmr;

  /// Calorie al giorno per mantenere il peso.
  final double mantenimento;

  /// Calorie al giorno consigliate per l'obiettivo.
  final double obiettivo;
  final double proteine;
  final double grassi;
  final double carboidrati;

  /// Variazione rispetto al mantenimento, in percentuale (es. -15).
  final int variazionePercento;

  /// Vero se l'obiettivo è stato alzato per non scendere troppo con le calorie.
  final bool limitato;

  const Fabbisogno({
    required this.bmr,
    required this.mantenimento,
    required this.obiettivo,
    required this.proteine,
    required this.grassi,
    required this.carboidrati,
    required this.variazionePercento,
    required this.limitato,
  });
}

/// Metabolismo basale con la formula di Mifflin-St Jeor. Se il sesso non è
/// indicato si usa la media tra i due valori.
double calcolaBmr({required double kg, required double cm, required int eta, required String? sesso}) {
  final base = 10 * kg + 6.25 * cm - 5 * eta;
  if (sesso == 'Uomo') return base + 5;
  if (sesso == 'Donna') return base - 161;
  return base - 78;
}

/// Livello di attività (0-3) in base agli allenamenti a settimana.
int livelloAttivitaDaAllenamenti(double allenamentiASettimana) {
  if (allenamentiASettimana < 1.5) return 0;
  if (allenamentiASettimana < 3.5) return 1;
  if (allenamentiASettimana < 5.5) return 2;
  return 3;
}

/// Indice di massa corporea (peso / altezza al quadrato).
double indiceMassaCorporea(double kg, double cm) {
  final m = cm / 100;
  return kg / (m * m);
}

/// Con un indice di massa corporea sotto 18,5 non si propone un dimagrimento.
bool dimagrimentoSconsigliato(double kg, double cm) => indiceMassaCorporea(kg, cm) < 18.5;

double _variazione(String? obiettivo) {
  switch (obiettivo) {
    case 'Dimagrimento':
      return -0.15;
    case 'Massa muscolare':
      return 0.10;
    case 'Forza':
      return 0.05;
  }
  return 0.0;
}

double _proteineAlKg(String? obiettivo) {
  switch (obiettivo) {
    case 'Dimagrimento':
      return 2.0;
    case 'Massa muscolare':
    case 'Forza':
      return 1.8;
  }
  return 1.6;
}

/// Calcola calorie e macro. Il deficit non scende mai sotto il metabolismo
/// basale stimato (e comunque non sotto 1200 kcal).
Fabbisogno calcolaFabbisogno({
  required double kg,
  required double cm,
  required int eta,
  required String? sesso,
  required int livelloAttivita,
  required String? obiettivo,
}) {
  final bmr = calcolaBmr(kg: kg, cm: cm, eta: eta, sesso: sesso);
  final mantenimento = bmr * fattoriAttivita[livelloAttivita.clamp(0, fattoriAttivita.length - 1)];
  final variazione = _variazione(obiettivo);
  var kcal = mantenimento * (1 + variazione);
  var limitato = false;
  final minimo = math.max(1200.0, bmr);
  if (kcal < minimo) {
    kcal = minimo < mantenimento ? minimo : mantenimento;
    limitato = true;
  }
  var proteine = kg * _proteineAlKg(obiettivo);
  if (4 * proteine > 0.4 * kcal) proteine = 0.4 * kcal / 4;
  final grassi = math.max(0.25 * kcal / 9, 0.6 * kg);
  final carboidrati = math.max(0.0, (kcal - 4 * proteine - 9 * grassi) / 4);
  return Fabbisogno(
    bmr: bmr,
    mantenimento: mantenimento,
    obiettivo: kcal,
    proteine: proteine,
    grassi: grassi,
    carboidrati: carboidrati,
    variazionePercento: (variazione * 100).round(),
    limitato: limitato,
  );
}
