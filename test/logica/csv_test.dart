import 'package:flutter_test/flutter_test.dart';
import 'package:gymapp_v2/data/csv_allenamenti.dart';

void main() {
  test('esporta e rilegge lo stesso storico', () {
    final righe = <Map<String, dynamic>>[
      {'id': 1, 'serie_numero': 1, 'carico': 60.0, 'rep': 10, 'data': '2024-08-13T08:47:00.000', 'esercizio_nome': 'Panca', 'a_tempo': 0, 'scheda_nome': 'Push A'},
      {'id': 2, 'serie_numero': 2, 'carico': 62.5, 'rep': 8, 'data': '2024-08-13T08:49:00.000', 'esercizio_nome': 'Panca', 'a_tempo': 0, 'scheda_nome': 'Push A'},
      {'id': 3, 'serie_numero': 1, 'carico': 0.0, 'rep': 45, 'data': '2024-08-13T08:55:00.000', 'esercizio_nome': 'Plank', 'a_tempo': 1, 'scheda_nome': 'Push A'},
    ];
    final letto = interpretaCsv(creaCsvStrong(righe));
    expect(letto.righe.length, 3);
    expect(letto.righe[0].esercizio, 'Panca');
    expect(letto.righe[0].carico, 60);
    expect(letto.righe[0].allenamento, 'Push A');
    expect(letto.righe[1].rep, 8);
    expect(letto.righe[1].carico, 62.5);
    expect(letto.righe[2].aTempo, isTrue);
    expect(letto.righe[2].rep, 45);
  });

  test('legge un file di Hevy: salta il riscaldamento e capisce la data', () {
    const hevy = 'title,start_time,end_time,description,exercise_title,superset_id,exercise_notes,set_index,set_type,weight_kg,reps,distance_km,duration_seconds,rpe\n'
        '"Gambe, giorno 2","13 Aug 2024, 08:47","13 Aug 2024, 09:40",,Squat (Barbell),,,0,warmup,40,10,,,\n'
        '"Gambe, giorno 2","13 Aug 2024, 08:47","13 Aug 2024, 09:40",,Squat (Barbell),,,1,normal,100,5,,,\n'
        '"Gambe, giorno 2","13 Aug 2024, 08:47","13 Aug 2024, 09:40",,Squat (Barbell),,,2,normal,100,5,,,\n';
    final letto = interpretaCsv(hevy);
    expect(letto.righe.length, 2);
    expect(letto.riscaldamento, 1);
    expect(letto.righe.first.allenamento, 'Gambe, giorno 2');
    expect(letto.righe.first.data, DateTime(2024, 8, 13, 8, 47));
    expect(letto.righe.first.serie, 1);
    expect(letto.righe.last.serie, 2);
    expect(letto.righe.last.carico, 100);
  });

  test('legge un file con punto e virgola e pesi in libbre', () {
    const testo = 'Date;Workout Name;Exercise Name;Set Order;Weight (lbs);Reps\n'
        '2024-01-05 18:00:00;Upper;Curl;1;25,5;12\n'
        '2024-01-05 18:00:00;Upper;Curl;2;25,5;10\n';
    final letto = interpretaCsv(testo);
    expect(letto.inLibbre, isTrue);
    expect(letto.righe.length, 2);
    expect(letto.righe.first.carico, closeTo(11.57, 0.01));
  });

  test('un file senza le colonne giuste dà un errore chiaro', () {
    expect(() => interpretaCsv('a,b\n1,2'), throwsFormatException);
  });

  test('un campo tra virgolette può contenere virgole e virgolette', () {
    final t = leggiCsv('a,b\n"x, ""y""",2\n');
    expect(t[1][0], 'x, "y"');
    expect(t[1][1], '2');
  });
}
