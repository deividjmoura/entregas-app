import 'package:flutter/material.dart';
import '../models/solicitacao.dart';
import '../services/solicitacao_service.dart';
import '../utils/constantes.dart';

/// Tela de detalhe de uma solicitação.
///
/// Retorna `true` via Navigator.pop quando algo foi alterado (status,
/// urgência, favorito ou cancelamento), pra a FilaScreen saber que precisa
/// recarregar a lista. Retorna `false`/null se nada mudou.
class SolicitacaoDetalheScreen extends StatefulWidget {
  final Solicitacao solicitacao;

  const SolicitacaoDetalheScreen({super.key, required this.solicitacao});

  @override
  State<SolicitacaoDetalheScreen> createState() =>
      _SolicitacaoDetalheScreenState();
}

class _SolicitacaoDetalheScreenState extends State<SolicitacaoDetalheScreen> {
  late Solicitacao _item;
  bool _alterado = false;
  bool _salvando = false;

  static const _corPrincipal = Color(0xFF990011);

  @override
  void initState() {
    super.initState();
    _item = widget.solicitacao;
  }

  void _mostrarErro(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem)),
    );
  }

  Future<void> _alternarFavorito() async {
    setState(() => _salvando = true);
    final novoValor = !_item.favorito;
    final ok = await SolicitacaoService.alternarFavorito(_item.id, novoValor);
    if (!mounted) return;
    if (ok) {
      setState(() {
        _item = _copiarCom(favorito: novoValor);
        _alterado = true;
      });
    } else {
      _mostrarErro('Erro ao atualizar favorito');
    }
    setState(() => _salvando = false);
  }

  Future<void> _alterarStatus() async {
    final novoStatus = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Alterar status'),
        children: statusDisponiveis.map((s) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, s),
            child: Row(
              children: [
                if (s == _item.status) const Icon(Icons.check, size: 18),
                if (s == _item.status) const SizedBox(width: 8),
                Text(s),
              ],
            ),
          );
        }).toList(),
      ),
    );

    if (novoStatus == null || novoStatus == _item.status) return;

    setState(() => _salvando = true);
    final ok = await SolicitacaoService.atualizarStatus(_item.id, novoStatus);
    if (!mounted) return;
    if (ok) {
      setState(() {
        _item = _copiarCom(status: novoStatus);
        _alterado = true;
      });
    } else {
      _mostrarErro('Erro ao atualizar status');
    }
    setState(() => _salvando = false);
  }

  Future<void> _alterarUrgencia() async {
    final novaUrgencia = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Alterar urgência'),
        children: urgenciasValidas.map((u) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, u),
            child: Row(
              children: [
                Icon(Icons.circle, size: 12, color: corUrgencia(u)),
                const SizedBox(width: 10),
                if (u == _item.urgencia) const Icon(Icons.check, size: 18),
                if (u == _item.urgencia) const SizedBox(width: 8),
                Text(urgenciaLabels[u] ?? u),
              ],
            ),
          );
        }).toList(),
      ),
    );

    if (novaUrgencia == null || novaUrgencia == _item.urgencia) return;

    setState(() => _salvando = true);
    final ok =
        await SolicitacaoService.atualizarUrgencia(_item.id, novaUrgencia);
    if (!mounted) return;
    if (ok) {
      setState(() {
        _item = _copiarCom(urgencia: novaUrgencia);
        _alterado = true;
      });
    } else {
      _mostrarErro('Erro ao atualizar urgência');
    }
    setState(() => _salvando = false);
  }

  Future<void> _cancelar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar solicitação'),
        content: Text('Cancelar "${_item.descricaoItem}"?'),
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

    setState(() => _salvando = true);
    final ok = await SolicitacaoService.cancelar(_item.id);
    if (!mounted) return;
    if (ok) {
      // A solicitação deixou de existir na fila ativa — volta pra lista
      // já sinalizando que precisa recarregar.
      Navigator.of(context).pop(true);
      return;
    } else {
      _mostrarErro('Erro ao cancelar');
    }
    setState(() => _salvando = false);
  }

  Solicitacao _copiarCom({
    String? status,
    String? urgencia,
    bool? favorito,
  }) {
    return Solicitacao(
      id: _item.id,
      tipo: _item.tipo,
      descricaoItem: _item.descricaoItem,
      localDestino: _item.localDestino,
      rackOuSlide: _item.rackOuSlide,
      temFoto: _item.temFoto,
      urgencia: urgencia ?? _item.urgencia,
      status: status ?? _item.status,
      favorito: favorito ?? _item.favorito,
      solicitanteNome: _item.solicitanteNome,
      entregadorNome: _item.entregadorNome,
      versao: _item.versao,
      criadaEm: _item.criadaEm,
      atualizadaEm: _item.atualizadaEm,
      entregueEm: _item.entregueEm,
      enderecoEstoque: _item.enderecoEstoque,
      enderecoAlteradoPor: _item.enderecoAlteradoPor,
    );
  }

  String _formatarData(DateTime? data) {
    if (data == null) return '—';
    final d = data.toLocal();
    final dia = d.day.toString().padLeft(2, '0');
    final mes = d.month.toString().padLeft(2, '0');
    final hora = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$dia/$mes/${d.year} às $hora:$min';
  }

  Widget _linhaInfo(String rotulo, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              rotulo,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: Text(valor)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop(_alterado);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: _corPrincipal,
          foregroundColor: Colors.white,
          title: const Text('Detalhe da solicitação'),
          actions: [
            IconButton(
              icon: Icon(
                _item.favorito ? Icons.star : Icons.star_border,
                color: _item.favorito ? Colors.amber : Colors.white,
              ),
              tooltip: 'Favoritar',
              onPressed: _salvando ? null : _alternarFavorito,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Cancelar solicitação',
              onPressed: _salvando ? null : _cancelar,
            ),
          ],
        ),
        body: AbsorbPointer(
          absorbing: _salvando,
          child: Stack(
            children: [
              ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    _item.descricaoItem,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Status
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.local_shipping_outlined),
                      title: const Text('Status'),
                      subtitle: Text(_item.status),
                      trailing: TextButton(
                        onPressed: _alterarStatus,
                        child: const Text('Alterar'),
                      ),
                    ),
                  ),

                  // Urgência
                  Card(
                    child: ListTile(
                      leading: Icon(
                        Icons.circle,
                        color: corUrgencia(_item.urgencia),
                        size: 20,
                      ),
                      title: const Text('Urgência'),
                      subtitle: Text(
                        urgenciaLabels[_item.urgencia] ?? _item.urgencia,
                      ),
                      trailing: TextButton(
                        onPressed: _alterarUrgencia,
                        child: const Text('Alterar'),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Text(
                    'Informações',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const Divider(),

                  _linhaInfo('Tipo', _item.tipo),
                  _linhaInfo('Destino', _item.localDestino),
                  if (_item.rackOuSlide != null)
                    _linhaInfo('Rack/Slide', _item.rackOuSlide!),
                  if (_item.enderecoEstoque != null)
                    _linhaInfo('Endereço estoque', _item.enderecoEstoque!),
                  _linhaInfo('Solicitante', _item.solicitanteNome),
                  _linhaInfo(
                    'Entregador',
                    _item.entregadorNome ?? 'Ainda não atribuído',
                  ),
                  _linhaInfo('Tem foto', _item.temFoto ? 'Sim' : 'Não'),
                  _linhaInfo('Versão', _item.versao.toString()),

                  const SizedBox(height: 16),
                  const Text(
                    'Datas',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const Divider(),

                  _linhaInfo('Criada em', _formatarData(_item.criadaEm)),
                  _linhaInfo(
                    'Atualizada em',
                    _formatarData(_item.atualizadaEm),
                  ),
                  _linhaInfo('Entregue em', _formatarData(_item.entregueEm)),
                ],
              ),
              if (_salvando)
                const Positioned.fill(
                  child: ColoredBox(
                    color: Color(0x11000000),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
