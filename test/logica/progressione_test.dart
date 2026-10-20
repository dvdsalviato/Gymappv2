import 'package:flutter_test/flutter_test.dart';
import 'package:gymapp_v2/data/progressione.dart';

void main() {
  testRiposo();

  group('incrementoCarico', () {
    test('fondamentale delle gambe: circa 5%', () {
      expect(incrementoCarico(100, 'Squat con bilanciere'), 5);
    });
    test('multiarticolare: almeno 2,5 kg', () {
      expect(incrementoCarico(80, 'Panca piana con bilanciere'), 2.5);
    });
    test('isolamento: almeno 1 kg', () {
      expect(incrementoCarico(12, 'Curl con manubri'), 1);
    });
  });

  group('suggerisciCarico', () {
    test('sale quando raggiungi le ripetizioni in tutte le serie', () {
      final s = suggerisciCarico(100, 10, 10, nome: 'Squat con bilanciere')!;
      expect(s.carico, 105);
      expect(s.aumento, isTrue);
    });
    test('non sale se alcune serie erano sotto', () {
      final s = suggerisciCarico(80, 8, 8, nome: 'Panca piana con bilanciere', consentiAumento: false)!;
      expect(s.carico, 80);
      expect(s.aumento, isFalse);
    });
    test('resta sullo stesso carico se le ripetizioni sono quasi al target', () {
      final s = suggerisciCarico(100, 6, 10, nome: 'Squat con bilanciere')!;
      expect(s.carico, 100);
      expect(s.aumento, isFalse);
    });
    test('scende se fai meno della metà delle ripetizioni', () {
      final s = suggerisciCarico(100, 3, 10, nome: 'Squat con bilanciere')!;
      expect(s.carico, 90);
      expect(s.aumento, isFalse);
    });
    test('nessun suggerimento senza dati', () {
      expect(suggerisciCarico(0, 10, 10), isNull);
      expect(suggerisciCarico(50, 0, 10), isNull);
    });
  });
}

void testRiposo() {
  group('riposoConsigliato', () {
    test('fondamentale delle gambe: 3 minuti', () => expect(riposoConsigliato('Squat con bilanciere'), 180));
    test('multiarticolare: 2 minuti', () => expect(riposoConsigliato('Panca piana con bilanciere'), 120));
    test('isolamento: 75 secondi', () => expect(riposoConsigliato('Curl con manubri'), 75));
  });
}
