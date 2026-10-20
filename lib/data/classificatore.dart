import 'catalogo_esercizi.dart';

/// Riconoscimento della categoria di un esercizio a partire dal nome, anche
/// se scritto in modo approssimativo ("hyperxtension", "lat pul down"...), e
/// ricerca "tollerante" nel catalogo.

/// Toglie accenti, maiuscole e punteggiatura: "Hyperextension 45°" diventa
/// "hyperextension 45".
String normalizzaNome(String s) {
  const da = 'àáâäãèéêëìíîïòóôöõùúûüçñ';
  const a = 'aaaaaeeeeiiiiooooouuuucn';
  final b = StringBuffer();
  for (final r in s.toLowerCase().runes) {
    final ch = String.fromCharCode(r);
    final i = da.indexOf(ch);
    if (i >= 0) {
      b.write(a[i]);
    } else if ((r >= 97 && r <= 122) || (r >= 48 && r <= 57)) {
      b.write(ch);
    } else {
      b.write(' ');
    }
  }
  return b.toString().split(' ').where((t) => t.isNotEmpty).join(' ');
}

/// Distanza di modifica (inserimenti, cancellazioni, sostituzioni e scambi di
/// due lettere vicine).
int _distanza(String a, String b) {
  if (a == b) return 0;
  final n = a.length;
  final m = b.length;
  if (n == 0) return m;
  if (m == 0) return n;
  var prec2 = List<int>.filled(m + 1, 0);
  var prec = List<int>.generate(m + 1, (j) => j);
  var corr = List<int>.filled(m + 1, 0);
  for (var i = 1; i <= n; i++) {
    corr[0] = i;
    for (var j = 1; j <= m; j++) {
      final costo = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      var v = prec[j] + 1;
      final ins = corr[j - 1] + 1;
      if (ins < v) v = ins;
      final sost = prec[j - 1] + costo;
      if (sost < v) v = sost;
      if (i > 1 &&
          j > 1 &&
          a.codeUnitAt(i - 1) == b.codeUnitAt(j - 2) &&
          a.codeUnitAt(i - 2) == b.codeUnitAt(j - 1)) {
        final scambio = prec2[j - 2] + 1;
        if (scambio < v) v = scambio;
      }
      corr[j] = v;
    }
    final t = prec2;
    prec2 = prec;
    prec = corr;
    corr = t;
  }
  return prec[m];
}

/// Versione pubblica: vero se [voce] è [chiave] o una sua forma scritta con qualche errore.
bool parolaSimile(String voce, String chiave) => _paroleSimili(voce, chiave);

/// Parole fino a 5 lettere devono essere identiche (altrimenti "sacco" e
/// "stacco" o "corsa" e "corda" si confonderebbero); poi si tollera 1 errore,
/// e 2 dalle parole di 9 lettere in su.
int _tolleranza(int lunghezza) => lunghezza <= 5 ? 0 : (lunghezza <= 8 ? 1 : 2);

/// Vero se la parola [voce] è la parola [chiave], una sua forma (plurale,
/// derivato) oppure è scritta con qualche errore.
bool _paroleSimili(String voce, String chiave) {
  if (voce == chiave) return true;
  if (voce.isEmpty || chiave.isEmpty) return false;
  if (chiave.length >= 4 && voce.startsWith(chiave)) return true;
  final minima = voce.length < chiave.length ? voce.length : chiave.length;
  final tol = _tolleranza(minima);
  if (tol == 0) return false;
  if (minima < 9 && voce[0] != chiave[0]) return false;
  if ((voce.length - chiave.length).abs() > tol) return false;
  return _distanza(voce, chiave) <= tol;
}

const Set<String> _paroleVuote = {
  'con', 'di', 'a', 'da', 'al', 'ai', 'alla', 'alle', 'il', 'la', 'le', 'lo', 'in', 'su', 'per',
  'e', 'the', 'and', 'with', 'of', 'to',
};

List<String> _paroleSignificative(String normalizzato) {
  return normalizzato
      .split(' ')
      .where((t) => t.isNotEmpty && !_paroleVuote.contains(t) && int.tryParse(t) == null)
      .toList();
}

class _Voce {
  final EsercizioCatalogo esercizio;
  final String normalizzato;
  final List<String> parole;
  final List<String> paroleAlias;
  const _Voce(this.esercizio, this.normalizzato, this.parole, this.paroleAlias);
}

List<_Voce>? _indice;

List<_Voce> _voci() {
  return _indice ??= [
    for (final e in catalogoEsercizi)
      _Voce(
        e,
        normalizzaNome(e.nome),
        _paroleSignificative(normalizzaNome(e.nome)),
        _paroleSignificative(normalizzaNome(aliasCatalogo[e.nome] ?? '')),
      ),
  ];
}

/// L'esercizio del catalogo che corrisponde al nome scritto (identico oppure
/// quasi identico). Null se non c'è nulla di abbastanza simile.
EsercizioCatalogo? trovaNelCatalogo(String nome) {
  final n = normalizzaNome(nome);
  if (n.isEmpty) return null;
  final voci = _voci();
  for (final v in voci) {
    if (v.normalizzato == n) return v.esercizio;
  }
  final q = _paroleSignificative(n);
  if (q.isEmpty) return null;
  EsercizioCatalogo? migliore;
  var punteggioMigliore = 0.0;
  for (final v in voci) {
    if (v.parole.isEmpty) continue;
    var trovate = 0;
    for (final parola in q) {
      if (v.parole.any((p) => _paroleSimili(parola, p))) trovate++;
    }
    if (trovate != q.length) continue;
    final punteggio = 2 * trovate / (q.length + v.parole.length);
    if (punteggio >= 0.8 && punteggio > punteggioMigliore) {
      punteggioMigliore = punteggio;
      migliore = v.esercizio;
    }
  }
  return migliore;
}

bool _prefissoSimile(String parolaCatalogo, String digitato) {
  if (digitato.length < 4) return false;
  for (final extra in const [0, 1]) {
    final fine = digitato.length + extra;
    if (fine > parolaCatalogo.length) continue;
    final prefisso = parolaCatalogo.substring(0, fine);
    final tol = digitato.length >= 8 ? 2 : 1;
    if (_distanza(prefisso, digitato) <= tol) return true;
  }
  return false;
}

/// Cerca nel catalogo per nome, sinonimi (anche inglesi) e con tolleranza
/// agli errori di battitura: "hyperxtension" trova "Hyperextension".
List<EsercizioCatalogo> cercaCatalogo(String ricerca) {
  final q = normalizzaNome(ricerca);
  if (q.isEmpty) return catalogoEsercizi;
  final digitate = q.split(' ');
  final risultato = <EsercizioCatalogo>[];
  for (final v in _voci()) {
    final tutte = [...v.parole, ...v.paroleAlias];
    final ok = digitate.every((d) => tutte.any((p) {
          if (p.startsWith(d)) return true;
          if (d.length >= 3 && p.contains(d)) return true;
          return _paroleSimili(p, d) || _prefissoSimile(p, d);
        }));
    if (ok) risultato.add(v.esercizio);
  }
  return risultato;
}

class _Regola {
  final String categoria;
  final List<String> frasi;
  const _Regola(this.categoria, this.frasi);
}

/// Regole in ordine di priorità: le prime che scattano vincono. Ogni frase
/// vale se TUTTE le sue parole compaiono nel nome (anche scritte male).
const List<_Regola> _regole = [
  // Parole inequivocabili delle gambe, prima del core ("calf raise" non è un "leg raise").
  _Regola('Gambe', [
    'calf', 'polpacci', 'polpaccio', 'leg press', 'leg pres', 'leg extension', 'leg curl', 'squat',
    'tibialis',
  ]),
  _Regola('Core', [
    'leg raise', 'knee raise', 'sollevamento gambe', 'toes bar', 'hanging', 'crunch', 'plank',
    'sit up', 'situp', 'russian twist', 'ab wheel', 'ab roller', 'rollout', 'addominali', 'addominale',
    'addome', 'hollow', 'dead bug', 'pallof', 'wood chop', 'woodchop', 'woodchopper', 'v up',
    'mountain climber', 'dragon flag', 'windshield wiper', 'obliqui', 'bird dog', 'bear crawl',
    'l sit', 'flutter kick', 'scissor kick', 'heel touch', 'side bend', 'torsioni', 'twist',
    'turkish get', 'suitcase', 'core',
  ]),
  _Regola('Gambe', [
    'pressa', 'affondi', 'affondo', 'lunge', 'punte', 'hip thrust', 'glute', 'glutei', 'gluteo',
    'step up', 'abductor', 'adductor', 'abduzioni', 'adduttori', 'nordic', 'stacco rumeno',
    'romanian', 'rdl', 'gambe', 'gamba', 'quadricipiti', 'femorali', 'hack', 'sissy', 'pistol',
    'wall sit', 'box jump', 'ponte glutei', 'donkey', 'fire hydrant', 'frog pump', 'pull through',
    'kettlebell swing', 'thruster', 'wall ball', 'sled',
  ]),
  _Regola('Cardio', [
    'tapis roulant', 'treadmill', 'cyclette', 'bike', 'bicicletta', 'ciclismo', 'spinning',
    'ellittica', 'elliptical', 'vogatore', 'rowing', 'rower', 'ski erg', 'skierg', 'corsa',
    'running', 'run', 'jogging', 'camminata', 'walking', 'nuoto', 'swimming', 'corda saltare',
    'jump rope', 'skipping', 'burpee', 'burpees', 'jumping jack', 'jumping jacks', 'stair',
    'stepper', 'assault', 'battle rope', 'battle ropes', 'hiit', 'cardio', 'sprint', 'boxe',
    'sacco', 'shadow boxing', 'trekking', 'escursione',
  ]),
  _Regola('Spalle', [
    'spalle', 'shoulder', 'military', 'arnold', 'alzate', 'raise', 'face pull', 'facepull',
    'rear delt', 'reverse fly', 'reverse pec', 'overhead press', 'lento avanti', 'deltoid',
    'deltoidi', 'upright row', 'tirate mento', 'push press', 'handstand', 'bus driver', 'z press',
    'pike push', 'cuban', 'band pull apart', 'rotazione esterna', 'external rotation',
  ]),
  _Regola('Tricipiti', [
    'tricipiti', 'tricipite', 'tricep', 'triceps', 'french press', 'skull crusher', 'skullcrusher',
    'pushdown', 'push down', 'dip su panca', 'bench dip', 'panca stretta', 'close grip', 'jm press',
    'tate press', 'kickback', 'estensioni tricipiti', 'diamond', 'dip macchina',
  ]),
  _Regola('Bicipiti', [
    'curl', 'curls', 'bicipiti', 'bicipite', 'bicep', 'biceps', 'hammer', 'martello', 'preacher',
    'scott', 'zottman', 'concentrato', 'spider', 'predicatore',
  ]),
  _Regola('Schiena', [
    'lat machine', 'lat pulldown', 'pulldown', 'pull down', 'trazioni', 'trazione', 'pull up',
    'pullup', 'pull ups', 'chin up', 'chin ups', 'chinup', 'chin', 'dead lift', 'rematore', 'row', 'pulley', 'stacco', 'stacchi',
    'deadlift', 'rack pull', 'hyperextension', 'iperestensioni', 'iperestensione', 'back extension',
    'estensioni lombari', 'lombari', 'good morning', 'shrug', 'shrugs', 'dorsali', 'dorsale',
    'schiena', 'trapezi', 'trapezio', 'dead hang', 'superman', 'muscle up', 'farmer',
    'pullover cavi', 'lat',
  ]),
  _Regola('Petto', [
    'panca', 'bench', 'chest', 'croci', 'fly', 'flyes', 'piegamenti', 'piegamento', 'flessioni',
    'push up', 'push ups', 'pushup', 'pettorali', 'pettorale', 'petto', 'pec', 'dip', 'dips', 'crossover',
    'floor press', 'svend', 'squeeze press', 'pullover', 'spinte', 'incline', 'decline', 'spoto',
  ]),
  _Regola('Tricipiti', ['extension', 'extensions', 'estensioni', 'estensione']),
];

/// Ricava la categoria dal nome dell'esercizio: prima cerca nel catalogo
/// (anche con errori di battitura), poi applica le regole sulle parole.
/// Null se non riesce a collocarlo.
String? classificaEsercizio(String nome) {
  final n = normalizzaNome(nome);
  if (n.isEmpty) return null;
  final nelCatalogo = trovaNelCatalogo(nome);
  if (nelCatalogo != null) return nelCatalogo.categoria;
  final parole = n.split(' ');
  for (final regola in _regole) {
    for (final frase in regola.frasi) {
      if (frase.split(' ').every((p) => parole.any((t) => _paroleSimili(t, p)))) {
        return regola.categoria;
      }
    }
  }
  return null;
}

/// Vero se il nome contiene (anche scritta male) una delle frasi indicate.
bool nomeContiene(String nome, List<String> frasi) {
  final parole = normalizzaNome(nome).split(' ');
  for (final frase in frasi) {
    if (frase.split(' ').every((p) => parole.any((t) => _paroleSimili(t, p)))) return true;
  }
  return false;
}
