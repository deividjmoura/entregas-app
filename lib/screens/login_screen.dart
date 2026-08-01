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
