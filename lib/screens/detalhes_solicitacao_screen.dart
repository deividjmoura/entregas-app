import 'package:flutter/material.dart';
import '../utils/constantes.dart';
import '../widgets/acoes_solicitacao_widget.dart';
import '../models/solicitacao.dart';

class DetalhesSolicitacaoScreen extends StatefulWidget {
  final Map<String, dynamic> solicitacao;

  const DetalhesSolicitacaoScreen({super.key, required this.solicitacao});

  @override
  State<DetalhesSolicitacaoScreen> createState() => _DetalhesSolicitacaoScreenState();
}

class _DetalhesSolicitacaoScreenState extends State<DetalhesSolicitacaoScreen> {
  late Map<String, dynamic> _solicitacao;

  @override
  void initState() {
    super.initState();
    _solicitacao = widget.solicitacao;
  }

  @override
  Widget build(BuildContext context) {
    final id = _solicitacao['id']?.toString() ?? '';
    final urgencia = _solicitacao['urgencia']?.toString() ?? 'BAIXA';
    final status = _solicitacao['status']?.toString() ?? 'PENDENTE';
    final descricao = _solicitacao['descricao'] ?? _solicitacao['item'] ?? 'Sem descrição';
    final solicitante = _solicitacao['solicitante'] ?? 'Não informado';
    final destino = _solicitacao['destino'] ?? _solicitacao['localEntrega'] ?? 'Não informado';
    final entregadorNome = _solicitacao['entregadorNome'] ?? 'Nenhum';

    return Scaffold(
      appBar: AppBar(
        title: Text('Solicitação #$id'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Chip(
                          avatar: CircleAvatar(backgroundColor: AppConstantes.corUrgencia(urgencia)),
                          label: Text('Urgência: $urgencia'),
                        ),
                        Chip(
                          label: Text(AppConstantes.formatarStatus(status)),
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text('Item / Descrição:', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    Text(descricao, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Text('Solicitante:', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    Text(solicitante, style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 12),
                    Text('Destino / Local:', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    Text(destino, style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 12),
                    Text('Entregador Responsável:', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    Text(entregadorNome, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Ações Disponíveis',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            AcoesSolicitacaoWidget(
              solicitacao: Solicitacao.fromJson(
                Map<String, dynamic>.from(_solicitacao),
              ),
              onAtualizado: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}
