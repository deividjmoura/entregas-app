#!/bin/bash
# scripts/02-acoes-solicitacao.sh
# Parte 1.2 — Ações de solicitação alinhadas ao contrato do backend
# Rode DEPOIS do 01-firebase-auth.sh
# Na raiz do projeto: ~/entregas_app
set -e

echo "=============================================="
echo "  02 - Ações corretas (/assumir, /confirmar)"
echo "=============================================="
echo ""

# ============================================================
# 1. Atualiza lib/services/solicitacao_service.dart
# ============================================================
echo "→ Atualizando lib/services/solicitacao_service.dart..."

cat > lib/services/solicitacao_service.dart <<'EOF'
import 'dart:convert';
import '../models/solicitacao.dart';
import '../models/mensagem.dart';
import 'api_client.dart';

/// Resultado detalhado de uma ação (assumir / confirmar / status)
enum AcaoResultado {
  sucesso,
  conflito,   // 409 — já assumido por outro ou status inválido
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

  /// Alias compatível com código antigo
  static Future<List<Solicitacao>> getSolicitacoes() => listar();

  // ===================== AÇÕES PRINCIPAIS =====================

  /// POST /solicitacoes/{id}/assumir
  /// Body: { "entregadorNome": "..." }
  /// Só funciona se status == PENDENTE
  /// Retorna 409 se outra pessoa já assumiu
  static Future<AcaoResultado> assumir(String id, String entregadorNome) async {
    try {
      final response = await ApiClient.post(
        '/solicitacoes/$id/assumir',
        body: {'entregadorNome': entregadorNome},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return AcaoResultado.sucesso;
      }
      if (response.statusCode == 409) {
        return AcaoResultado.conflito;
      }
      return AcaoResultado.erro;
    } catch (_) {
      return AcaoResultado.erro;
    }
  }

  /// PATCH /solicitacoes/{id}  com { "status": "EM_ROTA" | "EM_BAIXA" }
  /// Só deve ser usado nesses dois valores (igual ao cliente web oficial)
  static Future<AcaoResultado> atualizarStatus(
    String id,
    String status, // apenas EM_ROTA ou EM_BAIXA
  ) async {
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

  /// POST /solicitacoes/{id}/confirmar
  /// Só funciona se status == EM_ROTA → vira ENTREGUE
  static Future<AcaoResultado> confirmar(String id) async {
    try {
      final response = await ApiClient.post('/solicitacoes/$id/confirmar');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return AcaoResultado.sucesso;
      }
      if (response.statusCode == 409) {
        return AcaoResultado.conflito;
      }
      return AcaoResultado.erro;
    } catch (_) {
      return AcaoResultado.erro;
    }
  }

  // ===================== ENDEREÇO DE ESTOQUE =====================

  /// PATCH /solicitacoes/{id}/endereco
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

echo "  ✓ solicitacao_service.dart atualizado"

# ============================================================
# 2. Atualiza lib/screens/solicitacao_detalhe_screen.dart
# ============================================================
echo "→ Atualizando lib/screens/solicitacao_detalhe_screen.dart..."

cat > lib/screens/solicitacao_detalhe_screen.dart <<'EOF'
import 'package:flutter/material.dart';
import '../models/solicitacao.dart';
import '../services/auth_service.dart';
import '../services/solicitacao_service.dart';
import '../utils/constantes.dart';

class SolicitacaoDetalheScreen extends StatefulWidget {
  final Solicitacao solicitacao;
  final VoidCallback onUpdated;

  const SolicitacaoDetalheScreen({
    super.key,
    required this.solicitacao,
    required this.onUpdated,
  });

  @override
  State<SolicitacaoDetalheScreen> createState() =>
      _SolicitacaoDetalheScreenState();
}

class _SolicitacaoDetalheScreenState extends State<SolicitacaoDetalheScreen> {
  bool _loading = false;
  late Solicitacao _item;

  @override
  void initState() {
    super.initState();
    _item = widget.solicitacao;
  }

  Future<String?> _obterNomeEntregador() async {
    final nome = await AuthService().entregadorNome;
    if (nome != null && nome.isNotEmpty) return nome;

    final controller = TextEditingController();
    final resultado = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Identifique-se'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Seu nome / apelido',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final n = controller.text.trim();
              if (n.isNotEmpty) Navigator.pop(ctx, n);
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (resultado != null) {
      await AuthService().loginComNome(resultado);
      return resultado;
    }
    return null;
  }

  Future<void> _executarAcao(
    Future<AcaoResultado> Function() acao, {
    required String sucessoMsg,
    String conflitoMsg = 'Ação não permitida no momento',
  }) async {
    setState(() => _loading = true);
    try {
      final resultado = await acao();
      if (!mounted) return;

      switch (resultado) {
        case AcaoResultado.sucesso:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(sucessoMsg), backgroundColor: Colors.green),
          );
          widget.onUpdated();
          Navigator.pop(context);
          break;
        case AcaoResultado.conflito:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(conflitoMsg),
              backgroundColor: Colors.orange.shade800,
            ),
          );
          widget.onUpdated();
          break;
        case AcaoResultado.erro:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao executar a ação'),
              backgroundColor: Colors.red,
            ),
          );
          break;
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _assumir() async {
    final nome = await _obterNomeEntregador();
    if (nome == null) return;
    await _executarAcao(
      () => SolicitacaoService.assumir(_item.id, nome),
      sucessoMsg: 'Solicitação assumida!',
      conflitoMsg: 'Já foi assumida por outro entregador',
    );
  }

  Future<void> _marcarEmRota() async {
    await _executarAcao(
      () => SolicitacaoService.atualizarStatus(_item.id, 'EM_ROTA'),
      sucessoMsg: 'Marcado como Em rota',
    );
  }

  Future<void> _marcarEmBaixa() async {
    await _executarAcao(
      () => SolicitacaoService.atualizarStatus(_item.id, 'EM_BAIXA'),
      sucessoMsg: 'Marcado como Em baixa',
    );
  }

  Future<void> _confirmarEntrega() async {
    await _executarAcao(
      () => SolicitacaoService.confirmar(_item.id),
      sucessoMsg: 'Entrega confirmada!',
      conflitoMsg: 'Só é possível confirmar quando estiver Em rota',
    );
  }

  Future<void> _editarEndereco() async {
    final nome = await _obterNomeEntregador();
    if (nome == null) return;

    final controller = TextEditingController(
      text: _item.enderecoEstoque ?? '',
    );

    final novo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Endereço de Estoque'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_item.enderecoAlteradoPor != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Última alteração por: ${_item.enderecoAlteradoPor}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Endereço (ex: A1-03)',
                border: OutlineInputBorder(),
                hintText: 'A1-03',
              ),
              textCapitalization: TextCapitalization.characters,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx, controller.text.trim());
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (novo == null) return;

    setState(() => _loading = true);
    try {
      final resultado = await SolicitacaoService.atualizarEndereco(
        _item.id,
        enderecoEstoque: novo,
        alteradoPor: nome,
      );

      if (!mounted) return;

      if (resultado == AcaoResultado.sucesso) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Endereço atualizado'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _item = _item.copyWith(
            enderecoEstoque: novo.isEmpty ? null : novo.toUpperCase(),
            enderecoAlteradoPor: nome,
          );
        });
        widget.onUpdated();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao atualizar endereço'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _ehMeu {
    return _item.entregadorNome != null && _item.entregadorNome!.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    final status = item.status.toUpperCase();

    final podeAssumir = status == 'PENDENTE';
    final podeAgir = (status == 'EM_CURSO' ||
            status == 'EM_ROTA' ||
            status == 'EM_BAIXA') &&
        _ehMeu;
    final podeConfirmar = status == 'EM_ROTA' && _ehMeu;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Detalhe #${item.id.length > 8 ? item.id.substring(0, 8) : item.id}',
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color:
                                      AppConstantes.corUrgencia(item.urgencia),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                AppConstantes.formatarUrgencia(item.urgencia),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      AppConstantes.corUrgencia(item.urgencia),
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppConstantes.corStatus(item.status)
                                      .withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  AppConstantes.formatarStatus(item.status),
                                  style: TextStyle(
                                    color:
                                        AppConstantes.corStatus(item.status),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            item.descricaoItem,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _linhaInfo(
                              Icons.place, 'Destino', item.localDestino),
                          if (item.rackOuSlide != null &&
                              item.rackOuSlide!.isNotEmpty)
                            _linhaInfo(Icons.view_module, 'Rack/Slide',
                                item.rackOuSlide!),
                          // Endereço de estoque (clicável)
                          InkWell(
                            onTap: _editarEndereco,
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Icon(Icons.inventory_2,
                                      size: 18, color: Colors.grey.shade600),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Estoque: ',
                                    style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontSize: 14),
                                  ),
                                  Expanded(
                                    child: Text(
                                      item.enderecoEstoque?.isNotEmpty == true
                                          ? item.enderecoEstoque!
                                          : 'Não informado',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14,
                                        color: item.enderecoEstoque
                                                    ?.isNotEmpty ==
                                                true
                                            ? null
                                            : Colors.grey,
                                      ),
                                    ),
                                  ),
                                  Icon(Icons.edit,
                                      size: 16, color: Colors.blue.shade400),
                                ],
                              ),
                            ),
                          ),
                          if (item.enderecoAlteradoPor != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 26, top: 2),
                              child: Text(
                                'Alterado por ${item.enderecoAlteradoPor}',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey.shade500),
                              ),
                            ),
                          _linhaInfo(
                              Icons.person, 'Solicitante', item.solicitanteNome),
                          if (item.entregadorNome != null &&
                              item.entregadorNome!.isNotEmpty)
                            _linhaInfo(Icons.delivery_dining, 'Entregador',
                                item.entregadorNome!),
                          _linhaInfo(Icons.category, 'Tipo',
                              AppConstantes.formatarTipo(item.tipo)),
                          _linhaInfo(Icons.timer, 'Espera',
                              item.tempoEsperaFormatado),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  if (podeAssumir) ...[
                    ElevatedButton.icon(
                      icon: const Icon(Icons.handyman),
                      label: const Text('Aceitar solicitação'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _assumir,
                    ),
                  ],

                  if (podeAgir) ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.route),
                            label: const Text('Em rota'),
                            onPressed:
                                status == 'EM_ROTA' ? null : _marcarEmRota,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.inventory),
                            label: const Text('Em baixa'),
                            onPressed:
                                status == 'EM_BAIXA' ? null : _marcarEmBaixa,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (podeConfirmar)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Confirmar entrega'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _confirmarEntrega,
                      ),
                  ],

                  if (!podeAssumir &&
                      !podeAgir &&
                      item.isEmAndamento &&
                      item.entregadorNome != null)
                    Card(
                      color: Colors.orange.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(Icons.lock, color: Colors.orange.shade800),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Esta solicitação está com ${item.entregadorNome}',
                                style:
                                    TextStyle(color: Colors.orange.shade900),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _linhaInfo(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
          ),
          Expanded(
            child: Text(
              value,
              style:
                  const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
EOF

echo "  ✓ solicitacao_detalhe_screen.dart atualizado"

# Ajuste na fila_screen se necessário
if grep -q "SolicitacaoService.getSolicitacoes" lib/screens/fila_screen.dart 2>/dev/null; then
  sed -i 's/SolicitacaoService\.getSolicitacoes/SolicitacaoService.listar/g' lib/screens/fila_screen.dart
  echo "  ✓ chamada em fila_screen atualizada para .listar()"
fi

echo ""
echo "=============================================="
echo "✅ Parte 1.2 concluída com sucesso!"
echo "=============================================="
echo ""
echo "O que mudou:"
echo "  • SolicitacaoService.assumir() agora manda entregadorNome"
echo "  • Trata 409 (já assumido por outro)"
echo "  • atualizarStatus só aceita EM_ROTA / EM_BAIXA"
echo "  • confirmar() usa a rota correta"
echo "  • Tela de detalhe mostra botões contextuais (igual ao web)"
echo "  • Edição de endereço de estoque já incluída"
echo ""
echo "Próximo passo recomendado: Parte 2 (cores + polling + sessão)"
echo ""
