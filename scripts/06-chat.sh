#!/usr/bin/env bash
set -e

echo "=== [1/3] Criando o modelo Mensagem (lib/models/mensagem.dart) ==="

cat > lib/models/mensagem.dart <<'EOF'
class Mensagem {
  final String id;
  final String solicitacaoId;
  final String texto;
  final String autorNome;
  final String autorTipo;
  final DateTime createdAt;

  Mensagem({
    required this.id,
    required this.solicitacaoId,
    required this.texto,
    required this.autorNome,
    required this.autorTipo,
    required this.createdAt,
  });

  factory Mensagem.fromJson(Map<String, dynamic> json) {
    return Mensagem(
      id: json['id'] ?? '',
      solicitacaoId: json['solicitacaoId'] ?? '',
      texto: json['texto'] ?? '',
      autorNome: json['autorNome'] ?? 'Anônimo',
      autorTipo: json['autorTipo'] ?? 'ENTREGADOR',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }
}
EOF

echo "=== [2/3] Atualizando SolicitacaoService para incluir chamadas de Chat ==="

cat > lib/services/solicitacao_service.dart <<'EOF'
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/solicitacao.dart';
import '../models/mensagem.dart';
import 'api_client.dart';
import 'auth_service.dart';

class SolicitacaoService {
  static Future<List<Solicitacao>> listar() async {
    try {
      final response = await ApiClient.get('/api/solicitacoes');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Solicitacao.fromJson(json)).toList();
      }
    } catch (e) {
      debugPrint('Erro ao listar solicitações: $e');
    }
    return [];
  }

  static Future<bool> assumir(String id) async {
    final nome = AuthService().currentUser.value?.displayName ?? 'Entregador';
    final response = await ApiClient.post('/api/solicitacoes/$id/assumir', {
      'entregadorNome': nome,
    });
    return response.statusCode == 200;
  }

  static Future<bool> confirmar(String id) async {
    final nome = AuthService().currentUser.value?.displayName ?? 'Entregador';
    final response = await ApiClient.post('/api/solicitacoes/$id/confirmar', {
      'entregadorNome': nome,
    });
    return response.statusCode == 200;
  }

  static Future<bool> atualizarStatus(String id, String novoStatus) async {
    final nome = AuthService().currentUser.value?.displayName ?? 'Entregador';
    final response = await ApiClient.patch('/api/solicitacoes/$id', {
      'status': novoStatus,
      'alteradoPor': nome,
    });
    return response.statusCode == 200;
  }

  static Future<bool> atualizarEnderecoEstoque(String id, String novoEndereco) async {
    final nome = AuthService().currentUser.value?.displayName ?? 'Entregador';
    final response = await ApiClient.patch('/api/solicitacoes/$id/endereco', {
      'enderecoEstoque': novoEndereco,
      'alteradoPor': nome,
    });
    return response.statusCode == 200;
  }

  static Future<List<Mensagem>> listarMensagens(String solicitacaoId) async {
    try {
      final response = await ApiClient.get('/api/solicitacoes/$solicitacaoId/mensagens');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Mensagem.fromJson(json)).toList();
      }
    } catch (e) {
      debugPrint('Erro ao listar mensagens: $e');
    }
    return [];
  }

  static Future<bool> enviarMensagem(String solicitacaoId, String texto) async {
    final nome = AuthService().currentUser.value?.displayName ?? 'Entregador';
    try {
      final response = await ApiClient.post('/api/solicitacoes/$solicitacaoId/mensagens', {
        'texto': texto,
        'autorNome': nome,
        'autorTipo': 'ENTREGADOR',
      });
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Erro ao enviar mensagem: $e');
      return false;
    }
  }
}
EOF

echo "=== [3/3] Criando a tela ChatScreen (lib/screens/chat_screen.dart) e integrando ao Detalhe ==="

cat > lib/screens/chat_screen.dart <<'EOF'
import 'dart:async';
import 'package:flutter/material.dart';
import '../models/mensagem.dart';
import '../models/solicitacao.dart';
import '../services/solicitacao_service.dart';
import '../services/auth_service.dart';

class ChatScreen extends StatefulWidget {
  final Solicitacao solicitacao;

  const ChatScreen({super.key, required this.solicitacao});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<Mensagem> _mensagens = [];
  bool _loading = true;
  bool _sending = false;
  final TextEditingController _controller = TextEditingController();
  Timer? _pollingTimer;

  bool get _chatAtivo {
    final s = widget.solicitacao.status;
    return s == 'EM_CURSO' || s == 'EM_ROTA' || s == 'EM_BAIXA';
  }

  @override
  void initState() {
    super.initState();
    _carregarMensagens();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) => _carregarMensagens(silent: true));
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _carregarMensagens({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    final lista = await SolicitacaoService.listarMensagens(widget.solicitacao.id);
    if (mounted) {
      setState(() {
        _mensagens = lista;
        _loading = false;
      });
    }
  }

  Future<void> _enviar() async {
    final texto = _controller.text.trim();
    if (texto.isEmpty) return;

    setState(() => _sending = true);
    final ok = await SolicitacaoService.enviarMensagem(widget.solicitacao.id, texto);
    setState(() => _sending = false);

    if (ok) {
      _controller.clear();
      _carregarMensagens(silent: true);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível enviar a mensagem (chat indisponível).')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final meuNome = AuthService().currentUser.value?.displayName ?? 'Entregador';

    return Scaffold(
      appBar: AppBar(
        title: Text('Chat #${widget.solicitacao.id.substring(0, widget.solicitacao.id.length > 6 ? 6 : widget.solicitacao.id.length)}'),
      ),
      body: Column(
        children: [
          if (!_chatAtivo)
            Container(
              color: Colors.amber.shade100,
              padding: const EdgeInsets.all(8.0),
              width: double.infinity,
              child: const Text(
                'O chat só está disponível durante o atendimento (Em Curso, Em Rota ou Em Baixa).',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.black87),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _mensagens.isEmpty
                    ? const Center(child: Text('Nenhuma mensagem enviada.'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _mensagens.length,
                        itemBuilder: (context, index) {
                          final msg = _mensagens[index];
                          final souEu = msg.autorNome.toLowerCase() == meuNome.toLowerCase();

                          return Align(
                            alignment: souEu ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: souEu ? Colors.blue.shade600 : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment:
                                    souEu ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    msg.autorNome,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: souEu ? Colors.white70 : Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    msg.texto,
                                    style: TextStyle(
                                      color: souEu ? Colors.white : Colors.black87,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    enabled: _chatAtivo && !_sending,
                    decoration: const InputDecoration(
                      hintText: 'Digite sua mensagem...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: _sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send, color: Colors.blue),
                  onPressed: _chatAtivo && !_sending ? _enviar : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
EOF

# Adiciona o botão de Chat na Tela de Detalhes
cat > lib/screens/solicitacao_detalhe_screen.dart <<'EOF'
import 'package:flutter/material.dart';
import '../models/solicitacao.dart';
import '../services/solicitacao_service.dart';
import '../services/auth_service.dart';
import '../utils/constantes.dart';
import 'chat_screen.dart';

class SolicitacaoDetalheScreen extends StatefulWidget {
  final Solicitacao solicitacao;

  const SolicitacaoDetalheScreen({super.key, required this.solicitacao});

  @override
  State<SolicitacaoDetalheScreen> createState() => _SolicitacaoDetalheScreenState();
}

class _SolicitacaoDetalheScreenState extends State<SolicitacaoDetalheScreen> {
  late Solicitacao _item;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _item = widget.solicitacao;
  }

  Future<void> _assumir() async {
    setState(() => _loading = true);
    final ok = await SolicitacaoService.assumir(_item.id);
    setState(() => _loading = false);

    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitação assumida com sucesso!')),
      );
      Navigator.pop(context, true);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao assumir solicitação.')),
      );
    }
  }

  Future<void> _alterarStatus(String novoStatus) async {
    setState(() => _loading = true);
    final ok = await SolicitacaoService.atualizarStatus(_item.id, novoStatus);
    setState(() => _loading = false);

    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status alterado para ${AppConstantes.formatarStatus(novoStatus)}')),
      );
      Navigator.pop(context, true);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao alterar status.')),
      );
    }
  }

  Future<void> _confirmar() async {
    setState(() => _loading = true);
    final ok = await SolicitacaoService.confirmar(_item.id);
    setState(() => _loading = false);

    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entrega confirmada com sucesso!')),
      );
      Navigator.pop(context, true);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao confirmar entrega.')),
      );
    }
  }

  Future<void> _editarEnderecoEstoque() async {
    final controller = TextEditingController(text: _item.enderecoEstoque ?? '');
    final novoEndereco = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Endereço de Estoque'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Localização (ex: A1-03)',
            hintText: 'Digite o endereço de estoque',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (novoEndereco != null && novoEndereco != _item.enderecoEstoque) {
      setState(() => _loading = true);
      final ok = await SolicitacaoService.atualizarEnderecoEstoque(_item.id, novoEndereco);
      setState(() => _loading = false);

      if (ok && mounted) {
        setState(() {
          _item = Solicitacao(
            id: _item.id,
            solicitanteNome: _item.solicitanteNome,
            entregadorNome: _item.entregadorNome,
            status: _item.status,
            urgencia: _item.urgencia,
            tipo: _item.tipo,
            descricao: _item.descricao,
            enderecoEstoque: novoEndereco,
            alteradoPor: AuthService().currentUser.value?.displayName ?? 'Entregador',
            fotoUrl: _item.fotoUrl,
            favorito: _item.favorito,
            createdAt: _item.createdAt,
            updatedAt: DateTime.now(),
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Endereço de estoque atualizado!')),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao atualizar endereço de estoque.')),
        );
      }
    }
  }

  void _abrirModalFoto(String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('Foto do Item'),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            InteractiveViewer(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text('Erro ao carregar a imagem.'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usuarioAtual = AuthService().currentUser.value?.displayName;
    final eMeuChamado = _item.entregadorNome != null &&
        usuarioAtual != null &&
        _item.entregadorNome!.toLowerCase() == usuarioAtual.toLowerCase();

    final labelStatus = AppConstantes.formatarStatus(_item.status);
    final labelTipo = AppConstantes.formatarTipo(_item.tipo);
    final corUrgencia = AppConstantes.corUrgencia(_item.urgencia);

    return Scaffold(
      appBar: AppBar(
        title: Text('Detalhes #${_item.id.substring(0, _item.id.length > 6 ? 6 : _item.id.length)}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat),
            tooltip: 'Abrir Chat',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(solicitacao: _item),
                ),
              );
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Chip(
                        avatar: CircleAvatar(backgroundColor: corUrgencia, radius: 6),
                        label: Text(_item.urgencia),
                      ),
                      const SizedBox(width: 8),
                      Chip(
                        label: Text(labelStatus),
                        backgroundColor: Colors.blue.shade50,
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 8),

                  Text('Solicitante: ${_item.solicitanteNome}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Entregador: ${_item.entregadorNome ?? 'Nenhum (Pendente)'}', style: const TextStyle(fontSize: 15)),
                  const SizedBox(height: 4),
                  Text('Tipo: $labelTipo', style: const TextStyle(fontSize: 15)),
                  const SizedBox(height: 12),

                  const Text('Descrição:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(_item.descricao.isEmpty ? 'Sem descrição' : _item.descricao),
                  const SizedBox(height: 16),

                  Card(
                    color: Colors.grey.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          const Icon(Icons.inventory_2, color: Colors.blueGrey),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Endereço de Estoque', style: TextStyle(fontWeight: FontWeight.bold)),
                                Text(
                                  _item.enderecoEstoque == null || _item.enderecoEstoque!.isEmpty
                                      ? 'Não informado'
                                      : _item.enderecoEstoque!,
                                  style: const TextStyle(fontSize: 15),
                                ),
                                if (_item.alteradoPor != null && _item.alteradoPor!.isNotEmpty)
                                  Text(
                                    'Alterado por: ${_item.alteradoPor}',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: _editarEnderecoEstoque,
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (_item.fotoUrl != null && _item.fotoUrl!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Card(
                      color: Colors.grey.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.image, color: Colors.blueGrey),
                                SizedBox(width: 8),
                                Text('Foto do Item', style: TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            GestureDetector(
                              onTap: () => _abrirModalFoto(_item.fotoUrl!),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  _item.fotoUrl!,
                                  height: 180,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    height: 100,
                                    color: Colors.grey.shade200,
                                    child: const Center(child: Text('Erro ao carregar a imagem.')),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  if (_item.status == 'PENDENTE')
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.handshake),
                        label: const Text('Aceitar (Assumir Entrega)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: _assumir,
                      ),
                    ),

                  if (eMeuChamado && _item.status != 'PENDENTE' && _item.status != 'ENTREGUE' && _item.status != 'CANCELADA') ...[
                    if (_item.status == 'EM_CURSO')
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.directions_bike),
                          label: const Text('Marcar em Rota'),
                          onPressed: () => _alterarStatus('EM_ROTA'),
                        ),
                      ),
                    if (_item.status == 'EM_ROTA') ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.archive),
                          label: const Text('Marcar em Baixa'),
                          onPressed: () => _alterarStatus('EM_BAIXA'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.check_circle),
                          label: const Text('Confirmar Entrega'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: _confirmar,
                        ),
                      ),
                    ],
                    if (_item.status == 'EM_BAIXA')
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.check_circle),
                          label: const Text('Confirmar Entrega'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: _confirmar,
                        ),
                      ),
                  ],
                ],
              ),
            ),
    );
  }
}
EOF

echo "✨ Script 06-chat.sh executado com sucesso!"