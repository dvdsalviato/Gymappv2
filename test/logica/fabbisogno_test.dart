import 'package:flutter_test/flutter_test.dart';
import 'package:gymapp_v2/data/fabbisogno.dart';

void main() {
  test('uomo, 80 kg, 180 cm, 30 anni: metabolismo basale 1780', () {
    expect(calcolaBmr(kg: 80, cm: 180, eta: 30, sesso: 'Uomo'), 1780);
  });

  test('donna, 60 kg, 165 cm, 25 anni: metabolismo basale 1345,25', () {
    expect(calcolaBmr(kg: 60, cm: 165, eta: 25, sesso: 'Donna'), closeTo(1345.25, 0.01));
  });

  test('dimagrimento: -15% e proteine 2 g per kg', () {
    final f = calcolaFabbisogno(kg: 80, cm: 180, eta: 30, sesso: 'Uomo', livelloAttivita: 2, obiettivo: 'Dimagrimento');
    expect(f.mantenimento, closeTo(2759, 0.5));
    expect(f.obiettivo, closeTo(2345.2, 0.5));
    expect(f.variazionePercento, -15);
    expect(f.proteine, closeTo(160, 0.01));
    expect(f.grassi, closeTo(65.1, 0.2));
    expect(f.carboidrati, closeTo(279.7, 0.5));
    expect(f.limitato, isFalse);
  });

  test('le calorie dei macro tornano con le calorie totali', () {
    final f = calcolaFabbisogno(kg: 75, cm: 178, eta: 28, sesso: 'Uomo', livelloAttivita: 2, obiettivo: 'Massa muscolare');
    final somma = f.proteine * 4 + f.carboidrati * 4 + f.grassi * 9;
    expect(somma, closeTo(f.obiettivo, 1));
    expect(f.obiettivo, greaterThan(f.mantenimento));
  });

  test('il deficit non scende sotto il minimo ragionevole', () {
    final f = calcolaFabbisogno(kg: 50, cm: 155, eta: 40, sesso: 'Donna', livelloAttivita: 0, obiettivo: 'Dimagrimento');
    expect(f.obiettivo, 1200);
    expect(f.limitato, isTrue);
  });

  test('con indice di massa corporea basso il dimagrimento è sconsigliato', () {
    expect(dimagrimentoSconsigliato(48, 175), isTrue);
    expect(dimagrimentoSconsigliato(75, 175), isFalse);
  });

  test('livello di attività dagli allenamenti a settimana', () {
    expect(livelloAttivitaDaAllenamenti(0.5), 0);
    expect(livelloAttivitaDaAllenamenti(2), 1);
    expect(livelloAttivitaDaAllenamenti(4), 2);
    expect(livelloAttivitaDaAllenamenti(6), 3);
  });
}
