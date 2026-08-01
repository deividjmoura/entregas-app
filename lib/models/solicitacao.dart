class Solicitacao {
  final String id;
  final String tipo;
  final String descricaoItem;
  final String localDestino;
  final String? rackOuSlide;
  final String? enderecoEstoque;
  final bool temFoto;
  final String? fotoUrl;
  final String urgencia;
  final String status;
  final bool favorito;
  final String solicitanteNome;
  final String? entregadorNome;
  final DateTime criadaEm;
  final DateTime atualizadaEm;
  final DateTime? entregueEm;
  final String? enderecoAlteradoPor;

  Solicitacao({
    required this.id,
    required this.tipo,
    required this.descricaoItem,
    required this.localDestino,
    this.rackOuSlide,
    this.enderecoEstoque,
    this.temFoto = false,
    this.fotoUrl,
    required this.urgencia,
    required this.status,
    this.favorito = false,
    required this.solicitanteNome,
    this.entregadorNome,
    required this.criadaEm,
    required this.atualizadaEm,
    this.entregueEm,
    this.enderecoAlteradoPor,
  });

  // ===================== GETTERS ÚTEIS =====================

  /// Tempo de espera em minutos desde a criação
  int get minutosEspera {
    return DateTime.now().difference(criadaEm).inMinutes;
  }

  /// Texto formatado do tempo de espera (ex: "12min" ou "1h 5min")
  String get tempoEsperaFormatado {
    final min = minutosEspera;
    if (min < 60) return '${min}min';
    final horas = min ~/ 60;
    final resto = min % 60;
    return resto > 0 ? '${horas}h ${resto}min' : '${horas}h';
  }

  /// Se ainda está pendente
  bool get isPendente => status == 'PENDENTE';

  /// Se está em andamento (qualquer status intermediário)
  bool get isEmAndamento =>
      status == 'EM_CURSO' || status == 'EM_ROTA' || status == 'EM_BAIXA';

  /// Se já foi finalizada
  bool get isFinalizada => status == 'ENTREGUE' || status == 'CANCELADA';

  // ===================== FROM JSON =====================

  factory Solicitacao.fromJson(Map<String, dynamic> json) {
    return Solicitacao(
      id: json['id']?.toString() ?? '',
      tipo: json['tipo']?.toString() ?? 'OUTROS',
      descricaoItem: json['descricaoItem']?.toString() ??
          json['descricao']?.toString() ??
          'Sem descrição',
      localDestino: json['localDestino']?.toString() ??
          json['destino']?.toString() ??
          'N/I',
      rackOuSlide: json['rackOuSlide']?.toString(),
      enderecoEstoque: json['enderecoEstoque']?.toString(),
      temFoto: json['temFoto'] == true ||
          (json['fotoUrl'] != null && json['fotoUrl'].toString().isNotEmpty),
      fotoUrl: json['fotoUrl']?.toString(),
      urgencia: (json['urgencia']?.toString() ?? 'BAIXA').toUpperCase(),
      status: (json['status']?.toString() ?? 'PENDENTE').toUpperCase(),
      favorito: json['favorito'] == true,
      solicitanteNome: json['solicitanteNome']?.toString() ??
          json['solicitante']?['nome']?.toString() ??
          'Desconhecido',
      entregadorNome: json['entregadorNome']?.toString() ??
          json['entregador']?['nome']?.toString(),
      criadaEm: _parseDate(json['criadaEm'] ?? json['createdAt']) ?? DateTime.now(),
      atualizadaEm: _parseDate(json['atualizadaEm'] ?? json['updatedAt']) ?? DateTime.now(),
      entregueEm: _parseDate(json['entregueEm']),
      enderecoAlteradoPor: json['enderecoAlteradoPor']?.toString(),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  // ===================== TO JSON =====================

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tipo': tipo,
      'descricaoItem': descricaoItem,
      'localDestino': localDestino,
      'rackOuSlide': rackOuSlide,
      'enderecoEstoque': enderecoEstoque,
      'temFoto': temFoto,
      'fotoUrl': fotoUrl,
      'urgencia': urgencia,
      'status': status,
      'favorito': favorito,
      'solicitanteNome': solicitanteNome,
      'entregadorNome': entregadorNome,
      'criadaEm': criadaEm.toIso8601String(),
      'atualizadaEm': atualizadaEm.toIso8601String(),
      'entregueEm': entregueEm?.toIso8601String(),
      'enderecoAlteradoPor': enderecoAlteradoPor,
    };
  }

  // ===================== COPY WITH =====================

  Solicitacao copyWith({
    String? id,
    String? tipo,
    String? descricaoItem,
    String? localDestino,
    String? rackOuSlide,
    String? enderecoEstoque,
    bool? temFoto,
    String? fotoUrl,
    String? urgencia,
    String? status,
    bool? favorito,
    String? solicitanteNome,
    String? entregadorNome,
    DateTime? criadaEm,
    DateTime? atualizadaEm,
    DateTime? entregueEm,
    String? enderecoAlteradoPor,
  }) {
    return Solicitacao(
      id: id ?? this.id,
      tipo: tipo ?? this.tipo,
      descricaoItem: descricaoItem ?? this.descricaoItem,
      localDestino: localDestino ?? this.localDestino,
      rackOuSlide: rackOuSlide ?? this.rackOuSlide,
      enderecoEstoque: enderecoEstoque ?? this.enderecoEstoque,
      temFoto: temFoto ?? this.temFoto,
      fotoUrl: fotoUrl ?? this.fotoUrl,
      urgencia: urgencia ?? this.urgencia,
      status: status ?? this.status,
      favorito: favorito ?? this.favorito,
      solicitanteNome: solicitanteNome ?? this.solicitanteNome,
      entregadorNome: entregadorNome ?? this.entregadorNome,
      criadaEm: criadaEm ?? this.criadaEm,
      atualizadaEm: atualizadaEm ?? this.atualizadaEm,
      entregueEm: entregueEm ?? this.entregueEm,
      enderecoAlteradoPor: enderecoAlteradoPor ?? this.enderecoAlteradoPor,
    );
  }
}