class Mensagem {
  final String id;
  final String texto;
  final String autorNome;
  final DateTime criadaEm;
  final bool lida;

  Mensagem({
    required this.id,
    required this.texto,
    required this.autorNome,
    required this.criadaEm,
    this.lida = false,
  });

  factory Mensagem.fromJson(Map<String, dynamic> json) {
    return Mensagem(
      id: json['id']?.toString() ?? '',
      texto: json['texto']?.toString() ?? json['mensagem']?.toString() ?? '',
      autorNome: json['autorNome']?.toString() ??
          json['autor']?.toString() ??
          'Anônimo',
      criadaEm: DateTime.tryParse(
            (json['criadaEm'] ?? json['createdAt'] ?? '').toString(),
          ) ??
          DateTime.now(),
      lida: json['lida'] == true,
    );
  }
}
