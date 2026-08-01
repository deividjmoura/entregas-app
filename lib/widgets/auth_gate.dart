import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/auth_service.dart';
import '../utils/constantes.dart';
import '../screens/login_screen.dart';
import '../screens/fila_screen.dart';

/// Decide a tela inicial:
/// - Tem código de acesso + identidade → FilaScreen
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
