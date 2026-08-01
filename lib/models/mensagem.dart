class Mensagem {
  final String id;
  final String solicitacaoId;
  final String texto;
  final String autorNome;
  final String autorTipo;
  final DateTime createdAt;

  Mensagem({
    required this.id,
    required this.solicitacaoId,
    required this.texto,
    required this.autorNome,
    required this.autorTipo,
    required this.createdAt,
  });

  factory Mensagem.fromJson(Map<String, dynamic> json) {
    return Mensagem(
      id: json['id'] ?? '',
      solicitacaoId: json['solicitacaoId'] ?? '',
      texto: json['texto'] ?? '',
      autorNome: json['autorNome'] ?? 'Anônimo',
      autorTipo: json['autorTipo'] ?? 'ENTREGADOR',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }
}
