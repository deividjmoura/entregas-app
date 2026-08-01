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
