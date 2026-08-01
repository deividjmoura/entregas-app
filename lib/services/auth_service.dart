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
