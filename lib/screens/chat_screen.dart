import 'dart:async';
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
  final _scroll = ScrollController();
  List<Mensagem> _mensagens = [];
  bool _loading = true;
  bool _enviando = false;
  String? _meuNome;
  Timer? _poll;

  bool get _disponivel {
    final s = widget.solicitacao.status.toUpperCase();
    return s == 'EM_CURSO' || s == 'EM_ROTA' || s == 'EM_BAIXA';
  }

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    _meuNome = await AuthService().entregadorNome;
    await _carregar(silent: false);
    if (_meuNome != null) {
      try {
        await SolicitacaoService.marcarMensagensLidas(
          widget.solicitacao.id,
          _meuNome!,
        );
      } catch (_) {}
    }
    _poll = Timer.periodic(const Duration(seconds: 4), (_) => _carregar(silent: true));
  }

  Future<void> _carregar({required bool silent}) async {
    try {
      final lista =
          await SolicitacaoService.listarMensagens(widget.solicitacao.id);
      if (!mounted) return;
      final mudou = lista.length != _mensagens.length;
      setState(() {
        _mensagens = lista;
        _loading = false;
      });
      if (mudou) _scrollFim();
    } catch (_) {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  void _scrollFim() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
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
      await _carregar(silent: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao enviar: $e')),
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
        title: Text('Chat · ${widget.solicitacao.descricaoItem}'),
      ),
      body: Column(
        children: [
          if (!_disponivel)
            Container(
              width: double.infinity,
              color: Colors.orange.shade100,
              padding: const EdgeInsets.all(8),
              child: const Text(
                'Chat disponível apenas enquanto a entrega está em andamento.',
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(12),
                    itemCount: _mensagens.length,
                    itemBuilder: (_, i) {
                      final m = _mensagens[i];
                      final eu = m.autorNome == _meuNome;
                      return Align(
                        alignment:
                            eu ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          decoration: BoxDecoration(
                            color: eu
                                ? Colors.blue.shade600
                                : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!eu)
                                Text(
                                  m.autorNome,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              Text(
                                m.texto,
                                style: TextStyle(
                                  color: eu ? Colors.white : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (_disponivel)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: const InputDecoration(
                          hintText: 'Mensagem...',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onSubmitted: (_) => _enviar(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _enviando ? null : _enviar,
                      icon: _enviando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
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
}
