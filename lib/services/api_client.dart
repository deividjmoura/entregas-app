import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiClient {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'access_token';

  // Troque pela URL real do seu deploy
  static const baseUrl = 'https://entregas-teste.vercel.app';

  static const _timeout = Duration(seconds: 10);

  static Future<bool> login(String codigo) async {
    debugPrint('ApiClient.login: enviando POST para $baseUrl/api/acesso');
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/api/acesso'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'codigo': codigo}),
          )
          .timeout(_timeout);

      debugPrint('ApiClient.login: status=${res.statusCode} body=${res.body}');

      if (res.statusCode != 200) return false;

      final data = jsonDecode(res.body);
      final token = data['token'] as String?;
      if (token == null) {
        debugPrint('ApiClient.login: resposta 200 mas sem campo "token" no body');
        return false;
      }

      await _storage.write(key: _tokenKey, value: token);
      debugPrint('ApiClient.login: token salvo com sucesso');
      return true;
    } catch (e, st) {
      debugPrint('ApiClient.login: EXCEÇÃO -> $e');
      debugPrint('$st');
      rethrow;
    }
  }

  static Future<String?> getToken() => _storage.read(key: _tokenKey);

  static Future<void> logout() => _storage.delete(key: _tokenKey);

  static Future<http.Response> get(String path) async {
    final token = await getToken();
    debugPrint('ApiClient.get: $baseUrl$path (token presente: ${token != null})');
    final res = await http
        .get(
          Uri.parse('$baseUrl$path'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(_timeout);
    debugPrint('ApiClient.get: status=${res.statusCode}');
    return res;
  }

  static Future<http.Response> post(String path, Map<String, dynamic> body) async {
    final token = await getToken();
    return http
        .post(
          Uri.parse('$baseUrl$path'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(_timeout);
  }

  static Future<http.Response> patch(String path, Map<String, dynamic> body) async {
    final token = await getToken();
    return http
        .patch(
          Uri.parse('$baseUrl$path'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(_timeout);
  }

  static Future<http.Response> delete(String path) async {
    final token = await getToken();
    return http
        .delete(
          Uri.parse('$baseUrl$path'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(_timeout);
  }
}
