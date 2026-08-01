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
    _pollingTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _carregarMensagens(silent: true),
    );
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _carregarMensagens({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);

    try {
      final lista = await SolicitacaoService.listarMensagens(widget.solicitacao.id);
      if (mounted) {
        setState(() {
          _mensagens = lista;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _enviar() async {
    final texto = _controller.text.trim();
    if (texto.isEmpty) return;

    setState(() => _sending = true);

    try {
      await SolicitacaoService.enviarMensagem(widget.solicitacao.id, texto);
      _controller.clear();
      await _carregarMensagens(silent: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível enviar a mensagem (chat indisponível).'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final meuNome = AuthService().currentUser?.displayName ?? 'Entregador';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Chat #${widget.solicitacao.id.substring(0, widget.solicitacao.id.length > 6 ? 6 : widget.solicitacao.id.length)}',
        ),
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
                    onSubmitted: (_) => _enviar(),
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