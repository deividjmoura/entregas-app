
import 'package:flutter/material.dart';
import '../models/solicitacao.dart';
import 'badge_nao_lidas.dart';
import 'foto_item.dart';

class SolicitanteItemActions extends StatelessWidget {
  final Solicitacao solicitacao;
  final int naoLidas;
  final VoidCallback onChat;
  final VoidCallback? onUrgencia;

  const SolicitanteItemActions({
    super.key,
    required this.solicitacao,
    required this.naoLidas,
    required this.onChat,
    this.onUrgencia,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (solicitacao.temFoto)
          IconButton(
            icon: const Icon(Icons.photo_outlined),
            tooltip: 'Ver foto',
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Foto do item'),
                  content: SizedBox(
                    width: 320,
                    child: FotoItem(solicitacaoId: solicitacao.id),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Fechar'),
                    ),
                  ],
                ),
              );
            },
          ),
        BadgeNaoLidas(
          quantidade: naoLidas,
          child: IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            tooltip: 'Chat',
            onPressed: onChat,
          ),
        ),
        if (onUrgencia != null && solicitacao.isPendente)
          IconButton(
            icon: const Icon(Icons.priority_high),
            tooltip: 'Urgência',
            onPressed: onUrgencia,
          ),
      ],
    );
  }
}
