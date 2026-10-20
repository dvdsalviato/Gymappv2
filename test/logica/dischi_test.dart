import 'package:flutter_test/flutter_test.dart';
import 'package:gymapp_v2/widgets/calcolatore_dischi.dart';

void main() {
  const tutti = [25.0, 20.0, 15.0, 10.0, 5.0, 2.5, 1.25];

  test('82,5 kg con bilanciere da 20: 25 + 5 + 1,25 per lato', () {
    final r = calcolaDischi(82.5, 20, tutti);
    expect(r.dischi, [25, 5, 1.25]);
    expect(r.restoPerLato, 0);
  });

  test('solo il bilanciere: nessun disco', () {
    final r = calcolaDischi(20, 20, tutti);
    expect(r.dischi, isEmpty);
    expect(r.restoPerLato, 0);
  });

  test('carico non realizzabile: resta un resto per lato', () {
    final r = calcolaDischi(21, 20, tutti);
    expect(r.dischi, isEmpty);
    expect(r.restoPerLato, 0.5);
  });

  test('senza i dischi piccoli si segnala quello che manca', () {
    final r = calcolaDischi(82.5, 20, const [20.0, 10.0, 5.0, 2.5]);
    expect(r.dischi, [20, 10]);
    expect(r.restoPerLato, 1.25);
  });
}
