import 'catalogo_esercizi.dart';

class Muscolo {
  final String id;
  final String nome;
  const Muscolo(this.id, this.nome);
}

/// I muscoli mostrati nella mappa muscolare.
const List<Muscolo> muscoli = [
  Muscolo('pettorali', 'Pettorali'),
  Muscolo('deltoidi', 'Spalle'),
  Muscolo('bicipiti', 'Bicipiti'),
  Muscolo('tricipiti', 'Tricipiti'),
  Muscolo('addominali', 'Addominali'),
  Muscolo('trapezio', 'Trapezi'),
  Muscolo('dorsali', 'Dorsali'),
  Muscolo('lombari', 'Lombari'),
  Muscolo('glutei', 'Glutei'),
  Muscolo('quadricipiti', 'Quadricipiti'),
  Muscolo('femorali', 'Femorali'),
  Muscolo('polpacci', 'Polpacci'),
];

/// Da categoria e nome dell'esercizio ricava il muscolo principale.
/// Restituisce null per gli esercizi che non si riescono a collocare.
String? muscoloDi(String nome, String categoria) {
  final n = nome.toLowerCase();
  switch (categoria) {
    case 'Petto':
      return 'pettorali';
    case 'Spalle':
      return 'deltoidi';
    case 'Bicipiti':
      return 'bicipiti';
    case 'Tricipiti':
      return 'tricipiti';
    case 'Core':
      return 'addominali';
    case 'Schiena':
      if (n.contains('shrug')) return 'trapezio';
      if (n.contains('stacco') || n.contains('hyperextension') || n.contains('good morning')) {
        return 'lombari';
      }
      return 'dorsali';
    case 'Gambe':
      if (n.contains('calf')) return 'polpacci';
      if (n.contains('leg curl') || n.contains('nordic') || n.contains('stacco rumeno')) {
        return 'femorali';
      }
      if (n.contains('hip thrust') || n.contains('ponte glutei') || n.contains('abductor')) {
        return 'glutei';
      }
      return 'quadricipiti';
  }
  return null;
}

/// Esercizi del catalogo per questo muscolo che non hai fatto di recente,
/// presi a distanza uno dall'altro nella lista per avere varietà.
List<String> consigliatiPer(String muscoloId, Set<String> giaFatti, {int quanti = 5}) {
  final candidati = <String>[];
  for (final e in catalogoEsercizi) {
    if (muscoloDi(e.nome, e.categoria) == muscoloId && !giaFatti.contains(e.nome)) {
      candidati.add(e.nome);
    }
  }
  if (candidati.length <= quanti) return candidati;
  final passo = candidati.length / quanti;
  return [for (var i = 0; i < quanti; i++) candidati[(i * passo).floor()]];
}
