import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';

class AcoesSolicitacaoWidget extends StatefulWidget {
  final Map<String, dynamic> solicitacao;
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
  String? _nomeUsuarioAtual;

  @override
  void initState() {
    super.initState();
    _carregarUsuario();
  }

  Future<void> _carregarUsuario() async {
    final nome = await AuthService().getEntregadorNome();
    if (mounted) {
      setState(() {
        _nomeUsuarioAtual = nome;
      });
    }
  }

  // Agora aceita Future<void> em vez de Future<bool>
  Future<void> _executarAcao(Future<void> Function() acao) async {
    setState(() => _loading = true);

    try {
      await acao();
      widget.onAtualizado();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Falha ao executar ação: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final id = widget.solicitacao['id']?.toString() ?? '';
    final status = widget.solicitacao['status']?.toString().toUpperCase() ?? '';
    final entregadorNome = widget.solicitacao['entregadorNome']?.toString();

    if (status == 'PENDENTE') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('Aceitar (Assumir Entrega)'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onPressed: () async {
            if (_nomeUsuarioAtual == null || _nomeUsuarioAtual!.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Identidade do entregador não encontrada. Faça login novamente.'),
                ),
              );
              return;
            }

            // Se o ApiClient.assumirSolicitacao aceitar 2 parâmetros:
            await _executarAcao(
  () => ApiClient.assumirSolicitacao(id),
);

            // Se der erro de "Too many positional arguments", use a versão abaixo:
            // await _executarAcao(() => ApiClient.assumirSolicitacao(id));
          },
        ),
      );
    }

    final ehMeu = entregadorNome != null &&
        _nomeUsuarioAtual != null &&
        entregadorNome.toLowerCase() == _nomeUsuarioAtual!.toLowerCase();

    if (!ehMeu && (status == 'EM_CURSO' || status == 'EM_ROTA' || status == 'EM_BAIXA')) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Em andamento por: ${entregadorNome ?? "Outro entregador"}',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54),
        ),
      );
    }

    return Column(
      children: [
        if (status == 'EM_CURSO') ...[
          ElevatedButton(
            onPressed: () => _executarAcao(() => ApiClient.atualizarStatus(id, 'EM_ROTA')),
            child: const Text('Marcar Em Rota'),
          ),
        ],
        if (status == 'EM_ROTA') ...[
          ElevatedButton(
            onPressed: () => _executarAcao(() => ApiClient.atualizarStatus(id, 'EM_BAIXA')),
            child: const Text('Marcar Em Baixa'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            onPressed: () => _executarAcao(() => ApiClient.confirmarEntrega(id)),
            child: const Text('Confirmar Entrega (Concluir)'),
          ),
        ],
        if (status == 'EM_BAIXA') ...[
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            onPressed: () => _executarAcao(() => ApiClient.confirmarEntrega(id)),
            child: const Text('Confirmar Entrega (Concluir)'),
          ),
        ],
      ],
    );
  }
}