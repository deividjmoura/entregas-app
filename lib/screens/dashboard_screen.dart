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
    _poll = Timer.periodic(const Duration(seconds: 10), (_) => _carregar(silent: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    _buscaCtrl.dispose();
    super.dispose();
  }

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
    return _todas.where((s) {
      if (_filtroStatus != 'TODOS' && s.status.toUpperCase() != _filtroStatus) {
        return false;
      }
      if (q.isEmpty) return true;
      final blob = [
        s.descricaoItem,
        s.localDestino,
        s.rackOuSlide ?? '',
        s.solicitanteNome,
        s.entregadorNome ?? '',
        s.enderecoEstoque ?? '',
      ].join(' ').toLowerCase();
      return blob.contains(q);
    }).toList();
  }

  int get _pendentes =>
      _todas.where((s) => s.status.toUpperCase() == 'PENDENTE').length;
  int get _emCurso => _todas
      .where((s) =>
          ['EM_CURSO', 'EM_ROTA', 'EM_BAIXA'].contains(s.status.toUpperCase()))
      .length;
  int get _entreguesHoje {
    final now = DateTime.now();
    return _todas.where((s) {
      if (s.status.toUpperCase() != 'ENTREGUE') return false;
      final d = s.entregueEm ?? s.atualizadaEm;
      return d.year == now.year && d.month == now.month && d.day == now.day;
    }).length;
  }

  Widget _kpi(String title, String value, Color color, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 12))),
            ]),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lista = _filtradas;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel geral'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => _carregar()),
        ],
      ),
      body: _loading && _todas.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _erro != null && _todas.isEmpty
              ? Center(child: Text('Erro: $_erro'))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                      child: TextField(
                        controller: _buscaCtrl,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search),
                          hintText: 'Buscar item, local, rack, solicitante...',
                          border: const OutlineInputBorder(),
                          isDense: true,
                          suffixIcon: _buscaCtrl.text.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _buscaCtrl.clear();
                                    setState(() {});
                                  },
                                ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: Row(
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
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: ChoiceChip(
                                label: Text(st == 'TODOS'
                                    ? 'Todos'
                                    : AppConstantes.formatarStatus(st)),
                                selected: _filtroStatus == st,
                                onSelected: (_) =>
                                    setState(() => _filtroStatus = st),
                              ),
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
                        childAspectRatio: 1.3,
                        children: [
                          _kpi('Pendentes', '$_pendentes', Colors.orange, Icons.hourglass_empty),
                          _kpi('Em curso', '$_emCurso', Colors.blue, Icons.local_shipping),
                          _kpi('Entregues hoje', '$_entreguesHoje', Colors.green, Icons.done_all),
                        ],
                      ),
                    ),
                    const Divider(),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () => _carregar(),
                        child: lista.isEmpty
                            ? ListView(children: const [
                                SizedBox(height: 80),
                                Center(child: Text('Nenhum resultado')),
                              ])
                            : ListView.separated(
                                itemCount: lista.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (_, i) {
                                  final s = lista[i];
                                  return ListTile(
                                    dense: true,
                                    title: Text(s.descricaoItem),
                                    subtitle: Text(
                                      '${s.localDestino}'
                                      '${s.rackOuSlide != null ? ' · ${s.rackOuSlide}' : ''}'
                                      ' · ${s.solicitanteNome}',
                                    ),
                                    trailing: Chip(
                                      label: Text(
                                        AppConstantes.formatarStatus(s.status),
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      backgroundColor: AppConstantes.corStatus(s.status)
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
