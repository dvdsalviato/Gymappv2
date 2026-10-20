import 'package:flutter_test/flutter_test.dart';
import 'package:gymapp_v2/data/classificatore.dart';

void main() {
  group('classificaEsercizio', () {
    const casi = {
      'hyperxtension': 'Schiena', // scritto storto
      'Panca piana': 'Petto',
      'leg press': 'Gambe',
      'stacco': 'Schiena',
      'curl manubri': 'Bicipiti',
      'tapis roulant 20 min': 'Cardio',
      'Bench Press (Barbell)': 'Petto',
      'Squat (Barbell)': 'Gambe',
      'Plank': 'Core',
    };
    casi.forEach((nome, categoria) {
      test('"$nome" è $categoria', () {
        expect(classificaEsercizio(nome), categoria);
      });
    });

    test('un nome sconosciuto resta senza categoria', () {
      expect(classificaEsercizio('crossfit wod'), isNull);
    });
  });

  group('cercaCatalogo', () {
    test('trova Hyperextension anche con un errore di battitura', () {
      final nomi = cercaCatalogo('hyperxtension').map((e) => e.nome);
      expect(nomi, contains('Hyperextension'));
    });

    test('trova per nome inglese', () {
      final nomi = cercaCatalogo('dead lift').map((e) => e.nome);
      expect(nomi, contains('Stacco da terra'));
    });

    test('una ricerca vuota restituisce tutto il catalogo', () {
      expect(cercaCatalogo('').length, greaterThan(300));
    });
  });
}
