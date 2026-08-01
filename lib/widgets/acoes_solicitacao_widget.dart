import 'package:flutter/material.dart';
import '../models/solicitacao.dart';
import '../services/auth_service.dart';
import '../services/solicitacao_service.dart';
import '../utils/constantes.dart';

class AcoesSolicitacaoWidget extends StatefulWidget {
  final Solicitacao solicitacao;
  final VoidCallback onAtualizado;

  const AcoesSolicitacaoWidget({
    super.key,
    required this.solicitacao,
    required this.onAtualizado,
  });

  @override
  State<AcoesSolicitacaoWidget> createState() => _AcoesSolicitacaoWidgetState();
}

class _AcoesSolicitacaoWidgetState extends State<AcoesSolicitacaoWidget> {
  bool _loading = false;
  String? _nome;

  @override
  void initState() {
    super.initState();
    AuthService().entregadorNome.then((n) {
      if (mounted) setState(() => _nome = n);
    });
  }

  Future<void> _run(Future<AcaoResultado> Function() acao, {String okMsg = 'OK'}) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final r = await acao();
      if (!mounted) return;
      if (r == AcaoResultado.sucesso) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(okMsg), backgroundColor: Colors.green),
        );
        widget.onAtualizado();
      } else if (r == AcaoResultado.conflito) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Outro entregador já assumiu esta solicitação'),
            backgroundColor: Colors.orange,
          ),
        );
        widget.onAtualizado();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Falha na ação'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.solicitacao;
    final status = s.status.toUpperCase();

    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final botoes = <Widget>[];

    if (status == AppConstantes.statusPendente) {
      botoes.add(
        ElevatedButton.icon(
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('Assumir entrega'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
          ),
          onPressed: () {
            if (_nome == null || _nome!.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Faça login novamente')),
              );
              return;
            }
            _run(() => SolicitacaoService.assumir(s.id, _nome!), okMsg: 'Assumida!');
          },
        ),
      );
    }

    if (status == AppConstantes.statusEmCurso) {
      botoes.add(
        ElevatedButton.icon(
          icon: const Icon(Icons.local_shipping),
          label: const Text('Em rota'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
          ),
          onPressed: () => _run(
            () => SolicitacaoService.atualizarStatus(s.id, AppConstantes.statusEmRota),
            okMsg: 'Status: Em rota',
          ),
        ),
      );
    }

    if (status == AppConstantes.statusEmRota) {
      botoes.add(
        ElevatedButton.icon(
          icon: const Icon(Icons.inventory_2),
          label: const Text('Em baixa'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
          ),
          onPressed: () => _run(
            () => SolicitacaoService.atualizarStatus(s.id, AppConstantes.statusEmBaixa),
            okMsg: 'Status: Em baixa',
          ),
        ),
      );
    }

    if (status == AppConstantes.statusEmBaixa || status == AppConstantes.statusEmRota) {
      botoes.add(
        ElevatedButton.icon(
          icon: const Icon(Icons.done_all),
          label: const Text('Confirmar entrega'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
          ),
          onPressed: () => _run(
            () => SolicitacaoService.confirmar(s.id),
            okMsg: 'Entrega confirmada!',
          ),
        ),
      );
    }

    if (botoes.isEmpty) {
      return Text(
        'Sem ações para status ${AppConstantes.formatarStatus(status)}',
        style: TextStyle(color: Colors.grey.shade600),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < botoes.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          botoes[i],
        ],
      ],
    );
  }
}
