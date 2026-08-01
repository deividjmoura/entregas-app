import 'dart:convert';
import 'api_client.dart';

class HistoricoEstoqueItem {
  final String endereco;
  final String? alteradoPor;
  final DateTime? em;

  HistoricoEstoqueItem({
    required this.endereco,
    this.alteradoPor,
    this.em,
  });

  factory HistoricoEstoqueItem.fromJson(Map<String, dynamic> json) {
    return HistoricoEstoqueItem(
      endereco: json['endereco']?.toString() ??
          json['enderecoEstoque']?.toString() ??
          '',
      alteradoPor: json['alteradoPor']?.toString() ??
          json['enderecoAlteradoPor']?.toString(),
      em: DateTime.tryParse(
        (json['em'] ?? json['atualizadaEm'] ?? json['createdAt'] ?? '').toString(),
      ),
    );
  }
}

class EstoqueService {
  /// GET /estoque/[nome]/historico
  static Future<List<HistoricoEstoqueItem>> historico(String nomeItem) async {
    final nome = nomeItem.trim();
    if (nome.isEmpty) return [];
    final response = await ApiClient.get(
      '/estoque/${Uri.encodeComponent(nome)}/historico',
    );
    if (response.statusCode != 200) return [];
    final data = jsonDecode(response.body);
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => HistoricoEstoqueItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    if (data is Map && data['historico'] is List) {
      return (data['historico'] as List)
          .whereType<Map>()
          .map((e) => HistoricoEstoqueItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }

  /// Último endereço conhecido do item (para autopreencher)
  static Future<String?> ultimoEndereco(String nomeItem) async {
    final h = await historico(nomeItem);
    if (h.isEmpty) return null;
    return h.first.endereco.isEmpty ? null : h.first.endereco;
  }
}
