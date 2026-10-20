import 'dart:math' as math;
import 'alimenti.dart';

/// Menu settimanale di esempio: pasti composti con alimenti della tabella,
/// con le quantità calcolate per avvicinarsi ai macro dell'obiettivo.
/// Non è una dieta personalizzata né un consiglio medico.

class Totali {
  final double kcal;
  final double proteine;
  final double carboidrati;
  final double grassi;
  const Totali(this.kcal, this.proteine, this.carboidrati, this.grassi);
}

String _ruoloDi(Alimento a) {
  if (a.kcal < 45) return 'neutro';
  final kp = 4 * a.p;
  final kc = 4 * a.c;
  final kg = 9 * a.g;
  final tot = kp + kc + kg;
  if (tot <= 0) return 'neutro';
  if (kg / tot >= 0.55) return 'grassi';
  if (kp / tot >= 0.40) return 'proteine';
  return 'carboidrati';
}

class ItemMenu {
  final Alimento alimento;
  final double base;

  /// Quanto può crescere al massimo quando si ricalcolano le quantità.
  final double massimo;
  double grammi;
  ItemMenu(this.alimento, double g, {double? massimo})
      : base = g,
        grammi = g,
        massimo = massimo ?? g * 2.5;

  double get kcal => alimento.kcal * grammi / 100;
  double get proteine => alimento.p * grammi / 100;
  double get carboidrati => alimento.c * grammi / 100;
  double get grassi => alimento.g * grammi / 100;
  String get ruolo => _ruoloDi(alimento);
}

Totali _somma(Iterable<ItemMenu> items) {
  var k = 0.0;
  var p = 0.0;
  var c = 0.0;
  var g = 0.0;
  for (final i in items) {
    k += i.kcal;
    p += i.proteine;
    c += i.carboidrati;
    g += i.grassi;
  }
  return Totali(k, p, c, g);
}

class PastoMenu {
  final String nome;
  final List<ItemMenu> items;
  PastoMenu(this.nome, this.items);
  Totali get totali => _somma(items);
}

class GiornoMenu {
  final List<PastoMenu> pasti;
  GiornoMenu(this.pasti);
  Totali get totali => _somma(pasti.expand((p) => p.items));
}

final Map<String, Alimento> _perNome = {for (final a in alimenti) a.nome: a};

/// L'alimento con questo nome esatto, altrimenti il più vicino.
Alimento? alimentoPerNome(String nome) => _perNome[nome] ?? trovaAlimento(nome);

const List<String> _integratori = [
  'Skyr',
  'Yogurt greco (0% grassi)',
  'Proteine in polvere (whey)',
  'Proteine vegetali in polvere',
  'Seitan',
  'Tofu',
];
const List<String> _integratoriVegani = ['Proteine vegetali in polvere', 'Seitan', 'Tofu'];

/// Uova, formaggi e legumi portano proteine ma non si possono "tirare" per
/// raggiungere l'obiettivo. Se le fonti di proteine del giorno sono poche si
/// aggiunge uno spuntino proteico (skyr, yogurt greco o proteine in polvere).
void _integraProteine(GiornoMenu giorno, double proteine, String tipoDieta, String esclusioni) {
  var daProteine = 0.0;
  for (final p in giorno.pasti) {
    for (final i in p.items) {
      if (i.ruolo == 'proteine') daProteine += i.proteine;
    }
  }
  if (daProteine >= 0.5 * proteine) return;
  final elenco = tipoDieta == 'Vegano' ? _integratoriVegani : _integratori;
  for (final nome in elenco) {
    final a = _perNome[nome];
    if (a == null || alimentoEscluso(a, tipo: tipoDieta, esclusioni: esclusioni)) continue;
    final tetto = a.porzione > 0 ? a.porzione * 1.7 : 300.0;
    final base = math.min(tetto, math.max(20.0, 0.25 * proteine / (a.p / 100)));
    PastoMenu? pasto;
    for (final p in giorno.pasti.reversed) {
      if (p.nome.startsWith('Spuntino')) {
        pasto = p;
        break;
      }
    }
    pasto ??= giorno.pasti.first;
    pasto.items.add(ItemMenu(a, base, massimo: tetto));
    return;
  }
}

/// Porta le quantità di un giorno verso i macro indicati (grammi di proteine,
/// carboidrati e grassi). Ogni gruppo di alimenti (ricchi di proteine, di
/// carboidrati o di grassi) viene ingrandito o ridotto, senza stravolgere i
/// pasti. Le verdure e le bevande leggere restano come sono.
void scalaGiorno(
  GiornoMenu giorno, {
  required double proteine,
  required double carboidrati,
  required double grassi,
  String tipoDieta = 'Onnivoro',
  String esclusioni = '',
}) {
  if (giorno.pasti.isEmpty) return;
  _integraProteine(giorno, proteine, tipoDieta, esclusioni);
  final items = [for (final p in giorno.pasti) ...p.items];
  if (items.isEmpty) return;
  for (var giro = 0; giro < 12; giro++) {
    for (final ruolo in const ['proteine', 'carboidrati', 'grassi']) {
      double macro(ItemMenu i) => ruolo == 'proteine' ? i.proteine : (ruolo == 'carboidrati' ? i.carboidrati : i.grassi);
      final obiettivo = ruolo == 'proteine' ? proteine : (ruolo == 'carboidrati' ? carboidrati : grassi);
      var totale = 0.0;
      var delRuolo = 0.0;
      for (final i in items) {
        totale += macro(i);
        if (i.ruolo == ruolo) delRuolo += macro(i);
      }
      if (delRuolo <= 0) continue;
      final fattore = ((obiettivo - (totale - delRuolo)) / delRuolo).clamp(0.5, 2.0);
      for (final i in items) {
        if (i.ruolo == ruolo) i.grammi = (i.grammi * fattore).clamp(i.base * 0.4, i.massimo);
      }
    }
  }
  for (final i in items) {
    i.grammi = math.max(5.0, (i.grammi / 5).round() * 5.0);
  }
}

// ---------------------------------------------------------------- modelli

class _Ing {
  final String nome;
  final double g;
  const _Ing(this.nome, this.g);
}

class _Modello {
  final String tipo; // Colazione, Spuntino, Pranzo, Cena
  final List<_Ing> ingredienti;
  const _Modello(this.tipo, this.ingredienti);
}

const String _olio = "Olio extravergine d'oliva";

const List<_Modello> _modelli = [
  // Colazioni
  _Modello('Colazione', [_Ing('Yogurt greco (0% grassi)', 200), _Ing("Fiocchi d'avena", 50), _Ing('Banana', 120), _Ing('Mandorle', 15)]),
  _Modello('Colazione', [_Ing('Pane integrale', 60), _Ing('Uova (intere)', 110), _Ing('Mela', 150)]),
  _Modello('Colazione', [_Ing('Latte parzialmente scremato', 250), _Ing('Cornflakes', 40), _Ing('Kiwi', 150)]),
  _Modello('Colazione', [_Ing('Bevanda di soia (non zuccherata)', 250), _Ing("Fiocchi d'avena", 60), _Ing('Mirtilli', 100), _Ing('Semi di chia', 10)]),
  _Modello('Colazione', [_Ing('Fette biscottate', 40), _Ing('Marmellata', 30), _Ing('Bevanda di soia (non zuccherata)', 200)]),
  _Modello('Colazione', [_Ing('Skyr', 200), _Ing("Fiocchi d'avena", 40), _Ing('Fragole', 150)]),
  // Colazioni senza glutine
  _Modello('Colazione', [_Ing('Yogurt greco (0% grassi)', 200), _Ing('Mirtilli', 100), _Ing('Mandorle', 20), _Ing('Banana', 100)]),
  _Modello('Colazione', [_Ing('Uova (intere)', 110), _Ing('Arancia', 180), _Ing('Noci', 15)]),
  _Modello('Colazione', [_Ing('Bevanda di soia (non zuccherata)', 250), _Ing('Banana', 120), _Ing('Semi di chia', 15), _Ing('Mandorle', 15)]),
  // Spuntini
  _Modello('Spuntino', [_Ing('Mela', 150), _Ing('Mandorle', 20)]),
  _Modello('Spuntino', [_Ing('Yogurt greco (0% grassi)', 150), _Ing('Miele', 10)]),
  _Modello('Spuntino', [_Ing('Skyr', 150), _Ing('Mirtilli', 80)]),
  _Modello('Spuntino', [_Ing('Banana', 120), _Ing('Burro di arachidi', 20)]),
  _Modello('Spuntino', [_Ing('Hummus', 50), _Ing('Carote', 100)]),
  _Modello('Spuntino', [_Ing('Proteine vegetali in polvere', 30), _Ing('Bevanda di soia (non zuccherata)', 250), _Ing('Banana', 100)]),
  _Modello('Spuntino', [_Ing('Pane integrale', 40), _Ing('Bresaola', 50)]),
  // Pranzi
  _Modello('Pranzo', [_Ing('Pasta di semola (cruda)', 90), _Ing('Petto di pollo (crudo)', 150), _Ing('Zucchine', 200), _Ing(_olio, 10)]),
  _Modello('Pranzo', [_Ing('Riso (crudo)', 90), _Ing('Salmone (crudo)', 140), _Ing('Spinaci', 200), _Ing(_olio, 5)]),
  _Modello('Pranzo', [_Ing('Riso (crudo)', 90), _Ing('Ceci (cotti o in scatola)', 150), _Ing('Pomodori', 150), _Ing('Tofu', 100), _Ing(_olio, 10)]),
  _Modello('Pranzo', [_Ing('Pasta integrale (cruda)', 90), _Ing('Tonno al naturale (sgocciolato)', 120), _Ing('Pomodori', 150), _Ing(_olio, 10)]),
  _Modello('Pranzo', [_Ing('Patate (crude)', 300), _Ing('Petto di tacchino (crudo)', 150), _Ing('Broccoli', 200), _Ing(_olio, 10)]),
  _Modello('Pranzo', [_Ing('Couscous (crudo)', 80), _Ing('Lenticchie (cotte o in scatola)', 150), _Ing('Peperoni', 150), _Ing('Seitan', 100), _Ing(_olio, 10)]),
  _Modello('Pranzo', [_Ing('Pane integrale', 100), _Ing('Mozzarella di vacca', 100), _Ing('Insalata', 100), _Ing('Pomodori', 100), _Ing(_olio, 10)]),
  // Cene
  _Modello('Cena', [_Ing('Manzo magro (crudo)', 160), _Ing('Patate (crude)', 250), _Ing('Insalata', 100), _Ing(_olio, 10)]),
  _Modello('Cena', [_Ing('Merluzzo o nasello (crudo)', 200), _Ing('Pane integrale', 80), _Ing('Fagiolini', 200), _Ing(_olio, 10)]),
  _Modello('Cena', [_Ing('Tofu', 150), _Ing('Riso (crudo)', 70), _Ing('Broccoli', 200), _Ing(_olio, 10)]),
  _Modello('Cena', [_Ing('Uova (intere)', 165), _Ing('Pane integrale', 70), _Ing('Pomodori', 150), _Ing('Rucola', 50), _Ing(_olio, 8)]),
  _Modello('Cena', [_Ing('Petto di pollo (crudo)', 170), _Ing('Quinoa (cruda)', 70), _Ing('Peperoni', 200), _Ing(_olio, 10)]),
  _Modello('Cena', [_Ing('Fagioli (cotti o in scatola)', 200), _Ing('Pane integrale', 80), _Ing('Bietole', 200), _Ing('Seitan', 100), _Ing(_olio, 10)]),
  _Modello('Cena', [_Ing('Gamberi (crudi)', 200), _Ing('Pasta di semola (cruda)', 70), _Ing('Zucchine', 200), _Ing(_olio, 10)]),
  _Modello('Cena', [_Ing('Mozzarella di vacca', 125), _Ing('Pane bianco', 80), _Ing('Insalata', 100), _Ing('Pomodori', 150), _Ing(_olio, 8)]),
];

/// Nomi dei pasti in base a quanti ne vuoi al giorno (3, 4 o 5).
List<String> nomiPasti(int numero) {
  if (numero <= 3) return const ['Colazione', 'Pranzo', 'Cena'];
  if (numero == 4) return const ['Colazione', 'Pranzo', 'Spuntino', 'Cena'];
  return const ['Colazione', 'Spuntino mattina', 'Pranzo', 'Spuntino pomeriggio', 'Cena'];
}

String _tipoModello(String nomePasto) => nomePasto.startsWith('Spuntino') ? 'Spuntino' : nomePasto;

bool _modelloValido(_Modello m, String tipoDieta, String esclusioni) {
  for (final i in m.ingredienti) {
    final a = _perNome[i.nome];
    if (a == null) return false;
    if (alimentoEscluso(a, tipo: tipoDieta, esclusioni: esclusioni)) return false;
  }
  return true;
}

/// Menu di 7 giorni costruito da pasti già pronti (funziona senza internet).
/// Restituisce una lista vuota se con le esclusioni indicate non resta nulla.
List<GiornoMenu> menuDaModelli({required int pasti, required String tipoDieta, required String esclusioni, int sfasamento = 0}) {
  final nomi = nomiPasti(pasti);
  final perTipo = <String, List<_Modello>>{};
  for (final tipo in const ['Colazione', 'Spuntino', 'Pranzo', 'Cena']) {
    perTipo[tipo] = _modelli.where((m) => m.tipo == tipo && _modelloValido(m, tipoDieta, esclusioni)).toList();
  }
  final giorni = <GiornoMenu>[];
  for (var d = 0; d < 7; d++) {
    final listaPasti = <PastoMenu>[];
    var contaSpuntini = 0;
    for (final nome in nomi) {
      final tipo = _tipoModello(nome);
      final disponibili = perTipo[tipo] ?? const <_Modello>[];
      if (disponibili.isEmpty) continue;
      if (tipo == 'Spuntino') contaSpuntini++;
      final indice = (d + sfasamento + (tipo == 'Spuntino' ? contaSpuntini * 2 : 0)) % disponibili.length;
      final modello = disponibili[indice];
      listaPasti.add(PastoMenu(nome, [for (final i in modello.ingredienti) ItemMenu(_perNome[i.nome]!, i.g)]));
    }
    if (listaPasti.isNotEmpty) giorni.add(GiornoMenu(listaPasti));
  }
  return giorni.length == 7 ? giorni : <GiornoMenu>[];
}

// ------------------------------------------------------------- JSON e AI

/// Da un JSON salvato o prodotto dall'AI a un giorno. I nomi si cercano nella
/// tabella; gli alimenti sconosciuti o esclusi vengono scartati.
GiornoMenu? giornoDaJson(dynamic json, {String tipoDieta = 'Onnivoro', String esclusioni = ''}) {
  if (json is! Map) return null;
  final pastiJson = json['pasti'];
  if (pastiJson is! List) return null;
  final pasti = <PastoMenu>[];
  for (final p in pastiJson) {
    if (p is! Map) continue;
    final nome = '${p['nome'] ?? 'Pasto'}';
    final lista = p['alimenti'];
    if (lista is! List) continue;
    final items = <ItemMenu>[];
    for (final a in lista) {
      if (a is! Map) continue;
      final alimento = alimentoPerNome('${a['nome'] ?? ''}');
      final g = (a['g'] as num?)?.toDouble() ?? 0;
      if (alimento == null || g <= 0 || g > 2000) continue;
      if (alimentoEscluso(alimento, tipo: tipoDieta, esclusioni: esclusioni)) continue;
      items.add(ItemMenu(alimento, g));
    }
    if (items.isNotEmpty) pasti.add(PastoMenu(nome, items));
  }
  return pasti.isEmpty ? null : GiornoMenu(pasti);
}

Map<String, dynamic> giornoInJson(GiornoMenu g) => {
      'pasti': [
        for (final p in g.pasti)
          {
            'nome': p.nome,
            'alimenti': [
              for (final i in p.items) {'nome': i.alimento.nome, 'g': i.grammi},
            ],
          },
      ],
    };

/// I 7 giorni da una risposta dell'AI ({"giorni":[...]}). Null se qualcosa non torna.
List<GiornoMenu>? giorniDaJsonAi(dynamic json, {String tipoDieta = 'Onnivoro', String esclusioni = ''}) {
  final lista = json is Map ? json['giorni'] : json;
  if (lista is! List || lista.length < 7) return null;
  final giorni = <GiornoMenu>[];
  for (final g in lista.take(7)) {
    final giorno = giornoDaJson(g, tipoDieta: tipoDieta, esclusioni: esclusioni);
    if (giorno == null || giorno.pasti.length < 2) return null;
    giorni.add(giorno);
  }
  return giorni;
}

// -------------------------------------------------------- lista della spesa

class VoceSpesa {
  final Alimento alimento;
  double grammi;
  VoceSpesa(this.alimento, this.grammi);
}

/// Somma gli alimenti della settimana, raggruppati per categoria.
Map<String, List<VoceSpesa>> listaSpesa(List<GiornoMenu> giorni) {
  final perAlimento = <String, VoceSpesa>{};
  for (final g in giorni) {
    for (final p in g.pasti) {
      for (final i in p.items) {
        perAlimento.putIfAbsent(i.alimento.nome, () => VoceSpesa(i.alimento, 0)).grammi += i.grammi;
      }
    }
  }
  final ordine = [cCarne, cLatticini, cCereali, cLegumi, cVerdura, cFrutta, cSecca, cCondimenti, cBevande, cAltro];
  final risultato = <String, List<VoceSpesa>>{};
  for (final cat in ordine) {
    final voci = perAlimento.values.where((v) => v.alimento.categoria == cat).toList()
      ..sort((a, b) => a.alimento.nome.compareTo(b.alimento.nome));
    if (voci.isNotEmpty) risultato[cat] = voci;
  }
  return risultato;
}

String quantitaTesto(double grammi, String unita) {
  if (grammi >= 1000) {
    final v = (grammi / 1000).toStringAsFixed(1).replaceAll('.', ',').replaceAll(RegExp(r',0$'), '');
    return unita == 'ml' ? '$v l' : '$v kg';
  }
  return '${grammi.round()} ${unita == 'ml' ? 'ml' : 'g'}';
}

String listaSpesaTesto(Map<String, List<VoceSpesa>> lista) {
  final b = StringBuffer('Lista della spesa (7 giorni)\n');
  lista.forEach((cat, voci) {
    b.writeln('\n$cat');
    for (final v in voci) {
      b.writeln('- ${v.alimento.nome}: ${quantitaTesto(v.grammi, v.alimento.unita)}');
    }
  });
  return b.toString();
}
