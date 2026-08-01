import 'chat_screen.dart';
import '../widgets/foto_item.dart';
import 'package:flutter/material.dart';
import '../models/solicitacao.dart';
import '../services/auth_service.dart';
import '../services/solicitacao_service.dart';
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
  State<SolicitacaoDetalheScreen> createState() =>
      _SolicitacaoDetalheScreenState();
}

class _SolicitacaoDetalheScreenState extends State<SolicitacaoDetalheScreen> {
  bool _loading = false;
  late Solicitacao _item;

  @override
  void initState() {
    super.initState();
    _item = widget.solicitacao;
  }

  Future<String?> _obterNomeEntregador() async {
    final nome = await AuthService().entregadorNome;
    if (nome != null && nome.isNotEmpty) return nome;

    final controller = TextEditingController();
    final resultado = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Identifique-se'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Seu nome / apelido',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final n = controller.text.trim();
              if (n.isNotEmpty) Navigator.pop(ctx, n);
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (resultado != null) {
      await AuthService().loginComNome(resultado);
      return resultado;
    }
    return null;
  }

  Future<void> _executarAcao(
    Future<AcaoResultado> Function() acao, {
    required String sucessoMsg,
    String conflitoMsg = 'Ação não permitida no momento',
  }) async {
    setState(() => _loading = true);
    try {
      final resultado = await acao();
      if (!mounted) return;

      switch (resultado) {
        case AcaoResultado.sucesso:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(sucessoMsg), backgroundColor: Colors.green),
          );
          widget.onUpdated();
          Navigator.pop(context);
          break;
        case AcaoResultado.conflito:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(conflitoMsg),
              backgroundColor: Colors.orange.shade800,
            ),
          );
          widget.onUpdated();
          break;
        case AcaoResultado.erro:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao executar a ação'),
              backgroundColor: Colors.red,
            ),
          );
          break;
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _assumir() async {
    final nome = await _obterNomeEntregador();
    if (nome == null) return;
    await _executarAcao(
      () => SolicitacaoService.assumir(_item.id, nome),
      sucessoMsg: 'Solicitação assumida!',
      conflitoMsg: 'Já foi assumida por outro entregador',
    );
  }

  Future<void> _marcarEmRota() async {
    await _executarAcao(
      () => SolicitacaoService.atualizarStatus(_item.id, 'EM_ROTA'),
      sucessoMsg: 'Marcado como Em rota',
    );
  }

  Future<void> _marcarEmBaixa() async {
    await _executarAcao(
      () => SolicitacaoService.atualizarStatus(_item.id, 'EM_BAIXA'),
      sucessoMsg: 'Marcado como Em baixa',
    );
  }

  Future<void> _confirmarEntrega() async {
    await _executarAcao(
      () => SolicitacaoService.confirmar(_item.id),
      sucessoMsg: 'Entrega confirmada!',
      conflitoMsg: 'Só é possível confirmar quando estiver Em rota',
    );
  }

  Future<void> _editarEndereco() async {
    final nome = await _obterNomeEntregador();
    if (nome == null) return;

    final controller = TextEditingController(
      text: _item.enderecoEstoque ?? '',
    );

    final novo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Endereço de Estoque'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_item.enderecoAlteradoPor != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Última alteração por: ${_item.enderecoAlteradoPor}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Endereço (ex: A1-03)',
                border: OutlineInputBorder(),
                hintText: 'A1-03',
              ),
              textCapitalization: TextCapitalization.characters,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx, controller.text.trim());
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (novo == null) return;

    setState(() => _loading = true);
    try {
      final resultado = await SolicitacaoService.atualizarEndereco(
        _item.id,
        enderecoEstoque: novo,
        alteradoPor: nome,
      );

      if (!mounted) return;

      if (resultado == AcaoResultado.sucesso) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Endereço atualizado'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _item = _item.copyWith(
            enderecoEstoque: novo.isEmpty ? null : novo.toUpperCase(),
            enderecoAlteradoPor: nome,
          );
        });
        widget.onUpdated();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao atualizar endereço'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _ehMeu {
    return _item.entregadorNome != null && _item.entregadorNome!.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    final status = item.status.toUpperCase();

    final podeAssumir = status == 'PENDENTE';
    final podeAgir = (status == 'EM_CURSO' ||
            status == 'EM_ROTA' ||
            status == 'EM_BAIXA') &&
        _ehMeu;
    final podeConfirmar = status == 'EM_ROTA' && _ehMeu;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Detalhe #${item.id.length > 8 ? item.id.substring(0, 8) : item.id}',
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color:
                                      AppConstantes.corUrgencia(item.urgencia),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                AppConstantes.formatarUrgencia(item.urgencia),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      AppConstantes.corUrgencia(item.urgencia),
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppConstantes.corStatus(item.status)
                                      .withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  AppConstantes.formatarStatus(item.status),
                                  style: TextStyle(
                                    color:
                                        AppConstantes.corStatus(item.status),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            item.descricaoItem,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _linhaInfo(
                              Icons.place, 'Destino', item.localDestino),
                          if (item.rackOuSlide != null &&
                              item.rackOuSlide!.isNotEmpty)
                            _linhaInfo(Icons.view_module, 'Rack/Slide',
                                item.rackOuSlide!),
                          // Endereço de estoque (clicável)
                          InkWell(
                            onTap: _editarEndereco,
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Icon(Icons.inventory_2,
                                      size: 18, color: Colors.grey.shade600),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Estoque: ',
                                    style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontSize: 14),
                                  ),
                                  Expanded(
                                    child: Text(
                                      item.enderecoEstoque?.isNotEmpty == true
                                          ? item.enderecoEstoque!
                                          : 'Não informado',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14,
                                        color: item.enderecoEstoque
                                                    ?.isNotEmpty ==
                                                true
                                            ? null
                                            : Colors.grey,
                                      ),
                                    ),
                                  ),
                                  Icon(Icons.edit,
                                      size: 16, color: Colors.blue.shade400),
                                ],
                              ),
                            ),
                          ),
                          if (item.enderecoAlteradoPor != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 26, top: 2),
                              child: Text(
                                'Alterado por ${item.enderecoAlteradoPor}',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey.shade500),
                              ),
                            ),
                          _linhaInfo(
                              Icons.person, 'Solicitante', item.solicitanteNome),
                          if (item.entregadorNome != null &&
                              item.entregadorNome!.isNotEmpty)
                            _linhaInfo(Icons.delivery_dining, 'Entregador',
                                item.entregadorNome!),
                          _linhaInfo(Icons.category, 'Tipo',
                              AppConstantes.formatarTipo(item.tipo)),
                          _linhaInfo(Icons.timer, 'Espera',
                              item.tempoEsperaFormatado),
                        ],
                      ),
                    ),
                  ),

                  
                  if (item.temFoto) ...[
                    const SizedBox(height: 12),
                    FotoItem(solicitacaoId: item.id),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 24),

                  if (podeAssumir) ...[
                    ElevatedButton.icon(
                      icon: const Icon(Icons.handyman),
                      label: const Text('Aceitar solicitação'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _assumir,
                    ),
                  ],

                  
                  if (_item.status.toUpperCase() == 'EM_CURSO' ||
                      _item.status.toUpperCase() == 'EM_ROTA' ||
                      _item.status.toUpperCase() == 'EM_BAIXA') ...[
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(solicitacao: _item),
                          ),
                        );
                      },
                      icon: const Icon(Icons.chat),
                      label: const Text('Abrir chat'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (podeAgir) ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.route),
                            label: const Text('Em rota'),
                            onPressed:
                                status == 'EM_ROTA' ? null : _marcarEmRota,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.inventory),
                            label: const Text('Em baixa'),
                            onPressed:
                                status == 'EM_BAIXA' ? null : _marcarEmBaixa,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (podeConfirmar)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Confirmar entrega'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _confirmarEntrega,
                      ),
                  ],

                  if (!podeAssumir &&
                      !podeAgir &&
                      item.isEmAndamento &&
                      item.entregadorNome != null)
                    Card(
                      color: Colors.orange.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(Icons.lock, color: Colors.orange.shade800),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Esta solicitação está com ${item.entregadorNome}',
                                style:
                                    TextStyle(color: Colors.orange.shade900),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _linhaInfo(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
          ),
          Expanded(
            child: Text(
              value,
              style:
                  const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
