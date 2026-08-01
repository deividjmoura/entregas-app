import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PreferenciasService {
  static const _storage = FlutterSecureStorage();
  static const _kLinha = 'linha_destino_padrao';
  static const _kRack = 'rack_padrao';

  static Future<String?> getLinhaPadrao() => _storage.read(key: _kLinha);
  static Future<String?> getRackPadrao() => _storage.read(key: _kRack);

  static Future<void> setLinhaPadrao(String? valor) async {
    if (valor == null || valor.trim().isEmpty) {
      await _storage.delete(key: _kLinha);
    } else {
      await _storage.write(key: _kLinha, value: valor.trim().toUpperCase());
    }
  }

  static Future<void> setRackPadrao(String? valor) async {
    if (valor == null || valor.trim().isEmpty) {
      await _storage.delete(key: _kRack);
    } else {
      await _storage.write(key: _kRack, value: valor.trim().toUpperCase());
    }
  }
}
