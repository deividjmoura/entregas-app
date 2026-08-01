import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/solicitacao.dart';
import '../models/mensagem.dart';
import 'api_client.dart';
import 'auth_service.dart';

class SolicitacaoService {
  static Future<List<Solicitacao>> listar() async {
    try {
      final response = await ApiClient.get('/api/solicitacoes');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Solicitacao.fromJson(json)).toList();
      }
    } catch (e) {
      debugPrint('Erro ao listar solicitações: $e');
    }
    return [];
  }

  static Future<bool> assumir(String id) async {
    final nome = AuthService().currentUser.value?.displayName ?? 'Entregador';
    final response = await ApiClient.post('/api/solicitacoes/$id/assumir', {
      'entregadorNome': nome,
    });
    return response.statusCode == 200;
  }

  static Future<bool> confirmar(String id) async {
    final nome = AuthService().currentUser.value?.displayName ?? 'Entregador';
    final response = await ApiClient.post('/api/solicitacoes/$id/confirmar', {
      'entregadorNome': nome,
    });
    return response.statusCode == 200;
  }

  static Future<bool> atualizarStatus(String id, String novoStatus) async {
    final nome = AuthService().currentUser.value?.displayName ?? 'Entregador';
    final response = await ApiClient.patch('/api/solicitacoes/$id', {
      'status': novoStatus,
      'alteradoPor': nome,
    });
    return response.statusCode == 200;
  }

  static Future<bool> atualizarEnderecoEstoque(String id, String novoEndereco) async {
    final nome = AuthService().currentUser.value?.displayName ?? 'Entregador';
    final response = await ApiClient.patch('/api/solicitacoes/$id/endereco', {
      'enderecoEstoque': novoEndereco,
      'alteradoPor': nome,
    });
    return response.statusCode == 200;
  }

  static Future<List<Mensagem>> listarMensagens(String solicitacaoId) async {
    try {
      final response = await ApiClient.get('/api/solicitacoes/$solicitacaoId/mensagens');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Mensagem.fromJson(json)).toList();
      }
    } catch (e) {
      debugPrint('Erro ao listar mensagens: $e');
    }
    return [];
  }

  static Future<bool> enviarMensagem(String solicitacaoId, String texto) async {
    final nome = AuthService().currentUser.value?.displayName ?? 'Entregador';
    try {
      final response = await ApiClient.post('/api/solicitacoes/$solicitacaoId/mensagens', {
        'texto': texto,
        'autorNome': nome,
        'autorTipo': 'ENTREGADOR',
      });
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Erro ao enviar mensagem: $e');
      return false;
    }
  }
}
