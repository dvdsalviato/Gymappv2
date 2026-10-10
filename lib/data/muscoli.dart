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
  var cat = categoria;
  if (!_categorieMuscolari.contains(cat) && cat != 'Cardio') {
    // Esercizio senza categoria ("Altro"): la ricavo dal catalogo o dal nome.
    cat = _categoriaDaNome(nome) ?? categoria;
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

const Set<String> _categorieMuscolari = {'Petto', 'Spalle', 'Bicipiti', 'Tricipiti', 'Core', 'Schiena', 'Gambe'};

String? _categoriaDaNome(String nome) {
  final n = nome.toLowerCase().trim();
  for (final e in catalogoEsercizi) {
    if (e.nome.toLowerCase() == n) return e.categoria;
  }
  bool ha(List<String> parole) => parole.any(n.contains);
  if (ha(['squat', 'leg press', 'leg extension', 'leg curl', 'affond', 'lunge', 'calf', 'polpacc', 'hip thrust',
      'glute', 'step up', 'pressa', 'abductor', 'adductor', 'nordic', 'stacco rumeno', 'romanian', 'gamb'])) {
    return 'Gambe';
  }
  if (ha(['lat ', 'lat machine', 'pulldown', 'pull down', 'trazion', 'pull-up', 'pull up', 'chin', 'rematore',
      'row', 'pulley', 'shrug', 'stacco', 'deadlift', 'hyperextension', 'back extension', 'good morning',
      'dorsal', 'schiena'])) {
    return 'Schiena';
  }
  if (ha(['panca', 'bench', 'chest', 'croci', 'fly', 'piegament', 'push-up', 'push up', 'pettor', 'pec deck', 'dips'])) {
    return 'Petto';
  }
  if (ha(['spalle', 'shoulder', 'military', 'arnold', 'alzate', 'lateral raise', 'face pull', 'overhead press',
      'lento avanti', 'deltoid'])) {
    return 'Spalle';
  }
  if (ha(['curl', 'bicip', 'hammer', 'preacher', 'scott'])) return 'Bicipiti';
  if (ha(['tricip', 'french', 'pushdown', 'push down', 'skull', 'kickback', 'estensioni', 'extension'])) return 'Tricipiti';
  if (ha(['plank', 'crunch', 'addom', 'core', 'sit-up', 'sit up', 'russian twist', 'leg raise', 'ab wheel', 'hollow'])) {
    return 'Core';
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
