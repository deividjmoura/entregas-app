#!/usr/bin/env bash
set -e

echo "=== Atualizando o modelo Solicitacao (lib/models/solicitacao.dart) ==="

cat > lib/models/solicitacao.dart <<'EOF'
class Solicitacao {
  final String id;
  final String solicitanteNome;
  final String? entregadorNome;
  final String status;
  final String urgencia;
  final String tipo;
  final String descricao;
  final String? enderecoEstoque;
  final String? alteradoPor;
  final String? fotoUrl;
  final bool favorito;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Solicitacao({
    required this.id,
    required this.solicitanteNome,
    this.entregadorNome,
    required this.status,
    required this.urgencia,
    required this.tipo,
    required this.descricao,
    this.enderecoEstoque,
    this.alteradoPor,
    this.fotoUrl,
    this.favorito = false,
    this.createdAt,
    this.updatedAt,
  });

  factory Solicitacao.fromJson(Map<String, dynamic> json) {
    return Solicitacao(
      id: json['id'] ?? '',
      solicitanteNome: json['solicitanteNome'] ?? 'Solicitante Desconhecido',
      entregadorNome: json['entregadorNome'],
      status: json['status'] ?? 'PENDENTE',
      urgencia: json['urgencia'] ?? 'BAIXA',
      tipo: json['tipo'] ?? 'OUTROS',
      descricao: json['descricao'] ?? '',
      enderecoEstoque: json['enderecoEstoque'],
      alteradoPor: json['alteradoPor'],
      fotoUrl: json['fotoUrl'],
      favorito: json['favorito'] ?? false,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'solicitanteNome': solicitanteNome,
      'entregadorNome': entregadorNome,
      'status': status,
      'urgencia': urgencia,
      'tipo': tipo,
      'descricao': descricao,
      'enderecoEstoque': enderecoEstoque,
      'alteradoPor': alteradoPor,
      'fotoUrl': fotoUrl,
      'favorito': favorito,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}
EOF

echo "✨ Modelo Solicitacao atualizado com sucesso!"