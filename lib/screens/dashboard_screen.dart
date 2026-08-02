import 'dart:async';
import 'package:flutter/material.dart';
import '../models/solicitacao.dart';
import '../services/solicitacao_service.dart';
import '../utils/constantes.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Solicitacao> _todas = [];
  bool _loading = true;
  String? _erro;
  Timer? _poll;
  final _buscaCtrl = TextEditingController();
  String _filtroStatus = 'TODOS';

  @override
  void initState() {
    super.initState();
    _carregar();
    _poll =
        Timer.periodic(const Duration(seconds: 10), (_) => _carregar(silent: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    _buscaCtrl.dispose();
    super.dispose();
  }

  bool _mesmoDia(DateTime d) {
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  /// Referência de data da solicitação (criação ou entrega)
  DateTime _ref(Solicitacao s) => s.entregueEm ?? s.criadaEm;

  Future<void> _carregar({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    try {
      final lista = await SolicitacaoService.listar();
      if (!mounted) return;
      setState(() {
        _todas = lista;
        _loading = false;
        _erro = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (!silent) _erro = e.toString();
      });
    }
  }

  List<Solicitacao> get _filtradas {
    final q = _buscaCtrl.text.trim().toLowerCase();
    final buscando = q.isNotEmpty;

    return _todas.where((s) {
      // Sem busca: só o dia de hoje
      if (!buscando && !_mesmoDia(_ref(s))) return false;

      if (_filtroStatus != 'TODOS' &&
          s.status.toUpperCase() != _filtroStatus) {
        return false;
      }

      if (!buscando) return true;

      final blob = [
        s.descricaoItem,
        s.localDestino,
        s.rackOuSlide ?? '',
        s.solicitanteNome,
        s.entregadorNome ?? '',
        s.enderecoEstoque ?? '',
      ].join(' ').toLowerCase();
      return blob.contains(q);
    }).toList()
      ..sort((a, b) => _ref(b).compareTo(_ref(a)));
  }

  int get _pendentes => _todas
      .where((s) =>
          s.status.toUpperCase() == 'PENDENTE' && _mesmoDia(s.criadaEm))
      .length;

  int get _emCurso => _todas
      .where((s) =>
          ['EM_CURSO', 'EM_ROTA', 'EM_BAIXA'].contains(s.status.toUpperCase()))
      .length;

  int get _entreguesHoje => _todas.where((s) {
        if (s.status.toUpperCase() != 'ENTREGUE') return false;
        final d = s.entregueEm ?? s.atualizadaEm;
        return _mesmoDia(d);
      }).length;

  Widget _kpi(String title, String value, Color color, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 4),
              Expanded(
                child: Text(title,
                    style: const TextStyle(fontSize: 11),
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lista = _filtradas;
    final buscando = _buscaCtrl.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel geral'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _carregar(),
          ),
        ],
      ),
      body: _loading && _todas.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _erro != null && _todas.isEmpty
              ? Center(child: Text('Erro: $_erro'))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                      child: TextField(
                        controller: _buscaCtrl,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search, size: 20),
                          hintText:
                              'Buscar histórico (item, local, solicitante...)',
                          border: const OutlineInputBorder(),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          suffixIcon: _buscaCtrl.text.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _buscaCtrl.clear();
                                    setState(() {});
                                  },
                                ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          buscando
                              ? 'Resultados da busca (todo o histórico)'
                              : 'Mostrando apenas o dia de hoje',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final st in [
                            'TODOS',
                            'PENDENTE',
                            'EM_CURSO',
                            'EM_ROTA',
                            'EM_BAIXA',
                            'ENTREGUE',
                            'CANCELADA',
                          ])
                            _FiltroStatusPill(
                              label: st == 'TODOS'
                                  ? 'Todos'
                                  : AppConstantes.formatarStatus(st),
                              selecionado: _filtroStatus == st,
                              onTap: () => setState(() => _filtroStatus = st),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: GridView.count(
                        crossAxisCount: 3,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: 1.45,
                        children: [
                          _kpi('Pendentes', '$_pendentes', Colors.orange,
                              Icons.hourglass_empty),
                          _kpi('Em curso', '$_emCurso', Colors.blue,
                              Icons.local_shipping),
                          _kpi('Entregues hoje', '$_entreguesHoje', Colors.green,
                              Icons.done_all),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () => _carregar(),
                        child: lista.isEmpty
                            ? ListView(
                                children: [
                                  const SizedBox(height: 80),
                                  Center(
                                    child: Text(
                                      buscando
                                          ? 'Nenhum resultado para a busca'
                                          : 'Nenhuma solicitação hoje',
                                      style: TextStyle(
                                          color: Colors.grey.shade600),
                                    ),
                                  ),
                                ],
                              )
                            : ListView.separated(
                                itemCount: lista.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (_, i) {
                                  final s = lista[i];
                                  return ListTile(
                                    dense: true,
                                    title: Text(s.descricaoItem,
                                        style: const TextStyle(fontSize: 14)),
                                    subtitle: Text(
                                      '${s.localDestino}'
                                      '${s.rackOuSlide != null ? ' · ${s.rackOuSlide}' : ''}'
                                      ' · ${s.solicitanteNome}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    trailing: Chip(
                                      label: Text(
                                        AppConstantes.formatarStatus(s.status),
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                      labelPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 6),
                                      backgroundColor:
                                          AppConstantes.corStatus(s.status)
                                              .withOpacity(0.15),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

/// Pill de filtro neutra — sem checkmark, sem sombra, sem "salto" de
/// tamanho ao selecionar. A cor de seleção é neutra (não usa a cor do
/// status), pra não competir com as cores de status que já aparecem nos
/// cards da lista logo abaixo.
class _FiltroStatusPill extends StatelessWidget {
  final String label;
  final bool selecionado;
  final VoidCallback onTap;

  const _FiltroStatusPill({
    required this.label,
    required this.selecionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selecionado ? Colors.black87 : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selecionado ? Colors.black87 : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: selecionado ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }
}
