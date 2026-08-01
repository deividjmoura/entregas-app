import 'dart:convert';
import '../models/solicitacao.dart';
import 'api_client.dart';

enum AcaoResultado { sucesso, jaAssumido, conflitoStatus, erro }

class SolicitacaoService {
  static Future<List<Solicitacao>> listar() async {
    final res = await ApiClient.get('/api/solicitacoes');
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((json) => Solicitacao.fromJson(json)).toList();
    }
    return [];
  }

  static Future<AcaoResultado> assumir(String id, String entregadorNome) async {
    final res = await ApiClient.post('/api/solicitacoes/$id/assumir', {
      'entregadorNome': entregadorNome,
    });

    if (res.statusCode == 200) return AcaoResultado.sucesso;
    if (res.statusCode == 409) return AcaoResultado.jaAssumido;
    return AcaoResultado.erro;
  }

  static Future<bool> atualizarStatusEmRotaOuBaixa(String id, String novoStatus) async {
    if (novoStatus != 'EM_ROTA' && novoStatus != 'EM_BAIXA') {
      return false;
    }
    final res = await ApiClient.patch('/api/solicitacoes/$id', {'status': novoStatus});
    return res.statusCode == 200;
  }

  static Future<AcaoResultado> confirmar(String id) async {
    final res = await ApiClient.post('/api/solicitacoes/$id/confirmar', {});
    if (res.statusCode == 200) return AcaoResultado.sucesso;
    if (res.statusCode == 409) return AcaoResultado.conflitoStatus;
    return AcaoResultado.erro;
  }

  static Future<bool> cancelar(String id) async {
    final res = await ApiClient.delete('/api/solicitacoes/$id');
    return res.statusCode == 200;
  }

  static Future<bool> toggleFavorito(String id, bool favorito) async {
    final res = await ApiClient.patch('/api/solicitacoes/$id', {'favorito': favorito});
    return res.statusCode == 200;
  }
}
