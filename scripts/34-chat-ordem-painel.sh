#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
echo "==> [34] Chat visível, ordem da fila, painel só do dia + chips menores..."

python3 - <<'PY'
from pathlib import Path
import re

# ========== FILA ==========
p = Path("lib/screens/fila_screen.dart")
t = p.read_text()

# 1) Import chat
if "chat_screen.dart" not in t:
    t = "import 'chat_screen.dart';\n" + t

# 2) Sort: minhas em andamento primeiro, depois pendentes por urgência
old_sort = None
# Replace the lista.sort block in _carregarDados
sort_pat = re.compile(
    r"lista\.sort\(\(a, b\) \{.*?\n\s*\}\);",
    re.DOTALL,
)

new_sort = """lista.sort((a, b) {
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
      });"""

m = sort_pat.search(t)
if m:
    t = t[:m.start()] + new_sort + t[m.end():]
    print("OK: ordenacao da fila atualizada")
else:
    print("AVISO: lista.sort nao encontrado — confira manualmente")

# 3) Botao Chat direto no card expandido quando pode agir
if "ChatScreen(solicitacao:" not in t and "ChatScreen(solicitacao: sol)" not in t:
    chat_btn = """
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
"""
    # Insert when podeAgir section starts
    if "else if (podeAgir) ...[" in t:
        t = t.replace(
            "else if (podeAgir) ...[",
            "else if (podeAgir) ...[\n" + chat_btn,
            1,
        )
        print("OK: botao Chat no card expandido (podeAgir)")
    elif "if (podeConfirmar)" in t:
        t = t.replace(
            "if (podeConfirmar)",
            chat_btn + "                    if (podeConfirmar)",
            1,
        )
        print("OK: botao Chat antes de confirmar")
    else:
        print("AVISO: nao inseriu botao Chat automatico")

# Also show chat in detalhe button label clearer
t = t.replace(
    "label: const Text('Detalhe / estoque / chat')",
    "label: const Text('Detalhe / estoque')",
)

# Group sort: prefer locals that have "minhas" active
# Optional enhance locais.sort - skip if complex

p.write_text(t)
print("fila_screen salva")

# ========== DETALHE: garantir Chat ==========
pd = Path("lib/screens/solicitacao_detalhe_screen.dart")
if pd.exists():
    td = pd.read_text()
    if "chat_screen.dart" not in td:
        td = "import 'chat_screen.dart';\n" + td
    if "ChatScreen(" not in td:
        btn = """
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
"""
        if "if (podeAgir)" in td:
            td = td.replace("if (podeAgir)", btn + "                  if (podeAgir)", 1)
            print("OK: Chat no detalhe")
        elif "if (podeAssumir)" in td:
            td = td.replace("if (podeAssumir)", btn + "                  if (podeAssumir)", 1)
            print("OK: Chat no detalhe (antes assumir)")
        else:
            print("AVISO: detalhe sem ancora para Chat")
    else:
        print("INFO: ChatScreen ja no detalhe")
    pd.write_text(td)

# ========== SOLICITANTE: trailing actions ==========
ps = Path("lib/screens/solicitante_screen.dart")
if ps.exists():
    ts = ps.read_text()
    if "solicitante_item_actions.dart" not in ts:
        ts = "import '../widgets/solicitante_item_actions.dart';\n" + ts
    if "SolicitanteItemActions" not in ts or ts.count("SolicitanteItemActions") < 2:
        # Try inject trailing on ListTile
        if "ListTile(" in ts and "SolicitanteItemActions(" not in ts:
            # replace first few ListTile( with trailing - risky
            # Look for Card children with title related to descricaoItem
            print("INFO: no solicitante, adicione trailing SolicitanteItemActions nos cards")
        # Soft: if there's IconButton chat already skip
    # Ensure chat only when in progress for solicitante too - widget already handles
    ps.write_text(ts)

print("Done fila/detalhe")
PY

# ========== DASHBOARD completo (só do dia + chips compactos) ==========
cat > lib/screens/dashboard_screen.dart << 'DART'
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
                    SizedBox(
                      height: 40,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
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
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 3),
                              child: FilterChip(
                                label: Text(
                                  st == 'TODOS'
                                      ? 'Todos'
                                      : AppConstantes.formatarStatus(st),
                                  style: const TextStyle(fontSize: 11),
                                ),
                                selected: _filtroStatus == st,
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4),
                                labelPadding: const EdgeInsets.symmetric(
                                    horizontal: 4),
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
DART

echo "OK: dashboard_screen.dart reescrito"
echo ""
echo "flutter analyze lib/screens/fila_screen.dart lib/screens/dashboard_screen.dart lib/screens/solicitacao_detalhe_screen.dart"
flutter analyze lib/screens/fila_screen.dart lib/screens/dashboard_screen.dart lib/screens/solicitacao_detalhe_screen.dart 2>&1 | tail -25 || true
