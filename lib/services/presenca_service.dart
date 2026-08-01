import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import 'api_client.dart';

/// Heartbeat de presença.
/// O backend considera "online" quem mandou heartbeat nos últimos 30s.
class PresencaService {
  static const _storage = FlutterSecureStorage();
  static const _sessionKey = 'presenca_session_id';
  static const _uuid = Uuid();

  /// Retorna (ou cria) um sessionId estável por instalação do app
  static Future<String> _getSessionId() async {
    var id = await _storage.read(key: _sessionKey);
    if (id == null || id.isEmpty) {
      id = _uuid.v4();
      await _storage.write(key: _sessionKey, value: id);
    }
    return id;
  }

  /// Envia heartbeat e retorna quantos estão online
  static Future<int> heartbeat() async {
    try {
      final sessionId = await _getSessionId();
      final response = await ApiClient.post(
        '/presenca',
        body: {'sessionId': sessionId},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return (data['online'] as num?)?.toInt() ?? 0;
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }

  /// Só consulta quantos estão online (sem enviar heartbeat)
  static Future<int> consultar() async {
    try {
      final response = await ApiClient.get('/presenca');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return (data['online'] as num?)?.toInt() ?? 0;
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }
}
