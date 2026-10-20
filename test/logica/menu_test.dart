import 'package:flutter_test/flutter_test.dart';
import 'package:gymapp_v2/data/alimenti.dart';
import 'package:gymapp_v2/data/menu_settimanale.dart';

void main() {
  group('menuDaModelli', () {
    for (final tipo in const ['Onnivoro', 'Vegetariano', 'Vegano']) {
      for (final pasti in const [3, 4, 5]) {
        test('$tipo, $pasti pasti: 7 giorni completi', () {
          final giorni = menuDaModelli(pasti: pasti, tipoDieta: tipo, esclusioni: '');
          expect(giorni.length, 7);
          for (final g in giorni) {
            expect(g.pasti.length, nomiPasti(pasti).length);
            for (final p in g.pasti) {
              expect(p.items, isNotEmpty);
              for (final i in p.items) {
                expect(alimentoEscluso(i.alimento, tipo: tipo), isFalse, reason: '${i.alimento.nome} in dieta $tipo');
              }
            }
          }
        });
      }
    }

    test('le parole da evitare vengono rispettate', () {
      final giorni = menuDaModelli(pasti: 4, tipoDieta: 'Onnivoro', esclusioni: 'glutine, pesce');
      expect(giorni.length, 7);
      for (final g in giorni) {
        expect(g.pasti.length, 4, reason: 'deve restare una colazione anche senza glutine');
        for (final p in g.pasti) {
          for (final i in p.items) {
            expect(i.alimento.tag.contains('glutine'), isFalse, reason: i.alimento.nome);
            expect(i.alimento.tag.contains('pesce'), isFalse, reason: i.alimento.nome);
          }
        }
      }
    });
  });

  group('scalaGiorno', () {
    for (final tipo in const ['Onnivoro', 'Vegetariano']) {
      for (final pasti in const [4, 5]) {
        test('$tipo, $pasti pasti: i macro si avvicinano all\'obiettivo', () {
          final giorni = menuDaModelli(pasti: pasti, tipoDieta: tipo, esclusioni: '');
          for (final g in giorni) {
            scalaGiorno(g, proteine: 160, carboidrati: 280, grassi: 65, tipoDieta: tipo);
            final t = g.totali;
            expect((t.proteine - 160).abs() / 160, lessThanOrEqualTo(0.12), reason: 'proteine ${t.proteine}');
            expect((t.carboidrati - 280).abs() / 280, lessThanOrEqualTo(0.06), reason: 'carboidrati ${t.carboidrati}');
            expect((t.grassi - 65).abs() / 65, lessThanOrEqualTo(0.15), reason: 'grassi ${t.grassi}');
          }
        });
      }
    }

    test('le quantità sono multipli di 5 e mai sotto 5', () {
      final giorni = menuDaModelli(pasti: 4, tipoDieta: 'Onnivoro', esclusioni: '');
      for (final g in giorni) {
        scalaGiorno(g, proteine: 150, carboidrati: 250, grassi: 60);
        for (final p in g.pasti) {
          for (final i in p.items) {
            expect(i.grammi, greaterThanOrEqualTo(5));
            expect(i.grammi % 5, 0);
          }
        }
      }
    });
  });

  test('il salvataggio in JSON e la rilettura danno lo stesso giorno', () {
    final giorno = menuDaModelli(pasti: 3, tipoDieta: 'Onnivoro', esclusioni: '').first;
    final letto = giornoDaJson(giornoInJson(giorno))!;
    expect(letto.pasti.length, giorno.pasti.length);
    for (var p = 0; p < giorno.pasti.length; p++) {
      expect(letto.pasti[p].nome, giorno.pasti[p].nome);
      expect(letto.pasti[p].items.length, giorno.pasti[p].items.length);
      for (var i = 0; i < giorno.pasti[p].items.length; i++) {
        expect(letto.pasti[p].items[i].alimento.nome, giorno.pasti[p].items[i].alimento.nome);
        expect(letto.pasti[p].items[i].grammi, giorno.pasti[p].items[i].grammi);
      }
    }
  });

  test('una risposta dell\'AI con meno di 7 giorni viene rifiutata', () {
    final giorno = giornoInJson(menuDaModelli(pasti: 3, tipoDieta: 'Onnivoro', esclusioni: '').first);
    expect(giorniDaJsonAi({'giorni': [giorno, giorno]}), isNull);
    expect(giorniDaJsonAi({'giorni': List.filled(7, giorno)})?.length, 7);
  });

  test('gli alimenti sconosciuti nella risposta dell\'AI vengono scartati', () {
    final giorno = giornoDaJson({
      'pasti': [
        {
          'nome': 'Pranzo',
          'alimenti': [
            {'nome': 'Riso (crudo)', 'g': 80},
            {'nome': 'zxqwv inesistente', 'g': 100},
          ],
        },
      ],
    })!;
    expect(giorno.pasti.single.items.length, 1);
  });

  test('la lista della spesa somma le quantità della settimana', () {
    final riso = alimentoPerNome('Riso (crudo)')!;
    final mela = alimentoPerNome('Mela')!;
    final g1 = GiornoMenu([PastoMenu('Pranzo', [ItemMenu(riso, 80)]), PastoMenu('Spuntino', [ItemMenu(mela, 150)])]);
    final g2 = GiornoMenu([PastoMenu('Pranzo', [ItemMenu(riso, 90)])]);
    final lista = listaSpesa([g1, g2]);
    final cereali = lista[cCereali]!.firstWhere((v) => v.alimento.nome == 'Riso (crudo)');
    expect(cereali.grammi, 170);
    expect(lista[cFrutta]!.single.grammi, 150);
    expect(listaSpesaTesto(lista), contains('Riso (crudo): 170 g'));
  });

  test('quantitaTesto', () {
    expect(quantitaTesto(250, 'g'), '250 g');
    expect(quantitaTesto(1500, 'g'), '1,5 kg');
    expect(quantitaTesto(1000, 'ml'), '1 l');
    expect(quantitaTesto(330, 'ml'), '330 ml');
  });
}
