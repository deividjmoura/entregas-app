#!/bin/bash
# scripts/07-presenca.sh
# Parte 3.4 — Contador de presença (entregadores online)
# Opcional / baixa prioridade
set -e

echo "=============================================="
echo "  07 - Presença (entregadores online)"
echo "=============================================="
echo ""

# ============================================================
# 1. Cria o service de presença
# ============================================================
echo "→ Criando lib/services/presenca_service.dart..."

cat > lib/services/presenca_service.dart <<'EOF'
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
EOF

echo "  ✓ presenca_service.dart criado"

echo ""
echo "⚠️  Este script usa o pacote 'uuid'."
echo "   Rode: flutter pub add uuid"
echo ""

echo "=============================================="
echo "✅ 07 - Presença concluído!"
echo "=============================================="
echo ""
echo "Como usar na FilaScreen (exemplo):"
echo ""
echo "  int _online = 0;"
echo "  Timer? _presencaTimer;"
echo ""
echo "  // no initState:"
echo "  _presencaTimer = Timer.periodic(const Duration(seconds: 20), (_) async {"
echo "    final n = await PresencaService.heartbeat();"
echo "    if (mounted) setState(() => _online = n);"
echo "  });"
echo ""
echo "  // no dispose: _presencaTimer?.cancel();"
echo ""
echo "  // no AppBar:"
echo "  Text('Online: \$_online')"
echo ""
