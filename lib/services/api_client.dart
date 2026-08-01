import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiClient {
  static const _storage = FlutterSecureStorage();
  static const String _tokenKey = 'auth_token';
  static const String baseUrl = 'https://seu-backend.com/api';

  static Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  static Future<void> setToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  static Future<void> removeToken() async {
    await _storage.delete(key: _tokenKey);
  }

  static Future<http.Response> get(String endpoint) async {
    final token = await getToken();
    return await http.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
    );
  }

  static Future<http.Response> post(String endpoint, {Map<String, dynamic>? body}) async {
    final token = await getToken();
    return await http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: body != null ? jsonEncode(body) : null,
    );
  }

  static Future<http.Response> patch(String endpoint, {Map<String, dynamic>? body}) async {
    final token = await getToken();
    return await http.patch(
      Uri.parse('$baseUrl$endpoint'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: body != null ? jsonEncode(body) : null,
    );
  }

  // Métodos estáticos solicitados pelas telas de detalhes e ações
  static Future<void> assumirSolicitacao(String id) async {
    await post('/solicitacoes/$id/assumir');
  }

  static Future<void> atualizarStatus(String id, String status) async {
    await patch('/solicitacoes/$id/status', body: {'status': status});
  }

  static Future<void> confirmarEntrega(String id) async {
    await post('/solicitacoes/$id/confirmar');
  }

  static Future<bool> validarCodigoAcesso(String codigo) async {
    return codigo.isNotEmpty;
  }
}
