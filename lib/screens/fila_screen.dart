import 'package:flutter/material.dart';
import '../models/solicitacao.dart';
import '../services/solicitacao_service.dart';
import '../services/pusher_service.dart';
import '../utils/constantes.dart';
import 'solicitacao_detalhe_screen.dart';

class FilaScreen extends StatefulWidget {
  const FilaScreen({super.key});

  @override
  State<FilaScreen> createState() => _FilaScreenState();
}

class _FilaScreenState extends State<FilaScreen> {
  List<Solicitacao> _itens = [];
  bool _carregando = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregarInicial();
    PusherService.conectar(onNovaEntrega: _receberNovaEntrega);
  }

  @override
  void dispose() {
    PusherService.desconectar();
    super.dispose();
  }

  Future<void> _carregarInicial() async {
    try {
      final lista = await SolicitacaoService.listar(
        status: ['PENDENTE', 'EM_ROTA', 'EM_CURSO', 'EM_BAIXA'],
      );
      if (!mounted) return;
      setState(() {
        _itens = lista;
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = 'Erro ao carregar a fila';
        _carregando = false;
      });
    }
  }

  void _receberNovaEntrega(Solicitacao nova) {
    setState(() {
      _itens = [nova, ..._itens];
    });
  }

  void _mostrarErro(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem)),
    );
  }

  Future<void> _alternarFavorito(Solicitacao item) async {
    final ok = await SolicitacaoService.alternarFavorito(item.id, !item.favorito);
    if (ok) {
      await _carregarInicial();
    } else {
      _mostrarErro('Erro ao atualizar favorito');
    }
  }

  Future<void> _alterarStatus(Solicitacao item) async {
    final novoStatus = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Alterar status'),
        children: statusDisponiveis.map((s) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, s),
            child: Row(
              children: [
                if (s == item.status) const Icon(Icons.check, size: 18),
                if (s == item.status) const SizedBox(width: 8),
                Text(s),
              ],
            ),
          );
        }).toList(),
      ),
    );

    if (novoStatus == null || novoStatus == item.status) return;

    final ok = await SolicitacaoService.atualizarStatus(item.id, novoStatus);
    if (ok) {
      await _carregarInicial();
    } else {
      _mostrarErro('Erro ao atualizar status');
    }
  }

  Future<void> _cancelar(Solicitacao item) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar solicitação'),
        content: Text('Cancelar "${item.descricaoItem}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Voltar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancelar solicitação'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    final ok = await SolicitacaoService.cancelar(item.id);
    if (ok) {
      await _carregarInicial();
    } else {
      _mostrarErro('Erro ao cancelar');
    }
  }

  Future<void> _abrirDetalhe(Solicitacao item) async {
    final alterado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SolicitacaoDetalheScreen(solicitacao: item),
      ),
    );
    if (alterado == true) {
      await _carregarInicial();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_erro != null) {
      return Scaffold(body: Center(child: Text(_erro!)));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Fila de Entregas')),
      body: RefreshIndicator(
        onRefresh: _carregarInicial,
        child: ListView.builder(
          itemCount: _itens.length,
          itemBuilder: (context, index) {
            final item = _itens[index];
            return ListTile(
              onTap: () => _abrirDetalhe(item),
              leading: CircleAvatar(
                backgroundColor: corUrgencia(item.urgencia),
                child: Text(item.urgencia[0]),
              ),
              title: Text(item.descricaoItem),
              subtitle: Text(
                '${item.localDestino} • ${item.solicitanteNome} • ${item.status}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      item.favorito ? Icons.star : Icons.star_border,
                      color: item.favorito ? Colors.amber : null,
                    ),
                    tooltip: 'Favoritar',
                    onPressed: () => _alternarFavorito(item),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'status') _alterarStatus(item);
                      if (value == 'cancelar') _cancelar(item);
                    },
                    itemBuilder: (ctx) => const [
                      PopupMenuItem(value: 'status', child: Text('Alterar status')),
                      PopupMenuItem(value: 'cancelar', child: Text('Cancelar')),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
