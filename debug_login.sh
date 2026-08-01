#!/bin/bash
# Roda dentro de ~/entregas_app
set -e

echo "Atualizando lib/services/api_client.dart..."
cat > lib/services/api_client.dart <<'EOF'
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
EOF

echo "Atualizando lib/screens/login_screen.dart..."
cat > lib/screens/login_screen.dart <<'EOF'
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/api_client.dart';
import 'fila_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _codigoController = TextEditingController();
  bool _carregando = false;
  String? _erro;

  Future<void> _entrar() async {
    final codigo = _codigoController.text.trim();
    if (codigo.isEmpty) {
      setState(() => _erro = 'Digite o código de acesso');
      return;
    }

    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      final sucesso = await ApiClient.login(codigo);
      debugPrint('LoginScreen: login retornou sucesso=$sucesso');
      if (!mounted) return;

      if (sucesso) {
        debugPrint('LoginScreen: navegando para FilaScreen');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const FilaScreen()),
        );
      } else {
        setState(() => _erro = 'Código inválido');
      }
    } catch (e) {
      debugPrint('LoginScreen: EXCEÇÃO no _entrar -> $e');
      if (mounted) {
        setState(() => _erro = 'Erro de conexão. Verifique sua internet.');
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF990011),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Central de Despacho',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _codigoController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Código de acesso',
                  labelStyle: const TextStyle(color: Colors.white70),
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white54),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                ),
                onSubmitted: (_) => _entrar(),
              ),
              if (_erro != null) ...[
                const SizedBox(height: 12),
                Text(_erro!, style: const TextStyle(color: Colors.yellowAccent)),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _carregando ? null : _entrar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF990011),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _carregando
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Entrar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
EOF

echo ""
echo "Feito. Rode 'flutter run -d chrome' de novo, tente logar, e me manda"
echo "o que aparecer no Console do DevTools (ou no terminal onde rodou flutter run)."
