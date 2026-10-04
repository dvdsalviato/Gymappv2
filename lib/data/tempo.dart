/// "45 s", "1:30 min", "5:00 min": durata per le etichette.
String formattaDurata(int secondi) {
  if (secondi < 60) return '$secondi s';
  final m = secondi ~/ 60;
  final s = (secondi % 60).toString().padLeft(2, '0');
  return '$m:$s min';
}

/// "5:00", "0:45": orologio per il timer grande.
String formattaOrologio(int secondi) {
  final m = secondi ~/ 60;
  final s = (secondi % 60).toString().padLeft(2, '0');
  return '$m:$s';
}
