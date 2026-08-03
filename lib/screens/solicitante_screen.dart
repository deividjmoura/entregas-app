import '../services/estoque_service.dart';
import '../widgets/solicitante_item_actions.dart';
import 'chat_screen.dart';
import '../widgets/foto_item.dart';
import '../widgets/badge_nao_lidas.dart';
import '../widgets/app_drawer.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/solicitacao.dart';
import '../services/auth_service.dart';
import '../services/solicitacao_service.dart';
import '../services/notificacao_service.dart';
import '../utils/constantes.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/image_utils.dart';
import '../services/preferencias_service.dart';
import 'dashboard_screen.dart';
import 'fila_screen.dart';
import 'login_screen.dart';

class SolicitanteScreen extends StatefulWidget {
  const SolicitanteScreen({super.key});

  @override
  State<SolicitanteScreen> createState() => _SolicitanteScreenState();
}

class _SolicitanteScreenState extends State<SolicitanteScreen> {
  List<Solicitacao> _minhas = [];
  bool _loading = true;
  String? _nome;
  Timer? _polling;

  // Form
  bool _mostrarForm = false;
  final _descricaoCtrl = TextEditingController();
  final _destinoCtrl = TextEditingController();
  final _rackCtrl = TextEditingController();
  String _tipo = 'COMPONENTE_FISICO';
  String _urgencia = 'MEDIA';
  bool _enviando = false;
  String? _fotoBase64;
  String? _sugestaoEstoque;
  Map<String, int> _naoLidas = {};
  Map<String, int> _naoLidasAnterior = {};
  bool _primeiraCargaNaoLidas = true;

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  @override
  void dispose() {
    _polling?.cancel();
    _descricaoCtrl.dispose();
    _destinoCtrl.dispose();
    _rackCtrl.dispose();
    super.dispose();
  }

  Future<void> _iniciar() async {
    _nome = await AuthService().entregadorNome;
    final linha = await PreferenciasService.getLinhaPadrao();
    final rack = await PreferenciasService.getRackPadrao();
    if (linha != null && linha.isNotEmpty) _destinoCtrl.text = linha;
    if (rack != null && rack.isNotEmpty) _rackCtrl.text = rack;
    await _carregar();
    _polling = Timer.periodic(const Duration(seconds: 5), (_) => _carregar(silent: true));
  }

  Future<void> _carregar({bool silent = false}) async {
    if (_nome == null || _nome!.isEmpty) return;
    if (!silent) setState(() => _loading = true);
    try {
      final lista = await SolicitacaoService.listarMinhas(_nome!);
      // Ativas primeiro, depois por data
      lista.sort((a, b) {
        final aAtiva = !a.isFinalizada ? 0 : 1;
        final bAtiva = !b.isFinalizada ? 0 : 1;
        if (aAtiva != bAtiva) return aAtiva.compareTo(bAtiva);
        return b.criadaEm.compareTo(a.criadaEm);
      });
      Map<String, int> naoLidas = {};
      try {
        if (_nome != null) {
          naoLidas = await SolicitacaoService.minhasMensagensNaoLidas(_nome!);
        }
      } catch (_) {}
      if (mounted) {
        if (!_primeiraCargaNaoLidas) {
          for (final entry in naoLidas.entries) {
            final prev = _naoLidasAnterior[entry.key] ?? 0;
            if (entry.value > prev) {
              // Busca descrição para título da notificação
              final solMatch = lista.where((s) => s.id == entry.key);
              final desc = solMatch.isNotEmpty
                  ? solMatch.first.descricaoItem
                  : null;
              NotificacaoService.novaMensagem(
                solicitacaoId: entry.key,
                autorNome: 'Chat',
                texto: 'Nova mensagem (${entry.value} não lida${entry.value > 1 ? 's' : ''})',
                descricaoItem: desc,
              );
            }
          }
        } else {
          _primeiraCargaNaoLidas = false;
        }
        _naoLidasAnterior = Map<String, int>.from(naoLidas);

        setState(() {
          _minhas = lista;
          _naoLidas = naoLidas;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        if (!silent) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao carregar: $e')),
          );
        }
      }
    }
  }

  Future<void> _criar() async {
    if (_nome == null) return;
    final desc = _descricaoCtrl.text.trim();
    final dest = _destinoCtrl.text.trim();
    if (desc.isEmpty || dest.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha descrição e destino')),
      );
      return;
    }

    setState(() => _enviando = true);
    try {
      final criada = await SolicitacaoService.criar(
        tipo: _tipo,
        descricaoItem: desc,
        localDestino: dest,
        rackOuSlide: _rackCtrl.text.trim().isEmpty ? null : _rackCtrl.text.trim(),
        urgencia: _urgencia,
        solicitanteNome: _nome!,
        fotoBase64: _fotoBase64,
      );
      if (criada != null) {
        _descricaoCtrl.clear();
        _rackCtrl.clear();
        _urgencia = 'MEDIA';
        _fotoBase64 = null;
        setState(() => _mostrarForm = false);
        await _carregar();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Solicitação criada!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Falha ao criar solicitação'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _cancelar(Solicitacao s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar solicitação?'),
        content: Text('Deseja cancelar "${s.descricaoItem}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Não')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sim, cancelar'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final r = await SolicitacaoService.cancelar(s.id);
    if (r == AcaoResultado.sucesso) {
      await _carregar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Solicitação cancelada')),
        );
      }
    }
  }

  Future<void> _alterarUrgencia(Solicitacao s) async {
    final opcoes = ['BAIXA', 'MEDIA', 'CRITICA', 'LINHA_PARADA'];
    final nova = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Alterar urgência'),
        children: opcoes.map((u) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, u),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppConstantes.corUrgencia(u),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Text(AppConstantes.formatarUrgencia(u)),
                if (u == s.urgencia) ...[
                  const Spacer(),
                  const Icon(Icons.check, size: 18, color: Colors.green),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
    if (nova == null || nova == s.urgencia) return;
    final r = await SolicitacaoService.alterarUrgencia(s.id, nova);
    if (r == AcaoResultado.sucesso) await _carregar();
  }

  Future<void> _favoritar(Solicitacao s, bool valor) async {
    final r = await SolicitacaoService.favoritar(s.id, valor);
    if (r == AcaoResultado.sucesso) {
      await _carregar(silent: true);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Falha ao favoritar'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _refazer(Solicitacao s) async {
    if (_nome == null) return;
    final criada =
        await SolicitacaoService.refazer(s, solicitanteNome: _nome!);
    if (!mounted) return;
    if (criada != null) {
      await _carregar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Solicitação refeita!'),
            backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Falha ao refazer solicitação'),
            backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _logout() async {
    await AuthService().signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }



  Future<void> _buscarSugestaoEstoque(String item) async {
    final end = await EstoqueService.ultimoEndereco(item);
    if (!mounted) return;
    setState(() => _sugestaoEstoque = end);
  }

  void _abrirChat(Solicitacao s) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ChatScreen(solicitacao: s)),
    ).then((_) => _carregar(silent: true));
  }

  @override
  Widget build(BuildContext context) {
    final ativas = _minhas.where((s) => !s.isFinalizada).toList();
    final historico = _minhas.where((s) => s.isFinalizada).toList();
    final favoritos = _minhas.where((s) => s.favorito).toList()
      ..sort((a, b) => b.criadaEm.compareTo(a.criadaEm));

    return Scaffold(
      appBar: AppBar(
        title: Text(_nome != null ? 'Solicitante · $_nome' : 'Solicitante'),
      ),
      drawer: AppDrawer(
        papel: 'Solicitante',
        nome: _nome,
        items: [
          AppDrawerItem(
            icon: Icons.dashboard_outlined,
            label: 'Painel geral',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DashboardScreen()),
              );
            },
          ),
          AppDrawerItem(
            icon: Icons.local_shipping_outlined,
            label: 'Modo entregador',
            onTap: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const FilaScreen()),
              );
            },
          ),
        ],
        onSair: _logout,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => setState(() => _mostrarForm = !_mostrarForm),
        icon: Icon(_mostrarForm ? Icons.close : Icons.add),
        label: Text(_mostrarForm ? 'Fechar' : 'Nova solicitação'),
      ),
      body: Column(
        children: [
          // Formulário de nova solicitação
          if (_mostrarForm) _buildFormulario(),

          // Lista
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () => _carregar(),
                    child: _minhas.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 120),
                              Center(
                                child: Text(
                                  'Nenhuma solicitação ainda.\nToque em "Nova solicitação".',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                            ],
                          )
                        : ListView(
                            padding: const EdgeInsets.only(bottom: 88),
                            children: [
                              if (ativas.isNotEmpty) ...[
                                _secaoTitulo('Em andamento (${ativas.length})'),
                                ...ativas.map(_cardSolicitacao),
                              ],
                              if (favoritos.isNotEmpty) ...[
                                _secaoTitulo('⭐ Favoritos (${favoritos.length})'),
                                ...favoritos.map(_cardFavorito),
                              ],
                              if (historico.isNotEmpty) ...[
                                _secaoTitulo('Histórico (${historico.length})'),
                                ...historico.take(20).map(_cardSolicitacao),
                              ],
                            ],
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _secaoTitulo(String texto) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }

  Widget _buildFormulario() {
    return Material(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Nova solicitação',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            // Tipo
            DropdownButtonFormField<String>(
              value: _tipo,
              decoration: const InputDecoration(
                labelText: 'Tipo',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(value: 'COMPONENTE_FISICO', child: Text('Componente')),
                DropdownMenuItem(value: 'CIRCUITO_ELETRONICO', child: Text('Circuito')),
                DropdownMenuItem(value: 'OUTROS', child: Text('Outros')),
              ],
              onChanged: (v) => setState(() => _tipo = v ?? 'COMPONENTE_FISICO'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _descricaoCtrl,
decoration: const InputDecoration(
                labelText: 'Descrição do item *',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [UpperCaseTextFormatter()],
              onChanged: (v) {
                final up = v.toUpperCase();
                if (v != up) {
                  _descricaoCtrl.value = TextEditingValue(
                    text: up,
                    selection: TextSelection.collapsed(offset: up.length),
                  );
                }
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _destinoCtrl,
              decoration: const InputDecoration(
                labelText: 'Local de destino *',
                border: OutlineInputBorder(),
                isDense: true,
                hintText: 'Ex: REAR DOOR, LINHA 3',
              ),
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [UpperCaseTextFormatter()],
              onChanged: (v) {
                final up = v.toUpperCase();
                if (v != up) {
                  _destinoCtrl.value = TextEditingValue(
                    text: up,
                    selection: TextSelection.collapsed(offset: up.length),
                  );
                }
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _rackCtrl,
              decoration: const InputDecoration(
                labelText: 'Rack / Slide (opcional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [UpperCaseTextFormatter()],
              onChanged: (v) {
                final up = v.toUpperCase();
                if (v != up) {
                  _rackCtrl.value = TextEditingValue(
                    text: up,
                    selection: TextSelection.collapsed(offset: up.length),
                  );
                }
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _urgencia,
              decoration: const InputDecoration(
                labelText: 'Urgência',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(value: 'BAIXA', child: Text('Baixa')),
                DropdownMenuItem(value: 'MEDIA', child: Text('Média')),
                DropdownMenuItem(value: 'CRITICA', child: Text('Crítica')),
                DropdownMenuItem(value: 'LINHA_PARADA', child: Text('Linha parada')),
              ],
              onChanged: (v) => setState(() => _urgencia = v ?? 'MEDIA'),
            ),
            const SizedBox(height: 14),

            // Foto opcional
            
            if (_sugestaoEstoque != null && _sugestaoEstoque!.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: ActionChip(
                  avatar: const Icon(Icons.inventory_2, size: 16),
                  label: Text('Último estoque: $_sugestaoEstoque'),
                  onPressed: () {
                    // só informativo para o solicitante; entregador edita na fila
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Histórico: $_sugestaoEstoque')),
                    );
                  },
                ),
              ),
Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    final src = await showModalBottomSheet<ImageSource>(
                      context: context,
                      builder: (ctx) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.photo_library),
                              title: const Text('Galeria'),
                              onTap: () =>
                                  Navigator.pop(ctx, ImageSource.gallery),
                            ),
                            ListTile(
                              leading: const Icon(Icons.camera_alt),
                              title: const Text('Câmera'),
                              onTap: () =>
                                  Navigator.pop(ctx, ImageSource.camera),
                            ),
                          ],
                        ),
                      ),
                    );
                    if (src == null) return;
                    final data =
                        await ImageUtils.escolherEConverter(source: src);
                    if (!mounted) return;
                    setState(() => _fotoBase64 = data);
                  },
                  icon: Icon(_fotoBase64 != null
                      ? Icons.check_circle
                      : Icons.add_a_photo),
                  label: Text(
                      _fotoBase64 != null ? 'Foto anexada' : 'Anexar foto'),
                ),
                if (_fotoBase64 != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Remover foto',
                    onPressed: () => setState(() => _fotoBase64 = null),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () async {
                  await PreferenciasService.setLinhaPadrao(_destinoCtrl.text);
                  await PreferenciasService.setRackPadrao(_rackCtrl.text);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Destino salvo como padrão')),
                  );
                },
                icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                label: const Text('Salvar destino como padrão'),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _enviando ? null : _criar,
              icon: _enviando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send),
              label: Text(_enviando ? 'Enviando...' : 'Abrir solicitação'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardSolicitacao(Solicitacao s) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: s.isPendente ? () => _alterarUrgencia(s) : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppConstantes.corUrgencia(s.urgencia),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    AppConstantes.formatarUrgencia(s.urgencia),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppConstantes.corUrgencia(s.urgencia),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppConstantes.corStatus(s.status).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      AppConstantes.formatarStatus(s.status),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppConstantes.corStatus(s.status),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    s.tempoEsperaFormatado,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                s.descricaoItem,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.place, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(s.localDestino, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                  if (s.rackOuSlide != null && s.rackOuSlide!.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Icon(Icons.view_module, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(s.rackOuSlide!, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                  ],
                ],
              ),
              if (s.entregadorNome != null && s.entregadorNome!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.delivery_dining, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      'Entregador: ${s.entregadorNome}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ],
              if (s.isEmAndamento) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: () => _abrirChat(s),
                    icon: const Icon(Icons.chat_outlined, size: 18),
                    label: const Text('Chat'),
                  ),
                ),
              ],
              if (s.isPendente) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _cancelar(s),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Cancelar'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ),
              ],
              if (s.isFinalizada) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: Icon(
                        s.favorito ? Icons.star : Icons.star_border,
                        color: s.favorito
                            ? Colors.amber.shade700
                            : Colors.grey.shade500,
                      ),
                      tooltip:
                          s.favorito ? 'Remover dos favoritos' : 'Favoritar',
                      onPressed: () => _favoritar(s, !s.favorito),
                    ),
                    if (s.status == 'ENTREGUE')
                      OutlinedButton.icon(
                        onPressed: () => _refazer(s),
                        icon: const Icon(Icons.replay, size: 16),
                        label: const Text('Refazer'),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _cardFavorito(Solicitacao s) {
    final cor = AppConstantes.corUrgencia(s.urgencia);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: cor.withOpacity(0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    s.descricaoItem,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${s.localDestino}'
                    '${s.rackOuSlide != null && s.rackOuSlide!.isNotEmpty ? ' (${s.rackOuSlide})' : ''}'
                    ' · ${AppConstantes.formatarTipo(s.tipo)}'
                    ' · ${AppConstantes.formatarUrgencia(s.urgencia)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.star, color: Colors.amber.shade700),
              tooltip: 'Remover dos favoritos',
              onPressed: () => _favoritar(s, false),
            ),
            OutlinedButton.icon(
              onPressed: () => _refazer(s),
              icon: const Icon(Icons.replay, size: 16),
              label: const Text('Refazer'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Força todo o texto digitado para MAIÚSCULO
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
