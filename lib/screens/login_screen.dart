import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../utils/constantes.dart';
import 'fila_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _codigoController = TextEditingController();
  final _nomeVisitanteController = TextEditingController();
  final _authService = AuthService();
  final _storage = const FlutterSecureStorage();

  bool _isLoading = false;
  bool _codigoValidado = false; // controla se já passou da etapa do código
  bool _mostrarCampoVisitante = false;

  @override
  void initState() {
    super.initState();
    _verificarSeCodigoJaFoiValidado();
  }

  Future<void> _verificarSeCodigoJaFoiValidado() async {
    final codigoSalvo = await _storage.read(key: AppConstantes.storageKeyCodigoAcesso);
    if (codigoSalvo != null && codigoSalvo.isNotEmpty) {
      setState(() => _codigoValidado = true);
    }
  }

  Future<void> _validarCodigo() async {
    final codigo = _codigoController.text.trim();
    if (codigo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o código de acesso.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final valido = await ApiClient.validarCodigoAcesso(codigo);
      if (!valido) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Código de acesso inválido.')),
          );
        }
        return;
      }

      // Salva o código para não pedir de novo
      await _storage.write(key: AppConstantes.storageKeyCodigoAcesso, value: codigo);

      setState(() => _codigoValidado = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao validar código: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginComGoogle() async {
    setState(() => _isLoading = true);

    try {
      final user = await _authService.signInWithGoogle();
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Login com Google cancelado.')),
          );
        }
        return;
      }

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const FilaScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro no login com Google: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _entrarComoVisitante() async {
    final nome = _nomeVisitanteController.text.trim();
    if (nome.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe um nome para continuar como visitante.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authService.loginComNome(nome);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const FilaScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao entrar como visitante: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _codigoController.dispose();
    _nomeVisitanteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Entregas - Acesso'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.local_shipping_outlined, size: 80, color: Colors.blue),
                  const SizedBox(height: 24),

                  // ===================== ETAPA 1: CÓDIGO DE ACESSO =====================
                  if (!_codigoValidado) ...[
                    const Text(
                      'Código de Acesso',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Informe o código da empresa (só será pedido uma vez)',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _codigoController,
                      decoration: const InputDecoration(
                        labelText: 'Código de Acesso',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _validarCodigo,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Validar Código'),
                    ),
                  ]

                  // ===================== ETAPA 2: OPÇÕES DE LOGIN =====================
                  else ...[
                    const Text(
                      'Como deseja entrar?',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 32),

                    // Botão Google
                    ElevatedButton.icon(
                      icon: const Icon(Icons.login),
                      label: const Text('Entrar com Google'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _loginComGoogle,
                    ),

                    const SizedBox(height: 16),
                    const Text('ou', textAlign: TextAlign.center),
                    const SizedBox(height: 16),

                    // Visitante
                    if (!_mostrarCampoVisitante)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.person_outline),
                        label: const Text('Continuar como Visitante'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: () {
                          setState(() => _mostrarCampoVisitante = true);
                        },
                      )
                    else ...[
                      TextField(
                        controller: _nomeVisitanteController,
                        decoration: const InputDecoration(
                          labelText: 'Seu Nome / Apelido',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _entrarComoVisitante,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.grey.shade700,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Entrar como Visitante'),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() => _mostrarCampoVisitante = false);
                        },
                        child: const Text('Voltar'),
                      ),
                    ],
                  ],
                ],
              ),
      ),
    );
  }
}