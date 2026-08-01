import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/solicitacao.dart';
import '../services/auth_service.dart';
import '../services/solicitacao_service.dart';
import '../utils/constantes.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../utils/image_utils.dart';
import '../services/preferencias_service.dart';
import '../providers/tema_provider.dart';
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
  Map<String, int> _naoLidas = {};


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

  Future<void> _logout() async {
    await AuthService().signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ativas = _minhas.where((s) => !s.isFinalizada).toList();
    final historico = _minhas.where((s) => s.isFinalizada).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(_nome != null ? 'Solicitante · $_nome' : 'Solicitante'),
        actions: [
          IconButton(
            icon: const Icon(Icons.local_shipping_outlined),
            tooltip: 'Ir para fila do entregador',
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const FilaScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.dashboard_outlined),
            tooltip: 'Painel geral',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DashboardScreen()),
              );
            },
          ),
          IconButton(
            icon: Icon(context.watch<TemaProvider>().icone),
            tooltip: 'Alternar tema',
            onPressed: () => context.read<TemaProvider>().ciclar(),
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => _carregar()),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
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
            ],
          ),
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
