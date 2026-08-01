import 'dart:convert';
import '../models/mensagem.dart';
import '../models/solicitacao.dart';
import 'api_client.dart';

class SolicitacaoService {
  // Lista mensagens tipadas
  static Future<List<Mensagem>> listarMensagens(String solicitacaoId) async {
    final response = await ApiClient.get('/solicitacoes/$solicitacaoId/mensagens');
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => Mensagem.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  static Future<void> enviarMensagem(String solicitacaoId, String texto) async {
    await ApiClient.post(
      '/solicitacoes/$solicitacaoId/mensagens',
      body: {'texto': texto},
    );
  }

  static Future<List<Solicitacao>> getSolicitacoes() async {
    final response = await ApiClient.get('/solicitacoes');
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => Solicitacao.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  static Future<void> assumir(String id) async {
    await ApiClient.post('/solicitacoes/$id/assumir');
  }

  static Future<void> finalizar(String id, String motivo) async {
    await ApiClient.patch(
      '/solicitacoes/$id/finalizar',
      body: {'motivo': motivo},
    );
  }
}