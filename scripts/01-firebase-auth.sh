#!/bin/bash
# scripts/01-firebase-auth.sh
# Parte 1.1 — Identidade do entregador (Firebase + Google Sign-In)
# Rode na raiz do projeto Flutter: ~/entregas_app
set -e

echo "=============================================="
echo "  01 - Firebase Auth + Identidade do Entregador"
echo "=============================================="
echo ""

# 1. Verifica se o Firebase já foi configurado
if [ ! -f "lib/firebase_options.dart" ]; then
  echo "❌ ERRO: lib/firebase_options.dart não encontrado."
  echo ""
  echo "Antes de rodar este script, execute:"
  echo ""
  echo "  flutterfire configure"
  echo ""
  echo "Apontando para o mesmo projeto Firebase que o entregas-teste usa."
  echo "Depois rode este script novamente."
  exit 1
fi

echo "✅ firebase_options.dart encontrado."
echo ""

# ============================================================
# 2. Atualiza lib/main.dart
# ============================================================
echo "→ Atualizando lib/main.dart..."

cat > lib/main.dart <<'EOF'
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'widgets/auth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Entregas App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}
EOF

echo "  ✓ main.dart atualizado"

# ============================================================
# 3. Atualiza lib/services/auth_service.dart
# ============================================================
echo "→ Atualizando lib/services/auth_service.dart..."

cat > lib/services/auth_service.dart <<'EOF'
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/constantes.dart';
import 'api_client.dart';

/// Serviço de identidade do entregador.
/// Camada 2 de autenticação (a camada 1 é o código de acesso da empresa).
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // ===================== GETTERS =====================

  User? get currentUser => _firebaseAuth.currentUser;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  /// Nome do entregador (prioridade: Google displayName → email → storage visitante)
  Future<String?> get entregadorNome async {
    final user = currentUser;
    if (user != null) {
      final nome = user.displayName?.trim();
      if (nome != null && nome.isNotEmpty) return nome;
      final email = user.email?.trim();
      if (email != null && email.isNotEmpty) return email;
    }
    return await _storage.read(key: AppConstantes.storageKeyEntregadorNome);
  }

  /// Alias compatível com código antigo
  Future<String?> getEntregadorNome() => entregadorNome;

  Future<bool> get isVisitante async {
    if (currentUser != null) return false;
    final nome = await entregadorNome;
    return nome != null && nome.isNotEmpty;
  }

  Future<bool> get estaAutenticado async {
    if (currentUser != null) return true;
    final nome = await entregadorNome;
    return nome != null && nome.isNotEmpty;
  }

  // ===================== LOGIN =====================

  /// Login como visitante (só salva o nome)
  Future<void> loginComNome(String nome) async {
    final nomeLimpo = nome.trim();
    if (nomeLimpo.isEmpty) {
      throw Exception('Nome não pode ser vazio');
    }
    await _storage.write(
      key: AppConstantes.storageKeyEntregadorNome,
      value: nomeLimpo,
    );
  }

  /// Login com Google
  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // usuário cancelou

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
          await _firebaseAuth.signInWithCredential(credential);

      final user = userCredential.user;
      if (user != null) {
        // Persiste o nome também no storage para facilitar acesso offline
        final nome = user.displayName?.trim().isNotEmpty == true
            ? user.displayName!
            : (user.email ?? 'Entregador Google');
        await loginComNome(nome);
      }

      return user;
    } catch (e) {
      throw Exception('Erro no login com Google: $e');
    }
  }

  // ===================== LOGOUT =====================

  /// Logout completo: Firebase + storage de identidade
  /// Mantém o código de acesso da empresa (não força digitar de novo)
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}

    try {
      await _firebaseAuth.signOut();
    } catch (_) {}

    await _storage.delete(key: AppConstantes.storageKeyEntregadorNome);
    // Não remove o token de acesso da empresa de propósito
  }

  /// Limpa tudo (código da empresa + identidade) — use com cuidado
  Future<void> limparTudo() async {
    await signOut();
    await ApiClient.removeToken();
    await _storage.delete(key: AppConstantes.storageKeyCodigoAcesso);
  }
}
EOF

echo "  ✓ auth_service.dart atualizado"

# ============================================================
# 4. Atualiza lib/screens/login_screen.dart
# ============================================================
echo "→ Atualizando lib/screens/login_screen.dart..."

cat > lib/screens/login_screen.dart <<'EOF'
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
EOF

echo "  ✓ login_screen.dart atualizado"

# ============================================================
# 5. Garante que o AuthGate existe e está alinhado
# ============================================================
echo "→ Atualizando lib/widgets/auth_gate.dart..."

mkdir -p lib/widgets

cat > lib/widgets/auth_gate.dart <<'EOF'
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/auth_service.dart';
import '../utils/constantes.dart';
import '../screens/login_screen.dart';
import '../screens/fila_screen.dart';

/// Decide a tela inicial:
/// - Tem código de acesso + identidade (Google ou visitante) → FilaScreen
/// - Caso contrário → LoginScreen
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isLoading = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    const storage = FlutterSecureStorage();
    final authService = AuthService();

    final codigo =
        await storage.read(key: AppConstantes.storageKeyCodigoAcesso);
    final nome = await authService.entregadorNome;
    final user = authService.currentUser;

    final temCodigo = codigo != null && codigo.isNotEmpty;
    final temIdentificacao =
        (nome != null && nome.isNotEmpty) || user != null;

    if (mounted) {
      setState(() {
        _isAuthenticated = temCodigo && temIdentificacao;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_isAuthenticated) {
      return const FilaScreen();
    }

    return const LoginScreen();
  }
}
EOF

echo "  ✓ auth_gate.dart atualizado"

echo ""
echo "=============================================="
echo "✅ Parte 1.1 concluída com sucesso!"
echo "=============================================="
echo ""
echo "Próximos passos:"
echo "  1. Rode: flutter pub get"
echo "  2. Teste o fluxo de login (código → Google ou Visitante)"
echo "  3. Depois rode o script da Parte 1.2 (ações /assumir e /confirmar)"
echo ""
