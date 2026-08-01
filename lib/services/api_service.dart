import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/solicitacao.dart';
import '../utils/constantes.dart';

class ApiService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _storage.read(key: AppConstantes.storageKeyToken);
    final entregadorNome = await _storage.read(key: AppConstantes.storageKeyEntregadorNome) ?? '';

    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      'X-Entregador-Nome': Uri.encodeComponent(entregadorNome),
    };
  }

  Future<List<Solicitacao>> getSolicitacoesDisponiveis() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('${AppConstantes.apiBaseUrl}/solicitacoes/disponiveis'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Solicitacao.fromJson(json)).toList();
    } else {
      throw Exception('Falha ao carregar solicitações disponíveis: ${response.body}');
    }
  }

  Future<List<Solicitacao>> getMinhasSolicitacoes() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('${AppConstantes.apiBaseUrl}/solicitacoes/minhas'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Solicitacao.fromJson(json)).toList();
    } else {
      throw Exception('Falha ao carregar minhas solicitações: ${response.body}');
    }
  }

  Future<void> assumirSolicitacao(String id) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('${AppConstantes.apiBaseUrl}/solicitacoes/$id/assumir'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Falha ao assumir solicitação: ${response.body}');
    }
  }

  Future<void> finalizarSolicitacao(String id) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('${AppConstantes.apiBaseUrl}/solicitacoes/$id/finalizar'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Falha ao finalizar solicitação: ${response.body}');
    }
  }

  Future<void> cancelarSolicitacao(String id, String motivo) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('${AppConstantes.apiBaseUrl}/solicitacoes/$id/cancelar'),
      headers: headers,
      body: jsonEncode({'motivo': motivo}),
    );

    if (response.statusCode != 200) {
      throw Exception('Falha ao cancelar solicitação: ${response.body}');
    }
  }
}
