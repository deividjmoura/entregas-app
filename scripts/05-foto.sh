#!/usr/bin/env bash
set -e

echo "=== [1/1] Atualizando SolicitacaoDetalheScreen para suporte à exibição de Foto ==="

cat > lib/screens/solicitacao_detalhe_screen.dart <<'EOF'
import 'package:flutter/material.dart';
import '../models/solicitacao.dart';
import '../services/solicitacao_service.dart';
import '../services/auth_service.dart';
import '../utils/constantes.dart';

class SolicitacaoDetalheScreen extends StatefulWidget {
  final Solicitacao solicitacao;

  const SolicitacaoDetalheScreen({super.key, required this.solicitacao});

  @override
  State<SolicitacaoDetalheScreen> createState() => _SolicitacaoDetalheScreenState();
}

class _SolicitacaoDetalheScreenState extends State<SolicitacaoDetalheScreen> {
  late Solicitacao _item;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _item = widget.solicitacao;
  }

  Future<void> _assumir() async {
    setState(() => _loading = true);
    final ok = await SolicitacaoService.assumir(_item.id);
    setState(() => _loading = false);

    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitação assumida com sucesso!')),
      );
      Navigator.pop(context, true);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao assumir solicitação.')),
      );
    }
  }

  Future<void> _alterarStatus(String novoStatus) async {
    setState(() => _loading = true);
    final ok = await SolicitacaoService.atualizarStatus(_item.id, novoStatus);
    setState(() => _loading = false);

    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status alterado para ${AppConstantes.formatarStatus(novoStatus)}')),
      );
      Navigator.pop(context, true);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao alterar status.')),
      );
    }
  }

  Future<void> _confirmar() async {
    setState(() => _loading = true);
    final ok = await SolicitacaoService.confirmar(_item.id);
    setState(() => _loading = false);

    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entrega confirmada com sucesso!')),
      );
      Navigator.pop(context, true);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao confirmar entrega.')),
      );
    }
  }

  Future<void> _editarEnderecoEstoque() async {
    final controller = TextEditingController(text: _item.enderecoEstoque ?? '');
    final novoEndereco = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Endereço de Estoque'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Localização (ex: A1-03)',
            hintText: 'Digite o endereço de estoque',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (novoEndereco != null && novoEndereco != _item.enderecoEstoque) {
      setState(() => _loading = true);
      final ok = await SolicitacaoService.atualizarEnderecoEstoque(_item.id, novoEndereco);
      setState(() => _loading = false);

      if (ok && mounted) {
        setState(() {
          _item = Solicitacao(
            id: _item.id,
            solicitanteNome: _item.solicitanteNome,
            entregadorNome: _item.entregadorNome,
            status: _item.status,
            urgencia: _item.urgencia,
            tipo: _item.tipo,
            descricao: _item.descricao,
            enderecoEstoque: novoEndereco,
            alteradoPor: AuthService().currentUser.value?.displayName ?? 'Entregador',
            fotoUrl: _item.fotoUrl,
            favorito: _item.favorito,
            createdAt: _item.createdAt,
            updatedAt: DateTime.now(),
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Endereço de estoque atualizado!')),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao atualizar endereço de estoque.')),
        );
      }
    }
  }

  void _abrirModalFoto(String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('Foto do Item'),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            InteractiveViewer(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text('Erro ao carregar a imagem.'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usuarioAtual = AuthService().currentUser.value?.displayName;
    final eMeuChamado = _item.entregadorNome != null &&
        usuarioAtual != null &&
        _item.entregadorNome!.toLowerCase() == usuarioAtual.toLowerCase();

    final labelStatus = AppConstantes.formatarStatus(_item.status);
    final labelTipo = AppConstantes.formatarTipo(_item.tipo);
    final corUrgencia = AppConstantes.corUrgencia(_item.urgencia);

    return Scaffold(
      appBar: AppBar(
        title: Text('Detalhes #${_item.id.substring(0, _item.id.length > 6 ? 6 : _item.id.length)}'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cabeçalho de Status e Urgência
                  Row(
                    children: [
                      Chip(
                        avatar: CircleAvatar(backgroundColor: corUrgencia, radius: 6),
                        label: Text(_item.urgencia),
                      ),
                      const SizedBox(width: 8),
                      Chip(
                        label: Text(labelStatus),
                        backgroundColor: Colors.blue.shade50,
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 8),

                  Text('Solicitante: ${_item.solicitanteNome}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Entregador: ${_item.entregadorNome ?? 'Nenhum (Pendente)'}', style: const TextStyle(fontSize: 15)),
                  const SizedBox(height: 4),
                  Text('Tipo: $labelTipo', style: const TextStyle(fontSize: 15)),
                  const SizedBox(height: 12),

                  const Text('Descrição:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(_item.descricao.isEmpty ? 'Sem descrição' : _item.descricao),
                  const SizedBox(height: 16),

                  // Card de Endereço de Estoque (3.1)
                  Card(
                    color: Colors.grey.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          const Icon(Icons.inventory_2, color: Colors.blueGrey),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Endereço de Estoque', style: TextStyle(fontWeight: FontWeight.bold)),
                                Text(
                                  _item.enderecoEstoque == null || _item.enderecoEstoque!.isEmpty
                                      ? 'Não informado'
                                      : _item.enderecoEstoque!,
                                  style: const TextStyle(fontSize: 15),
                                ),
                                if (_item.alteradoPor != null && _item.alteradoPor!.isNotEmpty)
                                  Text(
                                    'Alterado por: ${_item.alteradoPor}',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: _editarEnderecoEstoque,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Card de Exibição de Foto (3.2)
                  if (_item.fotoUrl != null && _item.fotoUrl!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Card(
                      color: Colors.grey.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.image, color: Colors.blueGrey),
                                SizedBox(width: 8),
                                Text('Foto do Item', style: TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            GestureDetector(
                              onTap: () => _abrirModalFoto(_item.fotoUrl!),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  _item.fotoUrl!,
                                  height: 180,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    height: 100,
                                    color: Colors.grey.shade200,
                                    child: const Center(child: Text('Erro ao carregar a imagem.')),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Ações Contextuais baseadas no Status
                  if (_item.status == 'PENDENTE')
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.handshake),
                        label: const Text('Aceitar (Assumir Entrega)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: _assumir,
                      ),
                    ),

                  if (eMeuChamado && _item.status != 'PENDENTE' && _item.status != 'ENTREGUE' && _item.status != 'CANCELADA') ...[
                    if (_item.status == 'EM_CURSO')
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.directions_bike),
                          label: const Text('Marcar em Rota'),
                          onPressed: () => _alterarStatus('EM_ROTA'),
                        ),
                      ),
                    if (_item.status == 'EM_ROTA') ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.archive),
                          label: const Text('Marcar em Baixa'),
                          onPressed: () => _alterarStatus('EM_BAIXA'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.check_circle),
                          label: const Text('Confirmar Entrega'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: _confirmar,
                        ),
                      ),
                    ],
                    if (_item.status == 'EM_BAIXA')
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.check_circle),
                          label: const Text('Confirmar Entrega'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: _confirmar,
                        ),
                      ),
                  ],
                ],
              ),
            ),
    );
  }
}
EOF

echo "✨ Script 05-foto.sh concluído com sucesso!"