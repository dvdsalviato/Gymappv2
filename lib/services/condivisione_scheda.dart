import 'dart:convert';
import '../models/esercizio.dart';

/// Trasforma una scheda (nome + esercizi) in una stringa JSON compatta,
/// abbastanza piccola da entrare in un QR code.
String codificaScheda(String nomeScheda, List<Esercizio> esercizi) {
  final mappa = {
    'n': nomeScheda,
    'e': esercizi
        .map((e) => {
              'n': e.nome,
              's': e.serieTotali,
              'r': e.repTarget,
              'rp': e.riposoSecondi,
              'c': e.categoria,
              if (e.note != null && e.note!.isNotEmpty) 'no': e.note,
            })
        .toList(),
  };
  return jsonEncode(mappa);
}

/// Una scheda letta da un QR, non ancora salvata nel database (schedaId e
/// ordine vanno assegnati da chi la importa).
class SchedaImportata {
  final String nome;
  final List<Esercizio> esercizi;

  SchedaImportata(this.nome, this.esercizi);
}

/// Prova a leggere il testo di un QR come scheda Gymapp. Restituisce null
/// se il testo non è nel formato atteso (es. QR di un'altra app).
SchedaImportata? decodificaScheda(String testo) {
  try {
    final mappa = jsonDecode(testo) as Map<String, dynamic>;
    final nome = mappa['n'] as String;
    final voci = mappa['e'] as List;

    final esercizi = <Esercizio>[];
    for (var i = 0; i < voci.length; i++) {
      final m = voci[i] as Map<String, dynamic>;
      esercizi.add(Esercizio(
        schedaId: -1, // placeholder: verrà sostituito dopo aver creato la scheda
        nome: m['n'] as String,
        ordine: i,
        serieTotali: m['s'] as int,
        repTarget: m['r'] as int,
        riposoSecondi: m['rp'] as int,
        categoria: (m['c'] as String?) ?? 'Altro',
        note: m['no'] as String?,
      ));
    }
    if (esercizi.isEmpty) return null;
    return SchedaImportata(nome, esercizi);
  } catch (_) {
    return null;
  }
}
