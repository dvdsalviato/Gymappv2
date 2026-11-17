/// Marchi dei macchinari: lo stesso esercizio su macchine diverse (soprattutto
/// a cavi e a leve) ha resistenze diverse, quindi carichi non confrontabili.
/// Il marchio fa parte del nome: "Lat machine · Technogym" e
/// "Lat machine · Panatta" sono due esercizi con storici separati.
const List<String> marcheMacchinari = [
  'Technogym',
  'Panatta',
  'Matrix',
  'Life Fitness',
  'Hammer Strength',
  'Cybex',
  'Precor',
  'Gym80',
  'Nautilus',
  'Star Trac',
  'Body-Solid',
  'Primal',
];

const String separatoreMacchinario = ' · ';

/// Divide "Lat machine · Technogym" in nome base e macchinario.
({String base, String? macchinario}) separaMacchinario(String nome) {
  final i = nome.lastIndexOf(separatoreMacchinario);
  if (i <= 0) return (base: nome.trim(), macchinario: null);
  final marca = nome.substring(i + separatoreMacchinario.length).trim();
  if (marca.isEmpty) return (base: nome.substring(0, i).trim(), macchinario: null);
  return (base: nome.substring(0, i).trim(), macchinario: marca);
}

/// Nome completo: base più macchinario (se c'è).
String componiNome(String base, String? macchinario) {
  final m = macchinario?.trim() ?? '';
  return m.isEmpty ? base.trim() : '${base.trim()}$separatoreMacchinario$m';
}
