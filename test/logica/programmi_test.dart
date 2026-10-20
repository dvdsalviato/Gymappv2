import 'package:flutter_test/flutter_test.dart';
import 'package:gymapp_v2/data/catalogo_esercizi.dart';
import 'package:gymapp_v2/data/programmi_pronti.dart';

void main() {
  final nomiCatalogo = catalogoEsercizi.map((e) => e.nome).toSet();

  test('ogni esercizio dei programmi esiste nel catalogo', () {
    for (final p in programmiPronti) {
      for (final g in p.schede) {
        for (final e in g.esercizi) {
          expect(nomiCatalogo, contains(e.nome), reason: '${p.nome} / ${g.nome}');
        }
      }
    }
  });

  test('ogni programma ha schede, esercizi e valori sensati', () {
    final ids = <String>{};
    for (final p in programmiPronti) {
      expect(ids.add(p.id), isTrue, reason: 'id doppio: ${p.id}');
      expect(p.schede, isNotEmpty);
      expect(p.giorni, isNotEmpty);
      for (final g in p.schede) {
        expect(g.esercizi.length, greaterThanOrEqualTo(3), reason: '${p.nome} / ${g.nome}');
        for (final e in g.esercizi) {
          expect(e.serie, inInclusiveRange(1, 8));
          expect(e.rep, greaterThan(0));
          expect(e.riposo, inInclusiveRange(30, 300));
        }
      }
    }
  });

  test('ogni superset ha almeno due esercizi e sono uno dopo l\'altro', () {
    for (final p in programmiPronti) {
      for (final g in p.schede) {
        final conta = <int, int>{};
        for (final e in g.esercizi) {
          if (e.superset != 0) conta[e.superset] = (conta[e.superset] ?? 0) + 1;
        }
        conta.forEach((id, n) => expect(n, greaterThanOrEqualTo(2), reason: '${p.nome} / ${g.nome}'));
        for (var i = 0; i < g.esercizi.length; i++) {
          final id = g.esercizi[i].superset;
          if (id == 0) continue;
          final precedente = i > 0 && g.esercizi[i - 1].superset == id;
          final successivo = i + 1 < g.esercizi.length && g.esercizi[i + 1].superset == id;
          expect(precedente || successivo, isTrue, reason: '${p.nome} / ${g.nome}: superset non contiguo');
        }
      }
    }
  });

  test('gli esercizi a tempo hanno secondi, non ripetizioni', () {
    for (final p in programmiPronti) {
      for (final g in p.schede) {
        for (final e in eserciziPerDatabase(g)) {
          if (e['aTempo'] == true) expect((e['rep'] as int), greaterThanOrEqualTo(20), reason: '${e['nome']}');
        }
      }
    }
  });
}
