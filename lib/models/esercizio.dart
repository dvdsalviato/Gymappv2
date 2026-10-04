class Esercizio {
  final int? id;
  final int schedaId;
  final String nome;
  final int ordine;
  final int serieTotali;
  final int repTarget;
  final int riposoSecondi;
  final String? note;
  final String categoria;

  /// Se vero l'esercizio è a tempo: [repTarget] contiene la durata in secondi.
  final bool aTempo;

  Esercizio({
    this.id,
    required this.schedaId,
    required this.nome,
    required this.ordine,
    required this.serieTotali,
    required this.repTarget,
    required this.riposoSecondi,
    this.note,
    this.categoria = 'Altro',
    this.aTempo = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'scheda_id': schedaId,
      'nome': nome,
      'ordine': ordine,
      'serie_totali': serieTotali,
      'rep_target': repTarget,
      'riposo_secondi': riposoSecondi,
      'note': note,
      'categoria': categoria,
      'a_tempo': aTempo ? 1 : 0,
    };
  }

  factory Esercizio.fromMap(Map<String, dynamic> map) {
    return Esercizio(
      id: map['id'] as int?,
      schedaId: map['scheda_id'] as int,
      nome: map['nome'] as String,
      ordine: map['ordine'] as int,
      serieTotali: map['serie_totali'] as int,
      repTarget: map['rep_target'] as int,
      riposoSecondi: map['riposo_secondi'] as int,
      note: map['note'] as String?,
      categoria: (map['categoria'] as String?) ?? 'Altro',
      aTempo: (map['a_tempo'] as int?) == 1,
    );
  }
}
