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
  final double? volumePrima; // volume dell'ultima volta (null se è la prima)

  const EsercizioRiepilogo(
    this.nome,
    this.categoria,
    this.serie,
    this.caricoMax,
    this.volume,
    this.record, {
    this.aTempo = false,
    this.secondi = 0,
    this.volumePrima,
  });

  /// Variazione percentuale del volume rispetto all'ultima volta.
  double? get variazione {
    final p = volumePrima;
    if (aTempo || p == null || p <= 0 || volume <= 0) return null;
    return (volume - p) / p * 100;
  }
}

class RiepilogoSessione {
  final String nomeScheda;
  final Duration durata;
  final List<EsercizioRiepilogo> esercizi;

  const RiepilogoSessione(this.nomeScheda, this.durata, this.esercizi);

  int get serie => esercizi.fold(0, (a, e) => a + e.serie);
  double get volume => esercizi.fold(0.0, (a, e) => a + e.volume);
  int get record => esercizi.where((e) => e.record).length;

  /// Variazione del volume totale, contando solo gli esercizi già fatti prima.
  double? get variazioneVolume {
    var ora = 0.0;
    var prima = 0.0;
    for (final e in esercizi) {
      if (e.variazione == null) continue;
      ora += e.volume;
      prima += e.volumePrima!;
    }
    if (prima <= 0) return null;
    return (ora - prima) / prima * 100;
  }

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
