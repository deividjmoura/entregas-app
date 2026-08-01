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
  bool _codigoValidado = false;
  bool _mostrarCampoVisitante = false;

  @override
  void initState() {
    super.initState();
    _verificarSeCodigoJaFoiValidado();
  }

  @override
  void dispose() {
    _codigoController.dispose();
    _nomeVisitanteController.dispose();
    super.dispose();
  }

  Future<void> _verificarSeCodigoJaFoiValidado() async {
    final codigoSalvo =
        await _storage.read(key: AppConstantes.storageKeyCodigoAcesso);
    if (codigoSalvo != null && codigoSalvo.isNotEmpty) {
      setState(() => _codigoValidado = true);
    }
  }

  Future<void> _validarCodigo() async {
    final codigo = _codigoController.text.trim();
    if (codigo.isEmpty) {
      _mostrarErro('Informe o código de acesso.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final valido = await ApiClient.validarCodigoAcesso(codigo);
      if (!valido) {
        _mostrarErro('Código de acesso inválido.');
        return;
      }

      // Salva o código + token de acesso
      await _storage.write(
        key: AppConstantes.storageKeyCodigoAcesso,
        value: codigo,
      );

      setState(() => _codigoValidado = true);
    } catch (e) {
      _mostrarErro('Erro ao validar código: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginComGoogle() async {
    setState(() => _isLoading = true);

    try {
      final user = await _authService.signInWithGoogle();
      if (user == null) {
        // Usuário cancelou
        return;
      }
      _irParaFila();
    } catch (e) {
      _mostrarErro('Erro no login com Google: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _entrarComoVisitante() async {
    final nome = _nomeVisitanteController.text.trim();
    if (nome.isEmpty) {
      _mostrarErro('Informe seu nome ou apelido.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authService.loginComNome(nome);
      _irParaFila();
    } catch (e) {
      _mostrarErro('Erro: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _irParaFila() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const FilaScreen()),
    );
  }

  void _mostrarErro(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.local_shipping, size: 72, color: Colors.blue),
                  const SizedBox(height: 16),
                  Text(
                    'Entregas App',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _codigoValidado
                        ? 'Identifique-se para continuar'
                        : 'Digite o código de acesso da empresa',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
                  const SizedBox(height: 32),

                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (!_codigoValidado) ...[
                    // ========== ETAPA 1: Código de acesso ==========
                    TextField(
                      controller: _codigoController,
                      decoration: const InputDecoration(
                        labelText: 'Código de acesso',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _validarCodigo(),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _validarCodigo,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Validar Código'),
                    ),
                  ] else ...[
                    // ========== ETAPA 2: Identidade ==========
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
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _entrarComoVisitante(),
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
          ),
        ),
      ),
    );
  }
}
