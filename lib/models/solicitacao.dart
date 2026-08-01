class Solicitacao {
  final String id;
  final String tipo;
  final String descricaoItem;
  final String localDestino;
  final String? rackOuSlide;
  final bool temFoto;
  final String urgencia;
  final String status;
  final bool favorito;
  final String solicitanteNome;
  final String? entregadorNome;
  final int versao;
  final DateTime criadaEm;
  final DateTime atualizadaEm;
  final DateTime? entregueEm;
  final String? enderecoEstoque;
  final String? enderecoAlteradoPor;

  Solicitacao({
    required this.id,
    required this.tipo,
    required this.descricaoItem,
    required this.localDestino,
    this.rackOuSlide,
    required this.temFoto,
    required this.urgencia,
    required this.status,
    required this.favorito,
    required this.solicitanteNome,
    this.entregadorNome,
    required this.versao,
    required this.criadaEm,
    required this.atualizadaEm,
    this.entregueEm,
    this.enderecoEstoque,
    this.enderecoAlteradoPor,
  });

  factory Solicitacao.fromJson(Map<String, dynamic> json) {
    return Solicitacao(
      id: json['id'],
      tipo: json['tipo'],
      descricaoItem: json['descricaoItem'],
      localDestino: json['localDestino'],
      rackOuSlide: json['rackOuSlide'],
      temFoto: json['temFoto'] ?? false,
      urgencia: json['urgencia'],
      status: json['status'] ?? 'PENDENTE',
      favorito: json['favorito'] ?? false,
      solicitanteNome: json['solicitanteNome'],
      entregadorNome: json['entregadorNome'],
      versao: json['versao'] ?? 1,
      criadaEm: DateTime.parse(json['criadaEm']),
      atualizadaEm: DateTime.parse(json['atualizadaEm']),
      entregueEm: json['entregueEm'] != null
          ? DateTime.parse(json['entregueEm'])
          : null,
      enderecoEstoque: json['enderecoEstoque'],
      enderecoAlteradoPor: json['enderecoAlteradoPor'],
    );
  }
}