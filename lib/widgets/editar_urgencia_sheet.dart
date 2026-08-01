import 'package:flutter/material.dart';
import '../models/solicitacao.dart';
import '../services/solicitacao_service.dart';
import '../utils/constantes.dart';

class EditarUrgenciaSheet {
  static Future<bool> mostrar(BuildContext context, Solicitacao s) async {
    final opcoes = ['BAIXA', 'MEDIA', 'ALTA', 'CRITICA'];
    // CRITICA pode não existir no backend — filtre se necessário
    String atual = s.urgencia.toUpperCase();
    if (!opcoes.contains(atual)) atual = 'MEDIA';

    final escolhida = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text('Alterar urgência', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              for (final u in opcoes)
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppConstantes.corUrgencia(u),
                    radius: 10,
                  ),
                  title: Text(u),
                  trailing: u == atual ? const Icon(Icons.check) : null,
                  onTap: () => Navigator.pop(ctx, u),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (escolhida == null || escolhida == atual) return false;

    final r = await SolicitacaoService.alterarUrgencia(s.id, escolhida);
    if (r == AcaoResultado.sucesso) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Urgência: $escolhida'),
            backgroundColor: Colors.green,
          ),
        );
      }
      return true;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Falha ao alterar urgência'), backgroundColor: Colors.red),
      );
    }
    return false;
  }
}
