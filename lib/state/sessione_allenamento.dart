import '../models/esercizio.dart';

enum FaseAllenamento { pronto, inCorso, riposo, completato }

/// Un esercizio in coda durante l'allenamento, con la prossima serie da
/// fare. Permette di saltare/spostarsi tra esercizi e ritrovarli più avanti
/// nella coda senza perdere il punto in cui si era arrivati con ciascuno.
class VoceCoda {
  final Esercizio esercizio;
  int numeroSerie;

  VoceCoda(this.esercizio, this.numeroSerie);
}

/// Istantanea di un allenamento messo in pausa: l'intera coda rimanente,
/// la scheda a cui appartiene, e — se si era a metà di un riposo — quanti
/// secondi restavano, così il countdown riprende da dove era rimasto
/// invece di ripartire da capo o saltare all'esercizio successivo.
/// Vive solo in memoria finché l'app resta aperta: lo storico già salvato
/// non si perde comunque.
class SessioneAllenamentoInPausa {
  final List<VoceCoda> coda;
  final String nomeScheda;
  final FaseAllenamento fase;
  final int secondiRimanenti;
  final int secondiTotali;

  SessioneAllenamentoInPausa({
    required this.coda,
    required this.nomeScheda,
    this.fase = FaseAllenamento.pronto,
    this.secondiRimanenti = 0,
    this.secondiTotali = 0,
  });
}

class GestoreSessione {
  static SessioneAllenamentoInPausa? inPausa;

  /// Quando è iniziato l'allenamento attuale (anche se in pausa). Serve alla
  /// Home per mostrare il timer. Torna a null quando l'allenamento finisce.
  static DateTime? inizioAllenamento;
}
