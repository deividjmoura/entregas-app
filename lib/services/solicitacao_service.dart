import 'dart:convert';
import '../models/solicitacao.dart';
import 'api_client.dart';

class SolicitacaoService {
  static Future<List<Solicitacao>> listar({List<String>? status}) async {
    final query = status != null && status.isNotEmpty
        ? '?status=${status.join(",")}'
        : '';
    final res = await ApiClient.get('/api/solicitacoes$query');

    if (res.statusCode != 200) {
      throw Exception('Erro ao carregar solicitações');
    }

    final List<dynamic> data = jsonDecode(res.body);
    return data.map((json) => Solicitacao.fromJson(json)).toList();
  }

  static Future<bool> atualizarStatus(String id, String status) async {
    final res = await ApiClient.patch('/api/solicitacoes/$id', {'status': status});
    return res.statusCode == 200;
  }

  static Future<bool> atualizarUrgencia(String id, String urgencia) async {
    final res = await ApiClient.patch('/api/solicitacoes/$id', {'urgencia': urgencia});
    return res.statusCode == 200;
  }

  static Future<bool> alternarFavorito(String id, bool favorito) async {
    final res = await ApiClient.patch('/api/solicitacoes/$id', {'favorito': favorito});
    return res.statusCode == 200;
  }

  static Future<bool> cancelar(String id) async {
    final res = await ApiClient.delete('/api/solicitacoes/$id');
    return res.statusCode == 200;
  }
}