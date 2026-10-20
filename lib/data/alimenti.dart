import 'classificatore.dart';

/// Alimenti comuni con calorie e macronutrienti per 100 g (o 100 ml per le
/// bevande). Sono valori medi indicativi, non quelli di una marca precisa:
/// il peso va sempre controllato e, se serve, corretto a mano.

const String cCarne = 'Carne e pesce';
const String cLatticini = 'Uova e latticini';
const String cCereali = 'Cereali, pane e patate';
const String cLegumi = 'Legumi e proteine vegetali';
const String cVerdura = 'Verdura';
const String cFrutta = 'Frutta';
const String cSecca = 'Frutta secca e semi';
const String cCondimenti = 'Condimenti e dolci';
const String cBevande = 'Bevande';
const String cAltro = 'Altro';

class Alimento {
  final String nome;
  final double kcal;
  final double p;
  final double c;
  final double g;
  final String categoria;

  /// 'g' oppure 'ml'.
  final String unita;

  /// Peso (o volume) di un'unità tipica: un uovo, un vasetto, una bottiglia... 0 se non c'è.
  final double porzione;

  /// Parole alternative per la ricerca.
  final String alias;

  /// Etichette per escludere gli alimenti: carne, pesce, latticini, uova, glutine, fruttasecca, miele, alcol.
  final Set<String> tag;

  /// Grammi di alcol per 100 ml (contano 7 kcal al grammo).
  final double alcol;

  const Alimento(
    this.nome,
    this.kcal,
    this.p,
    this.c,
    this.g,
    this.categoria, {
    this.unita = 'g',
    this.porzione = 0,
    this.alias = '',
    this.tag = const <String>{},
    this.alcol = 0,
  });
}

const List<Alimento> alimenti = [
  // ---- Carne e pesce ----
  Alimento('Petto di pollo (crudo)', 110, 23, 0, 1.6, cCarne, alias: 'pollo', tag: {'carne'}),
  Alimento('Petto di pollo (cotto)', 165, 31, 0, 3.6, cCarne, alias: 'pollo', tag: {'carne'}),
  Alimento('Coscia di pollo (cruda, senza pelle)', 121, 19.7, 0, 4.1, cCarne, alias: 'pollo', tag: {'carne'}),
  Alimento('Petto di tacchino (crudo)', 105, 23.5, 0, 1, cCarne, alias: 'tacchino fesa', tag: {'carne'}),
  Alimento('Petto di tacchino (cotto)', 147, 30, 0, 2, cCarne, alias: 'tacchino fesa', tag: {'carne'}),
  Alimento('Manzo magro (crudo)', 137, 21.4, 0, 5, cCarne, alias: 'bistecca fettina carne rossa', tag: {'carne'}),
  Alimento('Manzo magro (cotto)', 190, 29, 0, 8, cCarne, alias: 'bistecca fettina carne rossa', tag: {'carne'}),
  Alimento('Macinato di manzo (crudo, 20% grasso)', 254, 17.2, 0, 20, cCarne, alias: 'hamburger macinato', tag: {'carne'}),
  Alimento('Lonza di maiale (cruda)', 143, 21, 0, 5.7, cCarne, alias: 'maiale', tag: {'carne'}),
  Alimento('Prosciutto crudo', 260, 26, 0, 17, cCarne, tag: {'carne'}),
  Alimento('Prosciutto cotto', 140, 19.5, 0.5, 6.5, cCarne, tag: {'carne'}),
  Alimento('Bresaola', 150, 32, 0, 2.5, cCarne, tag: {'carne'}),
  Alimento('Salmone (crudo)', 208, 20, 0, 13, cCarne, tag: {'pesce'}),
  Alimento('Tonno al naturale (sgocciolato)', 105, 24, 0, 1, cCarne, alias: 'scatoletta', tag: {'pesce'}),
  Alimento("Tonno sott'olio (sgocciolato)", 192, 25, 0, 10, cCarne, alias: 'scatoletta', tag: {'pesce'}),
  Alimento('Merluzzo o nasello (crudo)', 82, 17.8, 0, 0.7, cCarne, alias: 'merluzzo nasello pesce bianco', tag: {'pesce'}),
  Alimento('Orata (cruda)', 105, 20, 0, 2.5, cCarne, alias: 'branzino spigola pesce', tag: {'pesce'}),
  Alimento('Gamberi (crudi)', 85, 20, 0, 0.5, cCarne, tag: {'pesce'}),

  // ---- Uova e latticini ----
  Alimento('Uova (intere)', 143, 12.6, 0.7, 9.5, cLatticini, porzione: 55, alias: 'uovo', tag: {'uova'}),
  Alimento('Albume', 52, 11, 0.7, 0.2, cLatticini, alias: 'albumi', tag: {'uova'}),
  Alimento('Yogurt bianco (intero)', 61, 3.8, 4.7, 3.2, cLatticini, porzione: 125, tag: {'latticini'}),
  Alimento('Yogurt bianco (magro)', 38, 4, 5, 0.2, cLatticini, porzione: 125, tag: {'latticini'}),
  Alimento('Yogurt greco (0% grassi)', 57, 10.3, 3.9, 0.2, cLatticini, porzione: 150, alias: 'magro', tag: {'latticini'}),
  Alimento('Yogurt greco (intero)', 97, 9, 4, 5, cLatticini, porzione: 150, tag: {'latticini'}),
  Alimento('Skyr', 63, 11, 4, 0.2, cLatticini, porzione: 150, tag: {'latticini'}),
  Alimento('Latte parzialmente scremato', 46, 3.4, 4.9, 1.6, cLatticini, unita: 'ml', porzione: 200, tag: {'latticini'}),
  Alimento('Latte intero', 64, 3.3, 4.9, 3.6, cLatticini, unita: 'ml', porzione: 200, tag: {'latticini'}),
  Alimento('Latte scremato', 35, 3.5, 5, 0.1, cLatticini, unita: 'ml', porzione: 200, tag: {'latticini'}),
  Alimento('Bevanda di soia (non zuccherata)', 33, 3.3, 0.5, 1.8, cLatticini, unita: 'ml', porzione: 200, alias: 'latte di soia'),
  Alimento('Bevanda di avena', 45, 1, 8, 1.5, cLatticini, unita: 'ml', porzione: 200, alias: 'latte di avena', tag: {'glutine'}),
  Alimento('Bevanda di mandorla (non zuccherata)', 15, 0.5, 0.3, 1.1, cLatticini, unita: 'ml', porzione: 200, alias: 'latte di mandorla', tag: {'fruttasecca'}),
  Alimento('Mozzarella di vacca', 253, 18.7, 0.7, 19.5, cLatticini, porzione: 125, tag: {'latticini'}),
  Alimento('Ricotta di vacca', 146, 8.8, 3.5, 10.9, cLatticini, tag: {'latticini'}),
  Alimento('Parmigiano Reggiano', 390, 33, 0, 28, cLatticini, porzione: 20, alias: 'grana formaggio grattugiato', tag: {'latticini'}),
  Alimento('Grana Padano', 384, 33, 0, 28, cLatticini, porzione: 20, alias: 'formaggio grattugiato', tag: {'latticini'}),
  Alimento('Fiocchi di latte', 98, 11, 3.4, 4.3, cLatticini, alias: 'cottage', tag: {'latticini'}),
  Alimento('Feta', 264, 14, 4, 21, cLatticini, tag: {'latticini'}),
  Alimento('Scamorza', 334, 25, 1, 25, cLatticini, tag: {'latticini'}),
  Alimento('Burro', 740, 0.8, 0.1, 82, cLatticini, porzione: 10, tag: {'latticini'}),
  Alimento('Panna da cucina', 200, 2.5, 3.5, 20, cLatticini, tag: {'latticini'}),

  // ---- Cereali, pane e patate ----
  Alimento('Pasta di semola (cruda)', 353, 10.9, 79.1, 1.4, cCereali, alias: 'spaghetti penne fusilli rigatoni', tag: {'glutine'}),
  Alimento('Pasta di semola (cotta)', 158, 5.8, 30.9, 0.9, cCereali, alias: 'spaghetti penne fusilli rigatoni', tag: {'glutine'}),
  Alimento('Pasta integrale (cruda)', 340, 13, 68, 2.5, cCereali, alias: 'spaghetti penne fusilli', tag: {'glutine'}),
  Alimento('Riso (crudo)', 332, 6.7, 80.4, 0.4, cCereali, alias: 'basmati'),
  Alimento('Riso (cotto)', 130, 2.7, 28, 0.3, cCereali, alias: 'basmati'),
  Alimento('Riso integrale (crudo)', 350, 7.5, 75, 2.7, cCereali),
  Alimento('Pane bianco', 270, 8.5, 56, 1.5, cCereali, porzione: 30, alias: 'panino fetta', tag: {'glutine'}),
  Alimento('Pane integrale', 250, 9.5, 46, 2.8, cCereali, porzione: 30, alias: 'panino fetta', tag: {'glutine'}),
  Alimento('Fette biscottate', 400, 11, 72, 6.5, cCereali, porzione: 8, tag: {'glutine'}),
  Alimento("Fiocchi d'avena", 375, 12.5, 67, 7, cCereali, alias: 'avena porridge', tag: {'glutine'}),
  Alimento('Cornflakes', 375, 7, 84, 1, cCereali, alias: 'cereali', tag: {'glutine'}),
  Alimento('Muesli', 365, 9.5, 63, 6.5, cCereali, alias: 'cereali', tag: {'glutine', 'fruttasecca'}),
  Alimento('Couscous (crudo)', 360, 12.5, 72, 1.5, cCereali, tag: {'glutine'}),
  Alimento('Patate (crude)', 77, 2, 17, 0.1, cCereali, alias: 'patata'),
  Alimento('Patate dolci (crude)', 86, 1.6, 20, 0.1, cCereali, alias: 'patata dolce'),
  Alimento('Gnocchi di patate', 150, 3.5, 33, 0.5, cCereali, tag: {'glutine'}),
  Alimento('Quinoa (cruda)', 368, 14, 64, 6, cCereali),
  Alimento('Farro (crudo)', 340, 15, 67, 2.5, cCereali, tag: {'glutine'}),
  Alimento('Orzo perlato (crudo)', 330, 10, 70, 1.5, cCereali, tag: {'glutine'}),
  Alimento('Pizza margherita', 270, 10.5, 33, 10, cCereali, porzione: 300, tag: {'glutine', 'latticini'}),
  Alimento('Piadina', 330, 8.5, 52, 9.5, cCereali, porzione: 100, tag: {'glutine'}),
  Alimento('Crackers', 430, 10, 70, 12, cCereali, porzione: 7, tag: {'glutine'}),
  Alimento('Grissini', 410, 12, 72, 7.5, cCereali, porzione: 5, tag: {'glutine'}),
  Alimento('Biscotti secchi', 430, 7, 75, 11, cCereali, porzione: 8, tag: {'glutine'}),
  Alimento('Cornetto (brioche)', 400, 7.5, 50, 19, cCereali, porzione: 60, alias: 'brioche croissant', tag: {'glutine', 'latticini', 'uova'}),
  Alimento('Patatine fritte (confezione)', 536, 6.6, 53, 34, cCereali, alias: 'patatine chips'),

  // ---- Legumi e proteine vegetali ----
  Alimento('Ceci (cotti o in scatola)', 130, 7.5, 19, 2.4, cLegumi, alias: 'ceci'),
  Alimento('Lenticchie (cotte o in scatola)', 116, 9, 20, 0.4, cLegumi, alias: 'lenticchie'),
  Alimento('Fagioli (cotti o in scatola)', 115, 7.5, 19, 0.5, cLegumi, alias: 'borlotti cannellini'),
  Alimento('Piselli (cotti o surgelati)', 80, 5.4, 14, 0.4, cLegumi, alias: 'piselli'),
  Alimento('Tofu', 120, 12.5, 1.5, 7, cLegumi),
  Alimento('Seitan', 120, 24, 4, 1, cLegumi, tag: {'glutine'}),
  Alimento('Hummus', 260, 8, 14, 19, cLegumi, alias: 'hummus di ceci'),
  Alimento('Lenticchie (secche)', 325, 24, 51, 1.5, cLegumi),
  Alimento('Ceci (secchi)', 360, 20, 54, 6, cLegumi),
  Alimento('Fagioli (secchi)', 335, 22, 55, 1.5, cLegumi),

  // ---- Verdura ----
  Alimento('Zucchine', 17, 1.2, 3.1, 0.3, cVerdura, alias: 'zucchina'),
  Alimento('Broccoli', 34, 2.8, 6.6, 0.4, cVerdura),
  Alimento('Spinaci', 23, 2.9, 3.6, 0.4, cVerdura),
  Alimento('Insalata', 15, 1.4, 2.9, 0.2, cVerdura, alias: 'lattuga misticanza'),
  Alimento('Pomodori', 18, 0.9, 3.9, 0.2, cVerdura, alias: 'pomodoro'),
  Alimento('Carote', 41, 0.9, 9.6, 0.2, cVerdura, alias: 'carota'),
  Alimento('Peperoni', 31, 1, 6, 0.3, cVerdura, alias: 'peperone'),
  Alimento('Melanzane', 25, 1, 6, 0.2, cVerdura, alias: 'melanzana'),
  Alimento('Cavolfiore', 25, 1.9, 5, 0.3, cVerdura),
  Alimento('Cetrioli', 15, 0.7, 3.6, 0.1, cVerdura, alias: 'cetriolo'),
  Alimento('Fagiolini', 31, 1.8, 7, 0.1, cVerdura),
  Alimento('Funghi champignon', 22, 3.1, 3.3, 0.3, cVerdura, alias: 'funghi'),
  Alimento('Cipolle', 40, 1.1, 9.3, 0.1, cVerdura, alias: 'cipolla'),
  Alimento('Asparagi', 20, 2.2, 3.9, 0.1, cVerdura),
  Alimento('Finocchi', 31, 1.2, 7.3, 0.2, cVerdura, alias: 'finocchio'),
  Alimento('Zucca', 26, 1, 6.5, 0.1, cVerdura),
  Alimento('Radicchio', 23, 1.4, 4.5, 0.3, cVerdura),
  Alimento('Rucola', 25, 2.6, 3.7, 0.7, cVerdura),
  Alimento('Bietole', 19, 1.8, 3.7, 0.2, cVerdura),
  Alimento('Carciofi', 47, 3.3, 10.5, 0.2, cVerdura, alias: 'carciofo'),
  Alimento('Verza', 25, 1.8, 4.6, 0.1, cVerdura, alias: 'cavolo'),

  // ---- Frutta ----
  Alimento('Mela', 52, 0.3, 13.8, 0.2, cFrutta, porzione: 150, alias: 'mele'),
  Alimento('Banana', 89, 1.1, 22.8, 0.3, cFrutta, porzione: 120, alias: 'banane'),
  Alimento('Arancia', 47, 0.9, 11.8, 0.1, cFrutta, porzione: 180, alias: 'arance'),
  Alimento('Mandarino', 53, 0.8, 13.3, 0.3, cFrutta, porzione: 80, alias: 'mandarini clementine'),
  Alimento('Pera', 57, 0.4, 15, 0.1, cFrutta, porzione: 160, alias: 'pere'),
  Alimento('Fragole', 32, 0.7, 7.7, 0.3, cFrutta, alias: 'fragola'),
  Alimento('Uva', 69, 0.7, 18, 0.2, cFrutta),
  Alimento('Kiwi', 61, 1.1, 14.7, 0.5, cFrutta, porzione: 75),
  Alimento('Ananas', 50, 0.5, 13, 0.1, cFrutta),
  Alimento('Pesca', 39, 0.9, 9.5, 0.3, cFrutta, porzione: 150, alias: 'pesche nettarina'),
  Alimento('Albicocche', 48, 1.4, 11.1, 0.4, cFrutta, porzione: 40, alias: 'albicocca'),
  Alimento('Anguria', 30, 0.6, 7.6, 0.2, cFrutta, alias: 'cocomero'),
  Alimento('Melone', 34, 0.8, 8.2, 0.2, cFrutta),
  Alimento('Mirtilli', 57, 0.7, 14.5, 0.3, cFrutta),
  Alimento('Ciliegie', 63, 1.1, 16, 0.2, cFrutta),
  Alimento('Avocado', 160, 2, 8.5, 14.7, cFrutta, porzione: 150),
  Alimento('Datteri secchi', 282, 2.5, 75, 0.4, cFrutta, porzione: 20),
  Alimento('Uvetta', 299, 3.1, 79, 0.5, cFrutta, alias: 'uva passa'),

  // ---- Frutta secca e semi ----
  Alimento('Mandorle', 579, 21.2, 21.6, 49.9, cSecca, porzione: 30, tag: {'fruttasecca'}),
  Alimento('Noci', 654, 15.2, 13.7, 65.2, cSecca, porzione: 30, tag: {'fruttasecca'}),
  Alimento('Nocciole', 628, 15, 16.7, 60.8, cSecca, porzione: 30, tag: {'fruttasecca'}),
  Alimento('Arachidi', 567, 25.8, 16.1, 49.2, cSecca, porzione: 30, tag: {'fruttasecca'}),
  Alimento('Burro di arachidi', 588, 25, 20, 50, cSecca, porzione: 15, tag: {'fruttasecca'}),
  Alimento('Anacardi', 553, 18.2, 30.2, 43.8, cSecca, porzione: 30, tag: {'fruttasecca'}),
  Alimento('Pistacchi', 560, 20.2, 27.2, 45.3, cSecca, porzione: 30, tag: {'fruttasecca'}),
  Alimento('Semi di chia', 486, 16.5, 42, 30.7, cSecca),
  Alimento('Semi di lino', 534, 18, 29, 42, cSecca),
  Alimento('Semi di zucca', 559, 30, 11, 49, cSecca),

  // ---- Condimenti e dolci ----
  Alimento("Olio extravergine d'oliva", 900, 0, 0, 100, cCondimenti, porzione: 10, alias: 'olio evo oliva'),
  Alimento('Olio di semi', 900, 0, 0, 100, cCondimenti, porzione: 10),
  Alimento('Maionese', 680, 1.5, 2, 75, cCondimenti, porzione: 15, tag: {'uova'}),
  Alimento('Ketchup', 100, 1, 25, 0.1, cCondimenti, porzione: 15),
  Alimento('Miele', 304, 0.3, 82, 0, cCondimenti, porzione: 10, tag: {'miele'}),
  Alimento('Zucchero', 390, 0, 100, 0, cCondimenti, porzione: 5),
  Alimento('Marmellata', 250, 0.5, 62, 0.1, cCondimenti, porzione: 20, alias: 'confettura'),
  Alimento('Pesto alla genovese', 460, 5, 5, 46, cCondimenti, porzione: 20, tag: {'latticini', 'fruttasecca'}),
  Alimento('Sugo di pomodoro', 30, 1.3, 5, 0.3, cCondimenti, alias: 'passata pomodoro'),
  Alimento('Cioccolato fondente', 598, 7.8, 46, 43, cCondimenti, porzione: 10, alias: 'cioccolato'),
  Alimento('Cioccolato al latte', 535, 7.7, 59, 30, cCondimenti, porzione: 10, alias: 'cioccolato', tag: {'latticini'}),
  Alimento('Crema alle nocciole', 539, 6.3, 57.5, 30.9, cCondimenti, porzione: 15, alias: 'nutella', tag: {'latticini', 'fruttasecca'}),
  Alimento('Gelato alla crema', 200, 3.5, 24, 10, cCondimenti, porzione: 80, alias: 'gelato', tag: {'latticini'}),

  // ---- Bevande (per 100 ml) ----
  Alimento('Birra', 43, 0.5, 3.6, 0, cBevande, unita: 'ml', porzione: 330, alias: 'media chiara lager', tag: {'alcol', 'glutine'}, alcol: 3.7),
  Alimento('Vino', 85, 0.1, 2.6, 0, cBevande, unita: 'ml', porzione: 125, alias: 'rosso bianco calice bicchiere', tag: {'alcol'}, alcol: 9.5),
  Alimento('Prosecco', 70, 0.2, 2.5, 0, cBevande, unita: 'ml', porzione: 125, alias: 'spumante bollicine', tag: {'alcol'}, alcol: 8.7),
  Alimento('Superalcolico (40%)', 231, 0, 0, 0, cBevande, unita: 'ml', porzione: 40, alias: 'whisky vodka gin rum amaro liquore grappa', tag: {'alcol'}, alcol: 31.6),
  Alimento('Birra analcolica', 20, 0.4, 4.3, 0, cBevande, unita: 'ml', porzione: 330, tag: {'glutine'}),
  Alimento('Coca-Cola', 42, 0, 10.6, 0, cBevande, unita: 'ml', porzione: 330, alias: 'cola bibita gassata'),
  Alimento("Succo d'arancia", 45, 0.7, 10.4, 0.2, cBevande, unita: 'ml', porzione: 200, alias: 'spremuta'),
  Alimento('Succo di mela', 46, 0.1, 11.3, 0.1, cBevande, unita: 'ml', porzione: 200),
  Alimento('Caffè (espresso)', 2, 0.1, 0.3, 0, cBevande, unita: 'ml', porzione: 30, alias: 'caffe'),
  Alimento('Tè (senza zucchero)', 1, 0, 0.2, 0, cBevande, unita: 'ml', porzione: 200, alias: 'te'),

  // ---- Integratori ----
  Alimento('Proteine in polvere (whey)', 390, 78, 8, 5, cAltro, porzione: 30, alias: 'whey integratore shake', tag: {'latticini'}),
  Alimento('Proteine vegetali in polvere', 380, 75, 8, 6, cAltro, porzione: 30, alias: 'proteine soia piselli integratore shake vegana'),
  Alimento('Barretta proteica', 370, 30, 35, 12, cAltro, porzione: 60, tag: {'latticini'}),
];

/// Una voce del diario: un alimento con la quantità e i valori già calcolati.
class VoceCibo {
  String nome;
  double quantita;
  String unita;
  Alimento? alimento;
  double kcal100;
  double p100;
  double c100;
  double g100;

  /// Vero se i valori sono una stima dell'AI (alimento non presente in tabella).
  bool stima;

  /// Vero se non sono riuscito a riconoscere l'alimento: da scegliere a mano.
  bool nonTrovato;

  VoceCibo({
    required this.nome,
    required this.quantita,
    required this.unita,
    this.alimento,
    this.kcal100 = 0,
    this.p100 = 0,
    this.c100 = 0,
    this.g100 = 0,
    this.stima = false,
    this.nonTrovato = false,
  });

  factory VoceCibo.daAlimento(Alimento a, double quantita) => VoceCibo(
        nome: a.nome,
        quantita: quantita,
        unita: a.unita,
        alimento: a,
        kcal100: a.kcal,
        p100: a.p,
        c100: a.c,
        g100: a.g,
      );

  double get kcal => kcal100 * quantita / 100;
  double get proteine => p100 * quantita / 100;
  double get carboidrati => c100 * quantita / 100;
  double get grassi => g100 * quantita / 100;

  /// Sostituisce l'alimento riconosciuto (per esempio da "crudo" a "cotto").
  void usa(Alimento a) {
    nome = a.nome;
    unita = a.unita;
    alimento = a;
    kcal100 = a.kcal;
    p100 = a.p;
    c100 = a.c;
    g100 = a.g;
    stima = false;
    nonTrovato = false;
  }
}

// ---------------------------------------------------------------- ricerca

/// Articoli e preposizioni, ignorati nel confronto dei nomi. "crudo" e
/// "cotto" no: servono per scegliere la versione giusta.
const Set<String> _paroleVuote = {
  'di', 'del', 'della', 'dei', 'delle', 'dello', 'al', 'alla', 'con', 'e', 'a', 'da', 'il', 'la', 'le', 'lo', 'un', 'una',
  'uno', 'in', 'o', 'd', 'senza', 'pelle', 'sott',
};

List<String> _paroleCibo(String testo) {
  final risultato = <String>[];
  for (var w in normalizzaNome(testo).split(' ')) {
    if (w.isEmpty || _paroleVuote.contains(w) || int.tryParse(w) != null) continue;
    if (w == 'cruda' || w == 'crudi' || w == 'crude') w = 'crudo';
    if (w == 'cotta' || w == 'cotti' || w == 'cotte') w = 'cotto';
    risultato.add(w);
  }
  return risultato;
}

class _VoceAlimento {
  final Alimento alimento;
  final List<String> nome;
  final List<String> alias;
  const _VoceAlimento(this.alimento, this.nome, this.alias);
}

List<_VoceAlimento>? _indice;

List<_VoceAlimento> _voci() {
  return _indice ??= [
    for (final a in alimenti) _VoceAlimento(a, _paroleCibo(a.nome), _paroleCibo(a.alias)),
  ];
}

/// L'alimento della tabella che corrisponde al nome indicato (anche scritto
/// con qualche errore). [stato] ("crudo" o "cotto") sceglie la versione quando
/// ce ne sono due. Se non c'è nulla di abbastanza vicino restituisce null.
Alimento? trovaAlimento(String nome, {String? stato}) {
  final q = _paroleCibo(nome);
  if (q.isEmpty) return null;
  final statoNorm = stato == null ? null : _paroleCibo(stato).firstWhere((_) => true, orElse: () => '');
  _VoceAlimento? migliore;
  var punteggioMigliore = 0.0;
  for (final v in _voci()) {
    final tutte = [...v.nome, ...v.alias];
    var trovate = 0;
    for (final w in q) {
      if (tutte.any((t) => parolaSimile(w, t))) trovate++;
    }
    if (trovate != q.length) continue;
    var punteggio = 1.0;
    // Il nome che comincia con la parola cercata vale di più ("olio" → olio d'oliva, non "tonno sott'olio").
    if (v.nome.isNotEmpty && q.any((w) => parolaSimile(w, v.nome.first))) punteggio += 0.5;
    if (v.nome.length == q.length) punteggio += 0.25;
    // A parità, la versione richiesta (crudo/cotto).
    if (statoNorm != null && statoNorm.isNotEmpty && v.nome.contains(statoNorm)) punteggio += 0.1;
    if (punteggio > punteggioMigliore) {
      punteggioMigliore = punteggio;
      migliore = v;
    }
  }
  return migliore?.alimento;
}

/// Ricerca a mano: ogni parola digitata deve comparire (anche in parte o con un errore) nel nome o negli alias.
List<Alimento> cercaAlimenti(String testo) {
  final q = normalizzaNome(testo).split(' ').where((w) => w.isNotEmpty).toList();
  if (q.isEmpty) return alimenti;
  final risultato = <Alimento>[];
  for (final v in _voci()) {
    final tutte = [...v.nome, ...v.alias];
    final ok = q.every((w) => tutte.any((t) => t.startsWith(w) || (w.length >= 3 && t.contains(w)) || parolaSimile(w, t)));
    if (ok) risultato.add(v.alimento);
  }
  return risultato;
}

/// Vero se l'alimento va escluso per il tipo di dieta o per le parole indicate
/// (es. "pesce, latticini, glutine, noci").
bool alimentoEscluso(Alimento a, {String tipo = 'Onnivoro', String esclusioni = ''}) {
  if (tipo == 'Vegetariano' && (a.tag.contains('carne') || a.tag.contains('pesce'))) return true;
  if (tipo == 'Vegano' &&
      (a.tag.contains('carne') || a.tag.contains('pesce') || a.tag.contains('latticini') || a.tag.contains('uova') || a.tag.contains('miele'))) {
    return true;
  }
  const sinonimi = {
    'carne': 'carne',
    'pesce': 'pesce',
    'latticini': 'latticini',
    'lattosio': 'latticini',
    'latte': 'latticini',
    'uova': 'uova',
    'uovo': 'uova',
    'glutine': 'glutine',
    'frutta secca': 'fruttasecca',
    'noci': 'fruttasecca',
    'arachidi': 'fruttasecca',
    'alcol': 'alcol',
    'miele': 'miele',
  };
  final nomeNorm = normalizzaNome('${a.nome} ${a.alias}');
  for (final voce in esclusioni.split(RegExp(r'[,;\n]'))) {
    final parola = normalizzaNome(voce);
    if (parola.isEmpty) continue;
    final tag = sinonimi[parola];
    if (tag != null && a.tag.contains(tag)) return true;
    if (nomeNorm.split(' ').any((t) => parolaSimile(parola, t) || t == parola)) return true;
  }
  return false;
}

// ----------------------------------------------------------- testo libero

final RegExp _separatori = RegExp(r'\s*(?:,|;|\n|\+|\s+e\s+)\s*', caseSensitive: false);
final RegExp _quantitaIniziale = RegExp(r"^(\d+(?:[.,]\d+)?)\s*(kg|grammi|gr|g|ml|cl|l)?\b\s*(?:di\s+|d')?(.*)$", caseSensitive: false);

/// Lettore semplice per quando l'AI non è disponibile: capisce frasi come
/// "120 g pollo, 2 yogurt greco, una birra". Per un numero senza unità usa il
/// peso tipico dell'alimento (uno yogurt, un uovo...).
List<VoceCibo> vociDaTestoLocale(String testo) {
  final risultato = <VoceCibo>[];
  for (var pezzo in testo.split(_separatori)) {
    pezzo = pezzo.trim();
    if (pezzo.isEmpty) continue;
    double? numero;
    String? unita;
    var nome = pezzo;
    final m = _quantitaIniziale.firstMatch(pezzo);
    if (m != null && (m.group(3) ?? '').trim().isNotEmpty) {
      numero = double.tryParse(m.group(1)!.replaceAll(',', '.'));
      unita = m.group(2)?.toLowerCase();
      nome = m.group(3)!.trim();
    } else {
      final articolo = RegExp(r'^(un|uno|una|mezzo|mezza)\s+(.*)$', caseSensitive: false).firstMatch(pezzo);
      if (articolo != null) {
        numero = articolo.group(1)!.toLowerCase().startsWith('mezz') ? 0.5 : 1;
        nome = articolo.group(2)!.trim();
      }
    }
    final alimento = trovaAlimento(nome);
    if (alimento == null) {
      risultato.add(VoceCibo(nome: nome, quantita: numero ?? 1, unita: unita == 'ml' || unita == 'cl' || unita == 'l' ? 'ml' : 'g', nonTrovato: true));
      continue;
    }
    double quantita;
    if (unita == null) {
      final conta = numero ?? 1;
      quantita = conta * (alimento.porzione > 0 ? alimento.porzione : 100);
    } else if (unita == 'kg' || unita == 'l') {
      quantita = (numero ?? 1) * 1000;
    } else if (unita == 'cl') {
      quantita = (numero ?? 1) * 10;
    } else {
      quantita = numero ?? 100;
    }
    risultato.add(VoceCibo.daAlimento(alimento, quantita));
  }
  return risultato;
}
