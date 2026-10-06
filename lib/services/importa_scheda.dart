import '../db/database_helper.dart';
import '../models/esercizio.dart';
import '../models/scheda.dart';
import 'condivisione_scheda.dart';

/// Salva nel database una scheda ricevuta (da QR o da un amico).
Future<void> salvaSchedaImportata(SchedaImportata importata) async {
  final nuovaSchedaId = await DatabaseHelper.instance.insertScheda(
    Scheda(nome: importata.nome, dataCreazione: DateTime.now().toIso8601String()),
  );
  for (var i = 0; i < importata.esercizi.length; i++) {
    final e = importata.esercizi[i];
    await DatabaseHelper.instance.insertEsercizio(
      Esercizio(
        schedaId: nuovaSchedaId,
        nome: e.nome,
        ordine: i,
        serieTotali: e.serieTotali,
        repTarget: e.repTarget,
        riposoSecondi: e.riposoSecondi,
        categoria: e.categoria,
        note: e.note,
        aTempo: e.aTempo,
      ),
    );
  }
}
