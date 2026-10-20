import 'package:flutter_test/flutter_test.dart';
import 'package:gymapp_v2/data/superset.dart';
import 'package:gymapp_v2/models/esercizio.dart';
import 'package:gymapp_v2/state/sessione_allenamento.dart';

VoceCoda _v(String nome, int ordine, int superset, int serie) => VoceCoda(
      Esercizio(
        id: ordine + 1,
        schedaId: 1,
        nome: nome,
        ordine: ordine,
        serieTotali: serie,
        repTarget: 10,
        riposoSecondi: 60,
        supersetId: superset,
      ),
      1,
    );

/// Simula l'allenamento: "R" è un recupero, assente quando si passa subito al compagno.
String _simula(List<VoceCoda> iniziale) {
  final coda = raggruppaSuperset(iniziale);
  final passi = <String>[];
  while (coda.isNotEmpty) {
    final c = coda.first;
    passi.add('${c.esercizio.nome}${c.numeroSerie}');
    final subito = transizioneSuperset(coda);
    final compagno = compagnoSuperset(coda);
    avanzaCoda(coda, compagno);
    if (!subito) passi.add('R');
  }
  return passi.join(' ');
}

void main() {
  test('senza superset ogni esercizio va avanti da solo, con il recupero', () {
    expect(_simula([_v('A', 0, 0, 2), _v('B', 1, 0, 1)]), 'A1 R A2 R B1 R');
  });

  test('coppia con un numero di serie diverso, poi un esercizio normale', () {
    expect(
      _simula([_v('A', 0, 1, 3), _v('B', 1, 1, 2), _v('C', 2, 0, 2)]),
      'A1 B1 R A2 B2 R A3 R C1 R C2 R',
    );
  });

  test('triserie', () {
    expect(
      _simula([_v('A', 0, 1, 2), _v('B', 1, 1, 2), _v('C', 2, 1, 2)]),
      'A1 B1 C1 R A2 B2 C2 R',
    );
  });

  test('esercizi dello stesso superset separati da un altro vengono riuniti', () {
    expect(
      _simula([_v('A', 0, 1, 2), _v('B', 1, 0, 2), _v('C', 2, 1, 2)]),
      'A1 C1 R A2 C2 R B1 R B2 R',
    );
  });

  test('un esercizio prima e uno dopo il superset', () {
    expect(
      _simula([_v('X', 0, 0, 1), _v('A', 1, 2, 2), _v('B', 2, 2, 2), _v('Y', 3, 0, 1)]),
      'X1 R A1 B1 R A2 B2 R Y1 R',
    );
  });
}
