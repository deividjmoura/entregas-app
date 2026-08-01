class Mensagem {
  final String id;
  final String solicitacaoId;
  final String texto;
  final String autorNome;
  final String autorTipo; // SOLICITANTE | ENTREGADOR
  final DateTime criadaEm;

  Mensagem({
    required this.id,
    required this.solicitacaoId,
    required this.texto,
    required this.autorNome,
    required this.autorTipo,
    required this.criadaEm,
  });

  factory Mensagem.fromJson(Map<String, dynamic> json) {
    return Mensagem(
      id: json['id']?.toString() ?? '',
      solicitacaoId: json['solicitacaoId']?.toString() ?? '',
      texto: json['texto']?.toString() ?? '',
      autorNome: json['autorNome']?.toString() ?? 'Anônimo',
      autorTipo: json['autorTipo']?.toString() ?? 'ENTREGADOR',
      criadaEm: DateTime.tryParse(
            (json['criadaEm'] ?? json['createdAt'])?.toString() ?? '',
          ) ??
          DateTime.now(),
    );
  }

  bool get isEntregador => autorTipo.toUpperCase() == 'ENTREGADOR';
}
