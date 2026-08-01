import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/auth_service.dart';
import '../utils/constantes.dart';
import '../screens/login_screen.dart';
import '../screens/fila_screen.dart';

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

    // Verifica se o código de acesso da empresa já foi validado
    final codigo = await storage.read(key: AppConstantes.storageKeyCodigoAcesso);

    // Verifica se o usuário já está identificado (Google ou Visitante)
    final nome = await authService.getEntregadorNome();
    final user = authService.currentUser;

    final temCodigo = codigo != null && codigo.isNotEmpty;
    final temIdentificacao = (nome != null && nome.isNotEmpty) || user != null;

    setState(() {
      // Só considera autenticado se tiver o código da empresa E uma identificação
      _isAuthenticated = temCodigo && temIdentificacao;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_isAuthenticated) {
      return const FilaScreen();
    }

    return const LoginScreen();
  }
}