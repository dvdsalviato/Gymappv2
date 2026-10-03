String formatKg(double v) {
  final testo = v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '');
  return testo.replaceAll('.', ',');
}

class Suggerimento {
  final double carico;
  final String testo;
  final bool aumento;
  const Suggerimento(this.carico, this.testo, this.aumento);
}

/// Dato l'ultimo carico e le reps fatte, propone il carico per la serie dopo:
/// se hai fatto tutte le ripetizioni previste sale di 2,5 kg, altrimenti
/// resta sullo stesso carico.
Suggerimento? suggerisciCarico(double carico, int rep, int repTarget) {
  if (carico <= 0) return null;
  if (rep >= repTarget) {
    return Suggerimento(carico + 2.5, 'Hai fatto tutte le reps previste: sali di 2,5 kg', true);
  }
  return Suggerimento(carico, 'Punta a $repTarget reps prima di salire di carico', false);
}
