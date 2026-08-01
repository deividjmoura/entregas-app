#!/usr/bin/env bash
set -e

echo "=== [1/2] Verificando pré-requisitos do Firebase ==="

if [ ! -f "lib/firebase_options.dart" ]; then
  echo "❌ ERRO: lib/firebase_options.dart não encontrado!"
  echo "Por favor, execute 'flutterfire configure' na raiz do projeto antes de rodar este script."
  exit 1
fi

echo "✅ firebase_options.dart encontrado."

echo "=== [2/2] Atualizando arquivos de Auth e Login ==="

# 1. AuthService
cat > lib/services/auth_service.dart <<'EOF'
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'api_client.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  ValueNotifier<User?> currentUser = ValueNotifier<User?>(null);

  void init() {
    currentUser.value = _auth.currentUser;
    _auth.userChanges().listen((user) {
      currentUser.value = user;
    });
  }

  String get entregadorNome {
    final user = _auth.currentUser;
    if (user == null) return '';
    return user.displayName ?? user.email ?? 'Entregador';
  }

  Future<UserCredential?> signInWithGoogle() async {
    GoogleAuthProvider googleProvider = GoogleAuthProvider();
    googleProvider.addScope('email');
    googleProvider.addScope('profile');
    return await _auth.signInWithPopup(googleProvider);
  }

  Future<void> logout() async {
    await _auth.signOut();
    await ApiClient.logout();
  }
}
EOF

# 2. Main.dart
cat > lib/main.dart <<'EOF'
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  AuthService().init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Entregas App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}
EOF

# 3. LoginScreen
cat > lib/screens/login_screen.dart <<'EOF'
import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import 'fila_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _codigoController = TextEditingController();
  bool _codigoValidado = false;
  bool _loading = false;
  String _erro = '';

  Future<void> _validarCodigo() async {
    setState(() {
      _loading = true;
      _erro = '';
    });

    final sucesso = await ApiClient.login(_codigoController.text.trim());

    setState(() {
      _loading = false;
    });

    if (sucesso) {
      setState(() {
        _codigoValidado = true;
      });
    } else {
      setState(() {
        _erro = 'Código de acesso inválido.';
      });
    }
  }

  Future<void> _loginGoogle() async {
    setState(() {
      _loading = true;
      _erro = '';
    });

    try {
      final cred = await AuthService().signInWithGoogle();
      if (cred != null && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const FilaScreen()),
        );
      }
    } catch (e) {
      setState(() {
        _erro = 'Falha no login Google: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.local_shipping, size: 80, color: Colors.blue),
                const SizedBox(height: 24),
                const Text(
                  'Entregas App',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 32),
                if (_erro.isNotEmpty) ...[
                  Text(_erro, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 16),
                ],
                if (!_codigoValidado) ...[
                  TextField(
                    controller: _codigoController,
                    decoration: const InputDecoration(
                      labelText: 'Código de Acesso',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loading ? null : _validarCodigo,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                    child: _loading
                        ? const CircularProgressIndicator()
                        : const Text('Validar Código'),
                  ),
                ] else ...[
                  const Text(
                    'Código validado! Agora faça login com sua conta Google.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _loading ? null : _loginGoogle,
                    icon: const Icon(Icons.login),
                    label: const Text('Entrar com Google'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
EOF

echo "✨ Tarefa 1.1 concluída com sucesso!"