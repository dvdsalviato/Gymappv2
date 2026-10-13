class StoricoEntry {
  final int? id;
  final int esercizioId;
  final int serieNumero;
  final double carico;
  final int rep;
  final String data; // ISO8601

  StoricoEntry({
    this.id,
    required this.esercizioId,
    required this.serieNumero,
    required this.carico,
    required this.rep,
    required this.data,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'esercizio_id': esercizioId,
      'serie_numero': serieNumero,
      'carico': carico,
      'rep': rep,
      'data': data,
    };
  }

  factory StoricoEntry.fromMap(Map<String, dynamic> map) {
    return StoricoEntry(
      id: map['id'] as int?,
      esercizioId: map['esercizio_id'] as int,
      serieNumero: map['serie_numero'] as int,
      carico: (map['carico'] as num).toDouble(),
      rep: map['rep'] as int,
      data: map['data'] as String,
    );
  }
}
