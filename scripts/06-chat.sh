#!/bin/bash
# scripts/06-chat.sh
# Parte 3.3 — Chat da entrega
# Rode DEPOIS das Partes 1 e 2 (e preferencialmente depois do 05)
set -e

echo "=============================================="
echo "  06 - Chat da Entrega"
echo "=============================================="
echo ""

# ============================================================
# 1. Garante modelo de Mensagem atualizado
# ============================================================
echo "→ Atualizando modelo Mensagem..."

mkdir -p lib/models

cat > lib/models/mensagem.dart <<'EOF'
class Mensagem {
  final String id;
  final String solicitacaoId;
  final String texto;
  final String autorNome;
  final String autorTipo; // SOLICITANTE | ENTREGADOR
  final DateTime criadaEm;

  Mensagem({
    required this.id,
    required this.solicitacaoId,
    required this.texto,
    required this.autorNome,
    required this.autorTipo,
    required this.criadaEm,
  });

  factory Mensagem.fromJson(Map<String, dynamic> json) {
    return Mensagem(
      id: json['id']?.toString() ?? '',
      solicitacaoId: json['solicitacaoId']?.toString() ?? '',
      texto: json['texto']?.toString() ?? '',
      autorNome: json['autorNome']?.toString() ?? 'Anônimo',
      autorTipo: json['autorTipo']?.toString() ?? 'ENTREGADOR',
      criadaEm: DateTime.tryParse(
            (json['criadaEm'] ?? json['createdAt'])?.toString() ?? '',
          ) ??
          DateTime.now(),
    );
  }

  bool get isEntregador => autorTipo.toUpperCase() == 'ENTREGADOR';
}
EOF

echo "  ✓ mensagem.dart atualizado"

# ============================================================
# 2. Cria a tela de chat
# ============================================================
echo "→ Criando tela de chat..."

cat > lib/screens/chat_screen.dart <<'EOF'
import 'package:flutter/material.dart';
import '../models/mensagem.dart';
import '../models/solicitacao.dart';
import '../services/auth_service.dart';
import '../services/solicitacao_service.dart';

class ChatScreen extends StatefulWidget {
  final Solicitacao solicitacao;

  const ChatScreen({super.key, required this.solicitacao});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  List<Mensagem> _mensagens = [];
  bool _loading = true;
  bool _enviando = false;
  String? _meuNome;

  // Chat só é permitido nestes status
  bool get _chatDisponivel {
    final s = widget.solicitacao.status.toUpperCase();
    return s == 'EM_CURSO' || s == 'EM_ROTA' || s == 'EM_BAIXA';
  }

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _iniciar() async {
    _meuNome = await AuthService().entregadorNome;
    await _carregarMensagens();
  }

  Future<void> _carregarMensagens() async {
    setState(() => _loading = true);
    try {
      final lista =
          await SolicitacaoService.listarMensagens(widget.solicitacao.id);
      if (mounted) {
        setState(() {
          _mensagens = lista;
          _loading = false;
        });
        _scrollParaFim();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _scrollParaFim() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _enviar() async {
    final texto = _controller.text.trim();
    if (texto.isEmpty || _enviando) return;

    if (_meuNome == null || _meuNome!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Identifique-se antes de enviar')),
      );
      return;
    }

    setState(() => _enviando = true);
    _controller.clear();

    try {
      await SolicitacaoService.enviarMensagem(
        widget.solicitacao.id,
        texto,
        autorNome: _meuNome!,
      );
      await _carregarMensagens();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao enviar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Chat · ${widget.solicitacao.descricaoItem}',
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _carregarMensagens,
          ),
        ],
      ),
      body: Column(
        children: [
          // Aviso se chat não estiver disponível
          if (!_chatDisponivel)
            Container(
              width: double.infinity,
              color: Colors.orange.shade100,
              padding: const EdgeInsets.all(12),
              child: Text(
                'Chat disponível apenas enquanto a entrega está em andamento '
                '(Aceito / Em rota / Em baixa).\n'
                'Status atual: ${widget.solicitacao.status}',
                style: TextStyle(color: Colors.orange.shade900, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),

          // Lista de mensagens
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _mensagens.isEmpty
                    ? const Center(
                        child: Text(
                          'Nenhuma mensagem ainda.\nSeja o primeiro a escrever!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(12),
                        itemCount: _mensagens.length,
                        itemBuilder: (context, index) {
                          final m = _mensagens[index];
                          final isMe = m.isEntregador &&
                              m.autorNome == _meuNome;
                          return _bolha(m, isMe);
                        },
                      ),
          ),

          // Campo de envio
          if (_chatDisponivel)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: InputDecoration(
                          hintText: 'Digite uma mensagem...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _enviar(),
                        enabled: !_enviando,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _enviando ? null : _enviar,
                      icon: _enviando
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _bolha(Mensagem m, bool isMe) {
    final bg = isMe ? Colors.blue.shade600 : Colors.grey.shade200;
    final fg = isMe ? Colors.white : Colors.black87;
    final align = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final radius = isMe
        ? const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 2, left: 4, right: 4),
            child: Text(
              m.autorNome,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: bg, borderRadius: radius),
            child: Text(
              m.texto,
              style: TextStyle(color: fg, fontSize: 15),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
            child: Text(
              _formatarHora(m.criadaEm),
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
            ),
          ),
        ],
      ),
    );
  }

  String _formatarHora(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
EOF

echo "  ✓ chat_screen.dart criado"

# ============================================================
# 3. Instrução de integração
# ============================================================
echo ""
echo "=============================================="
echo "✅ 06 - Chat concluído!"
echo "=============================================="
echo ""
echo "Arquivos criados/atualizados:"
echo "  • lib/models/mensagem.dart"
echo "  • lib/screens/chat_screen.dart"
echo ""
echo "Para abrir o chat a partir da tela de detalhe, adicione um botão:"
echo ""
echo "  ElevatedButton.icon("
echo "    icon: const Icon(Icons.chat),"
echo "    label: const Text('Abrir chat'),"
echo "    onPressed: () {"
echo "      Navigator.push("
echo "        context,"
echo "        MaterialPageRoute("
echo "          builder: (_) => ChatScreen(solicitacao: item),"
echo "        ),"
echo "      );"
echo "    },"
echo "  ),"
echo ""
echo "Lembre de importar:"
echo "  import 'chat_screen.dart';"
echo ""
