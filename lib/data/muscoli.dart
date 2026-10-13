import 'catalogo_esercizi.dart';
import 'classificatore.dart';

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
  var cat = categoria;
  if (!_categorieMuscolari.contains(cat) && cat != 'Cardio') {
    // Esercizio senza categoria ("Altro"): la ricavo dal catalogo o dal nome,
    // anche se scritto con qualche errore.
    cat = classificaEsercizio(nome) ?? categoria;
  }
  switch (cat) {
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
      if (nomeContiene(nome, ['shrug', 'shrugs', 'trapezi', 'trapezio', 'farmer'])) return 'trapezio';
      if (nomeContiene(nome, [
        'stacco', 'stacchi', 'deadlift', 'dead lift', 'rack pull', 'hyperextension', 'iperestensioni',
        'iperestensione', 'back extension', 'lombari', 'good morning', 'superman',
      ])) {
        return 'lombari';
      }
      return 'dorsali';
    case 'Gambe':
      if (nomeContiene(nome, ['calf', 'polpacci', 'polpaccio', 'punte', 'tibialis'])) return 'polpacci';
      if (nomeContiene(nome, [
        'leg curl', 'nordic', 'stacco rumeno', 'romanian', 'rdl', 'glute ham', 'femorali', 'stacco gambe tese',
        'stacco gambe',
      ])) {
        return 'femorali';
      }
      if (nomeContiene(nome, [
        'hip thrust', 'ponte', 'glute', 'glutei', 'gluteo', 'abductor', 'abduzioni', 'kickback', 'donkey kick',
        'fire hydrant', 'frog pump', 'pull through', 'kettlebell swing',
      ])) {
        return 'glutei';
      }
      return 'quadricipiti';
  }
  return null;
}

const Set<String> _categorieMuscolari = {'Petto', 'Spalle', 'Bicipiti', 'Tricipiti', 'Core', 'Schiena', 'Gambe'};

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
