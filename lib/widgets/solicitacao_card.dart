import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/solicitacao.dart';
import '../providers/solicitacao_provider.dart';

class SolicitacaoCard extends StatelessWidget {
  final Solicitacao solicitacao;

  const SolicitacaoCard({super.key, required this.solicitacao});

  void _mostrarDialogoCancelar(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar Solicitação'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Motivo do cancelamento',
            hintText: 'Ex: Pneu furado, imprevisto...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Voltar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              Navigator.of(ctx).pop();
              final provider = Provider.of<SolicitacaoProvider>(context, listen: false);
              final ok = await provider.cancelar(solicitacao.id, controller.text);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok ? 'Solicitação cancelada' : 'Erro ao cancelar'),
                    backgroundColor: ok ? Colors.orange : Colors.red,
                  ),
                );
              }
            },
            child: const Text('Confirmar Cancelamento', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SolicitacaoProvider>(context, listen: false);
    final status = solicitacao.status;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Solicitação #${solicitacao.id.substring(0, solicitacao.id.length > 8 ? 8 : solicitacao.id.length)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Chip(
                  label: Text(
                    status.toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  backgroundColor: _getStatusColor(status),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('📍 Destino: ${solicitacao.localDestino}'),
if (solicitacao.rackOuSlide != null && solicitacao.rackOuSlide!.isNotEmpty)
  Text('📦 Rack/Slide: ${solicitacao.rackOuSlide}'),
            if (solicitacao.entregadorNome != null && solicitacao.entregadorNome!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('👤 Entregador: ${solicitacao.entregadorNome}'),
              ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (status.toLowerCase() == 'pendente' || status.toLowerCase() == 'disponivel')
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Assumir'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      final ok = await provider.assumir(solicitacao.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(ok ? 'Solicitação assumida!' : 'Erro ao assumir'),
                            backgroundColor: ok ? Colors.green : Colors.red,
                          ),
                        );
                      }
                    },
                  ),
                if (status.toLowerCase() == 'em_andamento' || status.toLowerCase() == 'assumida') ...[
                  OutlinedButton.icon(
                    icon: const Icon(Icons.close, size: 18, color: Colors.red),
                    label: const Text('Cancelar', style: TextStyle(color: Colors.red)),
                    onPressed: () => _mostrarDialogoCancelar(context),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.done_all, size: 18),
                    label: const Text('Finalizar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      final ok = await provider.finalizar(solicitacao.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(ok ? 'Solicitação finalizada!' : 'Erro ao finalizar'),
                            backgroundColor: ok ? Colors.blue : Colors.red,
                          ),
                        );
                      }
                    },
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pendente':
      case 'disponivel':
        return Colors.orange;
      case 'em_andamento':
      case 'assumida':
      case 'em_curso':
      case 'em_rota':
      case 'em_baixa':
        return Colors.blue;
      case 'finalizada':
      case 'concluida':
        return Colors.green;
      case 'cancelada':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}