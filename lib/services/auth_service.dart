import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/constantes.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // ===================== GETTERS =====================

  User? get currentUser => _firebaseAuth.currentUser;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  /// Retorna true se o usuário atual é visitante (não logou com Google)
  Future<bool> get isVisitante async {
    final user = currentUser;
    if (user != null) return false; // Tem conta Google

    final nome = await getEntregadorNome();
    return nome != null && nome.isNotEmpty;
  }

  /// Nome do entregador (Google ou Visitante)
  Future<String?> getEntregadorNome() async {
    // Prioriza o nome do Google se estiver logado
    final user = currentUser;
    if (user != null && (user.displayName?.isNotEmpty ?? false)) {
      return user.displayName;
    }

    // Caso contrário, pega o nome salvo no storage (visitante)
    return await _storage.read(key: AppConstantes.storageKeyEntregadorNome);
  }

  // ===================== LOGIN =====================

  /// Login como visitante (só salva o nome)
  Future<void> loginComNome(String nome) async {
    await _storage.write(
      key: AppConstantes.storageKeyEntregadorNome,
      value: nome.trim(),
    );
    await _storage.write(
      key: AppConstantes.storageKeyToken,
      value: 'visitante_${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  /// Login com Google
  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // Usuário cancelou

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await _firebaseAuth.signInWithCredential(credential);

      final user = userCredential.user;
      if (user != null) {
        // Salva o nome também no storage para facilitar
        await loginComNome(user.displayName ?? 'Entregador Google');
      }

      return user;
    } catch (e) {
      throw Exception('Erro no login com Google: $e');
    }
  }

  // ===================== LOGOUT / LIMPEZA =====================

  /// Faz logout completo (Google + storage)
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}

    try {
      await _firebaseAuth.signOut();
    } catch (_) {}

    // Limpa dados do storage (mas mantém o código da empresa)
    await _storage.delete(key: AppConstantes.storageKeyToken);
    await _storage.delete(key: AppConstantes.storageKeyEntregadorNome);
  }

  /// Limpa tudo (inclusive o código da empresa) - use com cuidado
  Future<void> limparTudo() async {
    await signOut();
    await _storage.delete(key: AppConstantes.storageKeyCodigoAcesso);
  }

  /// Verifica se o usuário está autenticado (Google ou Visitante)
  Future<bool> estaAutenticado() async {
    final user = currentUser;
    if (user != null) return true;

    final nome = await getEntregadorNome();
    return nome != null && nome.isNotEmpty;
  }
}