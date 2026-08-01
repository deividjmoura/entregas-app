import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TemaService {
  static const _storage = FlutterSecureStorage();
  static const _key = 'theme_mode'; // system | light | dark

  static Future<ThemeMode> carregar() async {
    final v = await _storage.read(key: _key);
    switch (v) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static Future<void> salvar(ThemeMode mode) async {
    final v = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await _storage.write(key: _key, value: v);
  }
}
