#!/bin/bash
# scripts/05-foto.sh
# Parte 3.2 — Visualizar foto do item
# Rode DEPOIS das Partes 1 e 2
set -e

echo "=============================================="
echo "  05 - Visualizar Foto do Item"
echo "=============================================="
echo ""

# ============================================================
# 1. Adiciona método no SolicitacaoService
# ============================================================
echo "→ Adicionando método buscarFoto no service..."

# Reescreve o service completo incluindo o método de foto
# (mantém tudo que já existia das partes anteriores)
cat > lib/services/solicitacao_service.dart <<'EOF'
import 'dart:convert';
import '../models/solicitacao.dart';
import '../models/mensagem.dart';
import 'api_client.dart';

/// Resultado detalhado de uma ação
enum AcaoResultado {
  sucesso,
  conflito,
  erro,
}

class SolicitacaoService {
  // ===================== LISTAGEM =====================

  static Future<List<Solicitacao>> listar() async {
    final response = await ApiClient.get('/solicitacoes');
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data
          .map((e) => Solicitacao.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Falha ao listar solicitações (${response.statusCode})');
  }

  static Future<List<Solicitacao>> getSolicitacoes() => listar();

  // ===================== AÇÕES PRINCIPAIS =====================

  static Future<AcaoResultado> assumir(String id, String entregadorNome) async {
    try {
      final response = await ApiClient.post(
        '/solicitacoes/$id/assumir',
        body: {'entregadorNome': entregadorNome},
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return AcaoResultado.sucesso;
      }
      if (response.statusCode == 409) return AcaoResultado.conflito;
      return AcaoResultado.erro;
    } catch (_) {
      return AcaoResultado.erro;
    }
  }

  static Future<AcaoResultado> atualizarStatus(String id, String status) async {
    if (status != 'EM_ROTA' && status != 'EM_BAIXA') {
      throw ArgumentError('Status permitido apenas: EM_ROTA ou EM_BAIXA');
    }
    try {
      final response = await ApiClient.patch(
        '/solicitacoes/$id',
        body: {'status': status},
      );
      if (response.statusCode == 200) return AcaoResultado.sucesso;
      if (response.statusCode == 409) return AcaoResultado.conflito;
      return AcaoResultado.erro;
    } catch (_) {
      return AcaoResultado.erro;
    }
  }

  static Future<AcaoResultado> confirmar(String id) async {
    try {
      final response = await ApiClient.post('/solicitacoes/$id/confirmar');
      if (response.statusCode == 200 || response.statusCode == 201) {
        return AcaoResultado.sucesso;
      }
      if (response.statusCode == 409) return AcaoResultado.conflito;
      return AcaoResultado.erro;
    } catch (_) {
      return AcaoResultado.erro;
    }
  }

  // ===================== ENDEREÇO DE ESTOQUE =====================

  static Future<AcaoResultado> atualizarEndereco(
    String id, {
    required String enderecoEstoque,
    required String alteradoPor,
  }) async {
    try {
      final response = await ApiClient.patch(
        '/solicitacoes/$id/endereco',
        body: {
          'enderecoEstoque': enderecoEstoque.trim().toUpperCase(),
          'alteradoPor': alteradoPor.trim(),
        },
      );
      if (response.statusCode == 200) return AcaoResultado.sucesso;
      if (response.statusCode == 400 || response.statusCode == 409) {
        return AcaoResultado.conflito;
      }
      return AcaoResultado.erro;
    } catch (_) {
      return AcaoResultado.erro;
    }
  }

  // ===================== FOTO =====================

  /// GET /solicitacoes/{id}/foto
  /// Retorna o base64 (data:image/...;base64,...) ou null se não tiver
  static Future<String?> buscarFoto(String id) async {
    try {
      final response = await ApiClient.get('/solicitacoes/$id/foto');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['foto'] as String?;
      }
      return null; // 404 ou outro
    } catch (_) {
      return null;
    }
  }

  // ===================== MENSAGENS =====================

  static Future<List<Mensagem>> listarMensagens(String solicitacaoId) async {
    final response =
        await ApiClient.get('/solicitacoes/$solicitacaoId/mensagens');
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data
          .map((e) => Mensagem.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  static Future<void> enviarMensagem(
    String solicitacaoId,
    String texto, {
    required String autorNome,
  }) async {
    await ApiClient.post(
      '/solicitacoes/$solicitacaoId/mensagens',
      body: {
        'autorNome': autorNome,
        'autorTipo': 'ENTREGADOR',
        'texto': texto,
      },
    );
  }
}
EOF

echo "  ✓ solicitacao_service.dart atualizado com buscarFoto()"

# ============================================================
# 2. Cria um widget simples de visualização de foto
# ============================================================
echo "→ Criando widget de foto..."

mkdir -p lib/widgets

cat > lib/widgets/foto_item.dart <<'EOF'
import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/solicitacao_service.dart';

/// Mostra a foto de uma solicitação (busca sob demanda).
/// Só deve ser usado quando temFoto == true.
class FotoItem extends StatefulWidget {
  final String solicitacaoId;

  const FotoItem({super.key, required this.solicitacaoId});

  @override
  State<FotoItem> createState() => _FotoItemState();
}

class _FotoItemState extends State<FotoItem> {
  String? _base64;
  bool _loading = true;
  bool _erro = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final foto = await SolicitacaoService.buscarFoto(widget.solicitacaoId);
    if (!mounted) return;
    setState(() {
      _base64 = foto;
      _loading = false;
      _erro = foto == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 180,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_erro || _base64 == null) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image, size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text('Foto não disponível',
                style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      );
    }

    // Remove o prefixo data:image/...;base64, se existir
    String data = _base64!;
    if (data.contains(',')) {
      data = data.split(',').last;
    }

    try {
      final bytes = base64Decode(data);
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(
          bytes,
          fit: BoxFit.cover,
          width: double.infinity,
          height: 220,
          errorBuilder: (_, __, ___) => Container(
            height: 120,
            alignment: Alignment.center,
            child: const Text('Erro ao decodificar imagem'),
          ),
        ),
      );
    } catch (_) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        child: const Text('Erro ao processar foto'),
      );
    }
  }
}
EOF

echo "  ✓ widget foto_item.dart criado"

# ============================================================
# 3. Instrução para integrar na tela de detalhe
# ============================================================
echo ""
echo "=============================================="
echo "✅ 05 - Foto concluído!"
echo "=============================================="
echo ""
echo "Arquivos criados/atualizados:"
echo "  • lib/services/solicitacao_service.dart  (método buscarFoto)"
echo "  • lib/widgets/foto_item.dart             (widget de visualização)"
echo ""
echo "Para mostrar a foto na tela de detalhe, adicione:"
echo ""
echo "  import '../widgets/foto_item.dart';"
echo ""
echo "  // Dentro do build, depois da descrição do item:"
echo "  if (item.temFoto) ..."
echo "    const SizedBox(height: 16),"
echo "    FotoItem(solicitacaoId: item.id),"
echo ""
echo "Ou rode o próximo script (06-chat) que já integra tudo."
echo ""
