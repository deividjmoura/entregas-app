import 'chat_screen.dart';
import '../services/presenca_service.dart';
import '../services/pusher_service.dart';
import '../services/notificacao_service.dart';
import '../widgets/elapsed_time.dart';
import 'solicitante_screen.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../models/solicitacao.dart';
import '../services/solicitacao_service.dart';
import '../services/auth_service.dart';
import '../utils/constantes.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';
import '../widgets/foto_item.dart';
import '../widgets/app_drawer.dart';

class FilaScreen extends StatefulWidget {
  const FilaScreen({super.key});

  @override
  State<FilaScreen> createState() => _FilaScreenState();
}

class _FilaScreenState extends State<FilaScreen> {
  List<Solicitacao> _solicitacoes = [];
  bool _isLoading = true;
  String? _nomeEntregador;
  Timer? _pollingTimer;
  String? _expandedId; // card expandido na fila
  final Set<String> _gruposColapsados = {}; // chaves dos grupos comprimidos
  bool _acaoLoading = false;
  final Set<String> _selecionados = {};
  bool _aceitandoLote = false;
  bool _concluindoLista = false;
  int _online = 0;
  Timer? _presencaTimer;
  /// IDs de PENDENTE já vistos — evita notificar de novo no polling.
  final Set<String> _pendentesConhecidos = {};
  bool _primeiraCarga = true;
  Map<String, int> _naoLidasAnterior = {};
  bool _primeiraCargaNaoLidas = true;

  @override
  void initState() {
    super.initState();
    _carregarDados();
    _tickPresenca();
    _presencaTimer = Timer.periodic(const Duration(seconds: 20), (_) => _tickPresenca());
    // Atualiza a fila a cada 5 segundos (igual ao polling do web)
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _carregarDados(silent: true);
    });
    // Real-time: nova entrega via Pusher → notificação local com ação Aceitar
    PusherService.conectar(onNovaEntrega: _onNovaEntregaPusher);
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _presencaTimer?.cancel();
    PusherService.desconectar();
    super.dispose();
  }

  void _onNovaEntregaPusher(Solicitacao s) {
    if (s.status.toUpperCase() != 'PENDENTE') return;
    if (_pendentesConhecidos.contains(s.id)) return;
    _pendentesConhecidos.add(s.id);
    NotificacaoService.novaSolicitacao(
      solicitacaoId: s.id,
      descricao: s.descricaoItem,
      local: s.localDestino,
      urgencia: AppConstantes.formatarUrgencia(s.urgencia),
    );
    // Atualiza a lista em silêncio
    _carregarDados(silent: true);
  }

  Future<void> _carregarDados({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);

    try {
      final nome = await AuthService().getEntregadorNome();
      final todas = await SolicitacaoService.listar();

      // Só itens ativos na fila (igual ao web: PENDENTE + em andamento)
      final lista = todas.where((s) {
        final st = s.status.toUpperCase();
        return st == 'PENDENTE' ||
            st == 'EM_CURSO' ||
            st == 'EM_ROTA' ||
            st == 'EM_BAIXA';
      }).toList();

      // 1º prioridade (urgência), 2º tempo de espera (mais antiga primeiro)
      lista.sort((a, b) {
        // 1) Minhas em andamento primeiro
        // 2) Depois pendentes
        // 3) Dentro do grupo: urgência (maior primeiro), depois mais antigas
        int grupo(Solicitacao s) {
          final st = s.status.toUpperCase();
          final minha = s.entregadorNome != null &&
              _nomeEntregador != null &&
              s.entregadorNome == _nomeEntregador;
          if (minha &&
              (st == 'EM_CURSO' || st == 'EM_ROTA' || st == 'EM_BAIXA')) {
            return 0;
          }
          if (st == 'PENDENTE') return 1;
          if (st == 'EM_CURSO' || st == 'EM_ROTA' || st == 'EM_BAIXA') return 2;
          return 3;
        }

        final g = grupo(a).compareTo(grupo(b));
        if (g != 0) return g;
        final pesoA = AppConstantes.pesoUrgencia(a.urgencia);
        final pesoB = AppConstantes.pesoUrgencia(b.urgencia);
        if (pesoA != pesoB) return pesoB.compareTo(pesoA);
        return a.criadaEm.compareTo(b.criadaEm);
      });

      if (mounted) {
        final pendentesAgora = lista
            .where((s) => s.status.toUpperCase() == 'PENDENTE')
            .toList();
        if (!_primeiraCarga) {
          for (final s in pendentesAgora) {
            if (!_pendentesConhecidos.contains(s.id)) {
              _pendentesConhecidos.add(s.id);
              NotificacaoService.novaSolicitacao(
                solicitacaoId: s.id,
                descricao: s.descricaoItem,
                local: s.localDestino,
                urgencia: AppConstantes.formatarUrgencia(s.urgencia),
              );
            }
          }
        } else {
          for (final s in pendentesAgora) {
            _pendentesConhecidos.add(s.id);
          }
          _primeiraCarga = false;
        }
        // Limpa IDs que saíram da fila pendente
        _pendentesConhecidos.removeWhere(
          (id) => !pendentesAgora.any((s) => s.id == id),
        );

        // Notifica mensagens novas nas entregas em andamento deste entregador
        if (nome != null && nome.isNotEmpty) {
          try {
            final naoLidas =
                await SolicitacaoService.minhasMensagensNaoLidas(nome);
            if (!_primeiraCargaNaoLidas) {
              for (final entry in naoLidas.entries) {
                final prev = _naoLidasAnterior[entry.key] ?? 0;
                if (entry.value > prev) {
                  final solMatch = lista.where((s) => s.id == entry.key);
                  final desc = solMatch.isNotEmpty
                      ? solMatch.first.descricaoItem
                      : null;
                  NotificacaoService.novaMensagem(
                    solicitacaoId: entry.key,
                    autorNome: 'Chat',
                    texto:
                        'Nova mensagem (${entry.value} não lida${entry.value > 1 ? 's' : ''})',
                    descricaoItem: desc,
                  );
                }
              }
            } else {
              _primeiraCargaNaoLidas = false;
            }
            _naoLidasAnterior = Map<String, int>.from(naoLidas);
          } catch (_) {}
        }

        setState(() {
          _nomeEntregador = nome;
          _solicitacoes = lista;
          _isLoading = false;
          _selecionados.removeWhere((id) => !lista.any(
              (s) => s.id == id && s.status.toUpperCase() == 'PENDENTE'));
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        if (!silent) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao carregar fila: $e')),
          );
        }
      }
    }
  }

  Future<void> _logout() async {
    await AuthService().signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  bool _colapsado(String chave) => _gruposColapsados.contains(chave);

  void _alternarColapso(String chave) {
    setState(() {
      if (_gruposColapsados.contains(chave)) {
        _gruposColapsados.remove(chave);
      } else {
        _gruposColapsados.add(chave);
      }
    });
  }

  /// Cabeçalho de grupo clicável, com seta indicando expandido/comprimido.
  /// [trailing] fica visível só quando o grupo está expandido, pra não
  /// poluir a lista quando comprimida.
  Widget _buildGroupHeader({
    required String chave,
    required Widget titulo,
    Widget? trailing,
  }) {
    final colapsado = _colapsado(chave);
    return InkWell(
      onTap: () => _alternarColapso(chave),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Row(
          children: [
            Expanded(child: titulo),
            if (trailing != null && !colapsado) ...[
              trailing,
              const SizedBox(width: 6),
            ],
            Icon(
              colapsado ? Icons.expand_more : Icons.expand_less,
              color: Colors.grey.shade500,
            ),
          ],
        ),
      ),
    );
  }

  /// Agrupa as solicitações por local de destino
  Map<String, List<Solicitacao>> _agruparPorLocal(List<Solicitacao> lista) {
    final Map<String, List<Solicitacao>> grupos = {};
    for (final s in lista) {
      final local = s.localDestino;
      grupos.putIfAbsent(local, () => []).add(s);
    }
    // Mantém a ordem de prioridade/tempo dentro de cada grupo
    for (final entry in grupos.entries) {
      entry.value.sort((a, b) {
        final pesoA = AppConstantes.pesoUrgencia(a.urgencia);
        final pesoB = AppConstantes.pesoUrgencia(b.urgencia);
        if (pesoA != pesoB) return pesoB.compareTo(pesoA);
        return a.criadaEm.compareTo(b.criadaEm);
      });
    }
    return grupos;
  }

  @override
  Widget build(BuildContext context) {
    // "Carrinho": minhas solicitações já aceitas e em andamento
    final minhas = _solicitacoes.where((s) {
      final st = s.status.toUpperCase();
      final ehMinha = s.entregadorNome != null &&
          s.entregadorNome!.isNotEmpty &&
          _nomeEntregador != null &&
          s.entregadorNome!.toLowerCase() == _nomeEntregador!.toLowerCase();
      return ehMinha && (st == 'EM_CURSO' || st == 'EM_ROTA' || st == 'EM_BAIXA');
    }).toList();

    // Fila de despacho: só as ainda não aceitas
    final pendentes =
        _solicitacoes.where((s) => s.status.toUpperCase() == 'PENDENTE').toList();

    final grupos = _agruparPorLocal(pendentes);
    final locais = grupos.keys.toList();
    // Locais com maior urgência / item mais antigo primeiro
    locais.sort((la, lb) {
      final ga = grupos[la]!;
      final gb = grupos[lb]!;
      final pesoA = ga.map((s) => AppConstantes.pesoUrgencia(s.urgencia)).fold<int>(0, (a, b) => a > b ? a : b);
      final pesoB = gb.map((s) => AppConstantes.pesoUrgencia(s.urgencia)).fold<int>(0, (a, b) => a > b ? a : b);
      if (pesoA != pesoB) return pesoB.compareTo(pesoA);
      final tempoA = ga.map((s) => s.criadaEm).reduce((a, b) => a.isBefore(b) ? a : b);
      final tempoB = gb.map((s) => s.criadaEm).reduce((a, b) => a.isBefore(b) ? a : b);
      return tempoA.compareTo(tempoB);
    });

    final totalEmRota = minhas.where((s) => s.status.toUpperCase() == 'EM_ROTA').length;

    final List<Widget> corpo = [];

    // ===== Minha lista (carrinho) — sempre no topo =====
    if (minhas.isNotEmpty) {
      corpo.add(
        _buildGroupHeader(
          chave: 'minha_lista',
          titulo: Row(
            children: [
              const Icon(Icons.shopping_cart, size: 18),
              const SizedBox(width: 6),
              Text(
                'Minha lista (${minhas.length})',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          trailing: totalEmRota > 0
              ? ElevatedButton.icon(
                  onPressed:
                      _concluindoLista ? null : () => _concluirLista(minhas),
                  icon: _concluindoLista
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.done_all, size: 16),
                  label: Text(_concluindoLista
                      ? 'Concluindo...'
                      : 'Concluir lista ($totalEmRota em rota)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                )
              : null,
        ),
      );
      if (!_colapsado('minha_lista')) {
        corpo.addAll(minhas.map((sol) => _buildCard(sol)));
      }
    }

    // ===== Fila de despacho — ainda não aceitas, logo abaixo da minha lista =====
    corpo.add(
      _buildGroupHeader(
        chave: 'fila_despacho',
        titulo: Row(
          children: [
            const Icon(Icons.inbox, size: 18),
            const SizedBox(width: 6),
            Text(
              'Fila de despacho (${pendentes.length})',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );

    if (!_colapsado('fila_despacho')) {
      if (pendentes.isEmpty) {
        corpo.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Nenhuma solicitação pendente no momento',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ),
        );
      } else {
        for (final local in locais) {
          final items = grupos[local]!;
          final chaveLocal = 'local_$local';
          corpo.add(
            _buildGroupHeader(
              chave: chaveLocal,
              titulo: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _corParaLocal(local),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    local,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '(${items.length})',
                    style:
                        TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          );
          if (!_colapsado(chaveLocal)) {
            corpo.addAll(items.map((sol) => _buildCard(sol)));
          }
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _nomeEntregador != null
              ? 'Fila · $_nomeEntregador · $_online online'
              : 'Fila · $_online online',
        ),
      ),
      drawer: AppDrawer(
        papel: 'Entregador',
        nome: _nomeEntregador,
        online: _online,
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
            icon: Icons.assignment_ind_outlined,
            label: 'Modo solicitante',
            onTap: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const SolicitanteScreen()),
              );
            },
          ),
        ],
        onSair: _logout,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _carregarDados(),
              child: _solicitacoes.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 120),
                        Center(
                          child: Text(
                            'Nenhuma solicitação na fila',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 90),
                      children: corpo,
                    ),
            ),
      bottomNavigationBar: _selecionados.isEmpty
          ? null
          : SafeArea(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: Theme.of(context).colorScheme.surface,
                child: Row(
                  children: [
                    Text(
                      '🛒 ${_selecionados.length} selecionado${_selecionados.length > 1 ? 's' : ''}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => setState(() => _selecionados.clear()),
                      child: const Text('Limpar'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _aceitandoLote ? null : _aceitarSelecionados,
                      icon: _aceitandoLote
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.playlist_add_check, size: 18),
                      label: Text(_aceitandoLote
                          ? 'Aceitando...'
                          : 'Aceitar selecionados (${_selecionados.length})'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }


  Widget _buildCard(Solicitacao sol) {
    final corUrgencia = AppConstantes.corUrgencia(sol.urgencia);
    final labelUrgencia = AppConstantes.formatarUrgencia(sol.urgencia);
    final labelStatus = AppConstantes.formatarStatus(sol.status);
    final expandido = _expandedId == sol.id;
    final status = sol.status.toUpperCase();
    final podeAssumir = status == 'PENDENTE';
    final ehMeu = sol.entregadorNome != null &&
        sol.entregadorNome!.isNotEmpty &&
        (_nomeEntregador != null &&
            sol.entregadorNome!.toLowerCase() == _nomeEntregador!.toLowerCase());
    final podeAgir = (status == 'EM_CURSO' ||
            status == 'EM_ROTA' ||
            status == 'EM_BAIXA') &&
        ehMeu;
    final podeConfirmar = status == 'EM_ROTA' && ehMeu;
    final deOutro = (status == 'EM_CURSO' ||
            status == 'EM_ROTA' ||
            status == 'EM_BAIXA') &&
        !ehMeu &&
        sol.entregadorNome != null;
    final selecionado = _selecionados.contains(sol.id);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: expandido ? 3 : 1.5,
      color: selecionado ? Colors.amber.shade50 : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: selecionado
            ? BorderSide(color: Colors.amber.shade600, width: 1.5)
            : expandido
                ? BorderSide(color: Colors.blue.shade200, width: 1.5)
                : BorderSide.none,
      ),
      child: Column(
        children: [
          // Área clicável: expande/recolhe
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              setState(() {
                _expandedId = expandido ? null : sol.id;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Linha 1: urgência + status + timer
                  Row(
                    children: [
                      if (podeAssumir)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _alternarSelecao(sol.id),
                            child: Icon(
                              selecionado
                                  ? Icons.check_box
                                  : Icons.check_box_outline_blank,
                              size: 20,
                              color: selecionado
                                  ? Colors.amber.shade800
                                  : Colors.grey.shade400,
                            ),
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: corUrgencia,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          labelUrgencia,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppConstantes.corStatus(sol.status)
                              .withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          labelStatus,
                          style: TextStyle(
                            color: AppConstantes.corStatus(sol.status),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.timer_outlined,
                          size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 3),
                      Text(
                        sol.tempoEsperaFormatado,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        expandido
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: Colors.grey.shade500,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    sol.descricaoItem,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: expandido ? 4 : 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (sol.rackOuSlide != null &&
                          sol.rackOuSlide!.isNotEmpty) ...[
                        Icon(Icons.view_module,
                            size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 3),
                        Text(
                          sol.rackOuSlide!,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade700),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Icon(Icons.person_outline,
                          size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          sol.solicitanteNome,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (sol.entregadorNome != null &&
                      sol.entregadorNome!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.delivery_dining,
                            size: 14, color: Colors.blue.shade600),
                        const SizedBox(width: 3),
                        Text(
                          sol.entregadorNome!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Área expandida: detalhes extras + botões de ação
          if (expandido) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Info extra — endereço de estoque (editável)
                  InkWell(
                    onTap: () => _editarEndereco(sol),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(Icons.inventory_2,
                              size: 16, color: Colors.grey.shade700),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              (sol.enderecoEstoque != null &&
                                      sol.enderecoEstoque!.isNotEmpty)
                                  ? 'Estoque: ${sol.enderecoEstoque}'
                                  : 'Definir endereço no estoque',
                              style: TextStyle(
                                fontSize: 13,
                                color: (sol.enderecoEstoque != null &&
                                        sol.enderecoEstoque!.isNotEmpty)
                                    ? Colors.grey.shade800
                                    : Colors.blue.shade700,
                                fontWeight: (sol.enderecoEstoque == null ||
                                        sol.enderecoEstoque!.isEmpty)
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          Icon(Icons.edit,
                              size: 16, color: Colors.blue.shade400),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Icon(Icons.category,
                          size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 6),
                      Text(
                        AppConstantes.formatarTipo(sol.tipo),
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade800),
                      ),
                      if (sol.temFoto) ...[
                        const Spacer(),
                        IconButton(
                          icon: Icon(Icons.photo_outlined,
                              size: 20, color: Colors.blue.shade600),
                          tooltip: 'Ver foto',
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _verFoto(sol),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Botões de ação
                  if (_acaoLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else if (podeAssumir)
                    ElevatedButton.icon(
                      onPressed: () => _acaoAssumir(sol),
                      icon: const Icon(Icons.handyman, size: 18),
                      label: const Text('Aceitar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    )
                  else if (podeAgir) ...[

                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(solicitacao: sol),
                          ),
                        );
                      },
                      icon: const Icon(Icons.chat, size: 16),
                      label: const Text('Chat'),
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: status == 'EM_ROTA'
                                ? null
                                : () => _acaoStatus(sol, 'EM_ROTA'),
                            icon: const Icon(Icons.route, size: 16),
                            label: const Text('Em rota'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: status == 'EM_BAIXA'
                                ? null
                                : () => _acaoStatus(sol, 'EM_BAIXA'),
                            icon: const Icon(Icons.inventory, size: 16),
                            label: const Text('Em baixa'),
                          ),
                        ),
                      ],
                    ),
                    if (podeConfirmar) ...[
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () => _acaoConfirmar(sol),
                        icon: const Icon(Icons.check_circle, size: 18),
                        label: const Text('Confirmar entrega'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ],
                  ] else if (deOutro)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.lock,
                              size: 16, color: Colors.orange.shade800),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Com ${sol.entregadorNome}',
                              style: TextStyle(
                                  color: Colors.orange.shade900, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }



  Future<void> _tickPresenca() async {
    try {
      final n = await PresencaService.heartbeat();
      if (mounted) setState(() => _online = n);
    } catch (_) {}
  }

  Future<void> _editarEndereco(Solicitacao sol) async {
    final nome = _nomeEntregador ?? await AuthService().entregadorNome;
    if (nome == null || nome.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Identifique-se antes de alterar o estoque')),
      );
      return;
    }

    final controller = TextEditingController(text: sol.enderecoEstoque ?? '');
    final novo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Endereço de estoque'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(sol.descricaoItem,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
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
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (novo == null) return;

    setState(() => _acaoLoading = true);
    try {
      final r = await SolicitacaoService.atualizarEndereco(
        sol.id,
        enderecoEstoque: novo,
        alteradoPor: nome,
      );
      if (!mounted) return;
      if (r == AcaoResultado.sucesso) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Endereço de estoque atualizado'),
            backgroundColor: Colors.green,
          ),
        );
        await _carregarDados(silent: true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao atualizar endereço'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _acaoLoading = false);
    }
  }

  void _verFoto(Solicitacao sol) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: FotoItem(solicitacaoId: sol.id, height: 400),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              style: IconButton.styleFrom(backgroundColor: Colors.black45),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _acaoAssumir(Solicitacao sol) async {
    final nome = _nomeEntregador ?? await AuthService().entregadorNome;
    if (nome == null || nome.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Identifique-se antes de aceitar')),
      );
      return;
    }
    setState(() => _acaoLoading = true);
    try {
      final r = await SolicitacaoService.assumir(sol.id, nome);
      if (!mounted) return;
      if (r == AcaoResultado.sucesso) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Solicitação aceita!'),
              backgroundColor: Colors.green),
        );
        setState(() => _expandedId = null);
        await _carregarDados(silent: true);
      } else if (r == AcaoResultado.conflito) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Já foi assumida por outro entregador'),
              backgroundColor: Colors.orange),
        );
        await _carregarDados(silent: true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Erro ao aceitar'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _acaoLoading = false);
    }
  }

  void _alternarSelecao(String id) {
    setState(() {
      if (_selecionados.contains(id)) {
        _selecionados.remove(id);
      } else {
        _selecionados.add(id);
      }
    });
  }

  /// Aceita de uma vez todas as solicitações marcadas na fila de despacho
  Future<void> _aceitarSelecionados() async {
    final nome = _nomeEntregador ?? await AuthService().entregadorNome;
    if (nome == null || nome.isEmpty || _selecionados.isEmpty) return;
    setState(() => _aceitandoLote = true);
    try {
      final ids = _selecionados.toList();
      final resultados = await Future.wait(
        ids.map((id) => SolicitacaoService.assumir(id, nome)),
      );
      final falhas =
          resultados.where((r) => r != AcaoResultado.sucesso).length;
      if (!mounted) return;
      if (falhas > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(falhas == resultados.length
                ? 'Não foi possível aceitar os itens selecionados'
                : '$falhas item(ns) já tinham sido assumidos por outro entregador'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Itens aceitos!'), backgroundColor: Colors.green),
        );
      }
      setState(() => _selecionados.clear());
      await _carregarDados(silent: true);
    } finally {
      if (mounted) setState(() => _aceitandoLote = false);
    }
  }

  /// Confirma de uma vez todas as minhas solicitações em rota (ou em baixa)
  Future<void> _concluirLista(List<Solicitacao> minhas) async {
    final alvo = minhas
        .where((s) => s.status == 'EM_ROTA' || s.status == 'EM_BAIXA')
        .toList();
    if (alvo.isEmpty) return;
    setState(() => _concluindoLista = true);
    try {
      await Future.wait(
        alvo.map((s) => SolicitacaoService.confirmar(s.id)),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Lista concluída!'), backgroundColor: Colors.green),
      );
      await _carregarDados(silent: true);
    } finally {
      if (mounted) setState(() => _concluindoLista = false);
    }
  }

  Future<void> _acaoStatus(Solicitacao sol, String status) async {
    setState(() => _acaoLoading = true);
    try {
      final r = await SolicitacaoService.atualizarStatus(sol.id, status);
      if (!mounted) return;
      if (r == AcaoResultado.sucesso) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(status == 'EM_ROTA'
                ? 'Marcado em rota'
                : 'Marcado em baixa'),
            backgroundColor: Colors.green,
          ),
        );
        await _carregarDados(silent: true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Erro ao atualizar'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _acaoLoading = false);
    }
  }

  Future<void> _acaoConfirmar(Solicitacao sol) async {
    setState(() => _acaoLoading = true);
    try {
      final r = await SolicitacaoService.confirmar(sol.id);
      if (!mounted) return;
      if (r == AcaoResultado.sucesso) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Entrega confirmada!'),
              backgroundColor: Colors.green),
        );
        setState(() => _expandedId = null);
        await _carregarDados(silent: true);
      } else if (r == AcaoResultado.conflito) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Só confirma quando estiver Em rota'),
              backgroundColor: Colors.orange),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Erro ao confirmar'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _acaoLoading = false);
    }
  }


  /// Gera uma cor estável a partir do nome do local (igual ao web)
  Color _corParaLocal(String nome) {
    int hash = 0;
    for (int i = 0; i < nome.length; i++) {
      hash = nome.codeUnitAt(i) + ((hash << 5) - hash);
    }
    final hue = (hash.abs() % 360).toDouble();
    return HSLColor.fromAHSL(1.0, hue, 0.65, 0.55).toColor();
  }
}
