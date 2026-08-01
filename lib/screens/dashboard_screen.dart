import 'dart:async';
import 'package:flutter/material.dart';
import '../services/dashboard_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DashboardMetricas? _m;
  bool _loading = true;
  String? _erro;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _carregar();
    _poll = Timer.periodic(const Duration(seconds: 10), (_) => _carregar(silent: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _carregar({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    try {
      final m = await DashboardService.carregar();
      if (!mounted) return;
      setState(() {
        _m = m;
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

  Widget _card(String titulo, String valor, Color cor, IconData icon) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: cor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    titulo,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              valor,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: cor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
      body: _loading && _m == null
          ? const Center(child: CircularProgressIndicator())
          : _erro != null && _m == null
              ? Center(child: Text('Erro: $_erro'))
              : RefreshIndicator(
                  onRefresh: () => _carregar(),
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 1.4,
                        children: [
                          _card('Pendentes', '${_m!.pendentes}', Colors.orange, Icons.hourglass_empty),
                          _card('Em curso', '${_m!.emCurso}', Colors.blue, Icons.local_shipping),
                          _card('Entregues hoje', '${_m!.entreguesHoje}', Colors.green, Icons.done_all),
                          _card('Canceladas hoje', '${_m!.canceladasHoje}', Colors.red, Icons.cancel),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text('Por local (ativas)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      if (_m!.porLocal.isEmpty)
                        const Text('Nenhuma ativa', style: TextStyle(color: Colors.grey))
                      else
                        ...(_m!.porLocal.entries.toList()
                              ..sort((a, b) => b.value.compareTo(a.value)))
                            .map(
                          (e) => ListTile(
                            dense: true,
                            title: Text(e.key),
                            trailing: Chip(label: Text('${e.value}')),
                          ),
                        ),
                      const SizedBox(height: 16),
                      const Text('Por urgência (ativas)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      if (_m!.porUrgencia.isEmpty)
                        const Text('Nenhuma ativa', style: TextStyle(color: Colors.grey))
                      else
                        ..._m!.porUrgencia.entries.map(
                          (e) => ListTile(
                            dense: true,
                            title: Text(e.key),
                            trailing: Chip(label: Text('${e.value}')),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}
