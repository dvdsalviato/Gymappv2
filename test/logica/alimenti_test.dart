import 'package:flutter_test/flutter_test.dart';
import 'package:gymapp_v2/data/alimenti.dart';

void main() {
  test('i nomi degli alimenti sono tutti diversi', () {
    final nomi = alimenti.map((a) => a.nome).toList();
    expect(nomi.toSet().length, nomi.length);
  });

  test('calorie e macro di ogni alimento sono coerenti', () {
    for (final a in alimenti) {
      final calcolate = 4 * a.p + 4 * a.c + 9 * a.g + 7 * a.alcol;
      final tolleranza = a.kcal * 0.15 > 12 ? a.kcal * 0.15 : 12;
      expect((calcolate - a.kcal).abs(), lessThanOrEqualTo(tolleranza), reason: a.nome);
    }
  });

  group('trovaAlimento', () {
    final casi = <String, String>{
      'pollo': 'Petto di pollo (crudo)',
      'pollo cotto': 'Petto di pollo (cotto)',
      'petto di pollo': 'Petto di pollo (crudo)',
      'prosciutto cotto': 'Prosciutto cotto',
      'prosciutto crudo': 'Prosciutto crudo',
      'yogurt greco': 'Yogurt greco (0% grassi)',
      'yougurt greco': 'Yogurt greco (0% grassi)',
      'olio': "Olio extravergine d'oliva",
      'latte': 'Latte parzialmente scremato',
      'pasta': 'Pasta di semola (cruda)',
      'riso': 'Riso (crudo)',
      'birra': 'Birra',
      'birra media': 'Birra',
      'uovo': 'Uova (intere)',
      'caffè': 'Caffè (espresso)',
      'whey': 'Proteine in polvere (whey)',
    };
    casi.forEach((cerca, atteso) {
      test('"$cerca" è $atteso', () {
        expect(trovaAlimento(cerca)?.nome, atteso);
      });
    });

    test('lo stato crudo o cotto sceglie la versione', () {
      expect(trovaAlimento('pollo', stato: 'cotto')?.nome, 'Petto di pollo (cotto)');
      expect(trovaAlimento('pasta', stato: 'cotto')?.nome, 'Pasta di semola (cotta)');
    });

    test('un nome strano non corrisponde a nulla', () {
      expect(trovaAlimento('qualcosa di strano'), isNull);
    });
  });

  test('il lettore semplice capisce quantità e porzioni', () {
    final v = vociDaTestoLocale('120 g di pollo, 2 yogurt greco, una birra');
    expect(v.length, 3);
    expect(v[0].nome, 'Petto di pollo (crudo)');
    expect(v[0].quantita, 120);
    expect(v[1].nome, 'Yogurt greco (0% grassi)');
    expect(v[1].quantita, 300);
    expect(v[2].nome, 'Birra');
    expect(v[2].quantita, 330);
    expect(v[2].unita, 'ml');
    expect(v[0].proteine, closeTo(27.6, 0.1));
  });

  test('un alimento sconosciuto viene segnalato', () {
    final v = vociDaTestoLocale('50 g di unobbyobby');
    expect(v.single.nonTrovato, isTrue);
  });

  group('alimentoEscluso', () {
    Alimento a(String nome) => trovaAlimento(nome)!;
    test('vegano esclude uova e latticini, non il tofu', () {
      expect(alimentoEscluso(a('uova'), tipo: 'Vegano'), isTrue);
      expect(alimentoEscluso(a('mozzarella'), tipo: 'Vegano'), isTrue);
      expect(alimentoEscluso(a('tofu'), tipo: 'Vegano'), isFalse);
    });
    test('vegetariano esclude carne e pesce, non le uova', () {
      expect(alimentoEscluso(a('pollo'), tipo: 'Vegetariano'), isTrue);
      expect(alimentoEscluso(a('salmone'), tipo: 'Vegetariano'), isTrue);
      expect(alimentoEscluso(a('uova'), tipo: 'Vegetariano'), isFalse);
    });
    test('le parole da evitare funzionano per etichetta e per nome', () {
      expect(alimentoEscluso(a('pane bianco'), esclusioni: 'glutine'), isTrue);
      expect(alimentoEscluso(a('salmone'), esclusioni: 'pesce, latticini'), isTrue);
      expect(alimentoEscluso(a('banana'), esclusioni: 'banana'), isTrue);
      expect(alimentoEscluso(a('riso'), esclusioni: 'glutine'), isFalse);
    });
  });

  test('la ricerca a mano tollera gli errori', () {
    expect(cercaAlimenti('yogurt'), isNotEmpty);
    expect(cercaAlimenti('salmne').map((e) => e.nome), contains('Salmone (crudo)'));
  });
}
