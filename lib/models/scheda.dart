class Scheda {
  final int? id;
  final String nome;
  final String dataCreazione;

  Scheda({this.id, required this.nome, required this.dataCreazione});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'data_creazione': dataCreazione,
    };
  }

  factory Scheda.fromMap(Map<String, dynamic> map) {
    return Scheda(
      id: map['id'] as int?,
      nome: map['nome'] as String,
      dataCreazione: map['data_creazione'] as String,
    );
  }
}
