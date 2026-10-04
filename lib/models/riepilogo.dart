import '../data/muscoli.dart';

class EsercizioRiepilogo {
  final String nome;
  final String categoria;
  final int serie;
  final double caricoMax;
  final double volume;
  final bool record;
  final bool aTempo;
  final int secondi; // tempo totale, per gli esercizi a tempo

  const EsercizioRiepilogo(
    this.nome,
    this.categoria,
    this.serie,
    this.caricoMax,
    this.volume,
    this.record, {
    this.aTempo = false,
    this.secondi = 0,
  });
}

class RiepilogoSessione {
  final String nomeScheda;
  final Duration durata;
  final List<EsercizioRiepilogo> esercizi;

  const RiepilogoSessione(this.nomeScheda, this.durata, this.esercizi);

  int get serie => esercizi.fold(0, (a, e) => a + e.serie);
  double get volume => esercizi.fold(0.0, (a, e) => a + e.volume);
  int get record => esercizi.where((e) => e.record).length;

  /// Nomi dei muscoli lavorati, nell'ordine della lista dei muscoli.
  List<String> get muscoliLavorati {
    final ids = <String>{};
    for (final e in esercizi) {
      final id = muscoloDi(e.nome, e.categoria);
      if (id != null) ids.add(id);
    }
    return [for (final m in muscoli) if (ids.contains(m.id)) m.nome];
  }
}
