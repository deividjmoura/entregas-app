import 'package:flutter/material.dart';
import '../models/solicitacao.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
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
  State<SolicitacaoDetalheScreen> createState() => _SolicitacaoDetalheScreenState();
}

class _SolicitacaoDetalheScreenState extends State<SolicitacaoDetalheScreen> {
  bool _loading = false;

  void _solicitarIdentificacaoSeNecessario(VoidCallback onIdentificado) {
    final user = AuthService().currentUser;

    // Se já tem usuário logado com Google, segue direto
    if (user != null && (user.displayName?.isNotEmpty ?? false)) {
      onIdentificado();
      return;
    }

    final nomeController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Identifique-se para esta ação'),
        content: TextField(
          controller: nomeController,
          decoration: const InputDecoration(
            labelText: 'Seu Nome / Apelido',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final nome = nomeController.text.trim();
              if (nome.isNotEmpty) {
                await AuthService().loginComNome(nome);
                if (ctx.mounted) Navigator.pop(ctx);
                onIdentificado();
              }
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  Future<void> _assumir() async {
    _solicitarIdentificacaoSeNecessario(() async {
      setState(() => _loading = true);

      try {
        await ApiClient.assumirSolicitacao(widget.solicitacao.id);

        if (!mounted) return;
        widget.onUpdated();
        Navigator.pop(context);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao assumir: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    });
  }

  Future<void> _mudarStatus(String novoStatus) async {
    setState(() => _loading = true);

    try {
      await ApiClient.atualizarStatus(widget.solicitacao.id, novoStatus);

      if (!mounted) return;
      widget.onUpdated();
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atualizar status: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmarEntrega() async {
    setState(() => _loading = true);

    try {
      await ApiClient.confirmarEntrega(widget.solicitacao.id);

      if (!mounted) return;
      widget.onUpdated();
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao confirmar entrega: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.solicitacao;
    final currentUser = AuthService().currentUser;
    final eSeu = currentUser != null &&
        (currentUser.displayName == item.entregadorNome ||
            (item.entregadorNome?.isNotEmpty ?? false) == false);

    return Scaffold(
      appBar: AppBar(
        title: Text('Detalhe #${item.id.length > 6 ? item.id.substring(0, 6) : item.id}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: ListTile(
                leading: Icon(Icons.flag, color: AppConstantes.corUrgencia(item.urgencia)),
                title: Text('Urgência: ${item.urgencia}'),
                subtitle: Text('Status: ${AppConstantes.formatarStatus(item.status)}'),
              ),
            ),
            const SizedBox(height: 16),

            const Text('Descrição:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
           Text(
  item.descricaoItem.isEmpty ? 'Sem descrição' : item.descricaoItem,
  style: const TextStyle(fontSize: 15),
),

const SizedBox(height: 16),
Text('Solicitante: ${item.solicitanteNome}'),
            if (item.entregadorNome != null && item.entregadorNome!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Entregador: ${item.entregadorNome}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],

            if (item.enderecoEstoque != null) ...[
              const SizedBox(height: 6),
              Text('Estoque/Endereço: ${item.enderecoEstoque}'),
            ],

            const SizedBox(height: 30),

            if (_loading)
              const Center(child: CircularProgressIndicator())
            else ...[
              if (item.status == 'PENDENTE')
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check),
                    label: const Text('Aceitar / Assumir Entrega'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(14),
                    ),
                    onPressed: _assumir,
                  ),
                ),

              if (eSeu &&
                  item.status != 'PENDENTE' &&
                  item.status != 'CONCLUIDA' &&
                  item.status != 'CANCELADA') ...[
                if (item.status == 'EM_CURSO')
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.directions_bike),
                      label: const Text('Marcar Em Rota'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(14),
                      ),
                      onPressed: () => _mudarStatus('EM_ROTA'),
                    ),
                  ),

                if (item.status == 'EM_ROTA') ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.downloading),
                      label: const Text('Marcar Em Baixa'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(14),
                      ),
                      onPressed: () => _mudarStatus('EM_BAIXA'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.done_all),
                      label: const Text('Confirmar Entrega'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(14),
                      ),
                      onPressed: _confirmarEntrega,
                    ),
                  ),
                ],

                if (item.status == 'EM_BAIXA')
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.done_all),
                      label: const Text('Confirmar Entrega'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(14),
                      ),
                      onPressed: _confirmarEntrega,
                    ),
                  ),
              ],
            ]
          ],
        ),
      ),
    );
  }
}