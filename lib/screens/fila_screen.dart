import 'solicitante_screen.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../models/solicitacao.dart';
import '../services/solicitacao_service.dart';
import '../services/auth_service.dart';
import '../utils/constantes.dart';
import 'login_screen.dart';
import 'solicitacao_detalhe_screen.dart'; // ajuste o nome se o seu arquivo for diferente

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

  @override
  void initState() {
    super.initState();
    _carregarDados();
    // Atualiza a fila a cada 8 segundos (igual ao polling do web)
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _carregarDados(silent: true);
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _carregarDados({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);

    try {
      final nome = await AuthService().getEntregadorNome();
      final lista = await SolicitacaoService.listar();

      // Ordena por urgência (maior peso primeiro) e depois por data de criação
      lista.sort((a, b) {
        final pesoA = AppConstantes.pesoUrgencia(a.urgencia);
        final pesoB = AppConstantes.pesoUrgencia(b.urgencia);
        if (pesoA != pesoB) return pesoB.compareTo(pesoA);
        return a.criadaEm.compareTo(b.criadaEm);
      });

      if (mounted) {
        setState(() {
          _nomeEntregador = nome;
          _solicitacoes = lista;
          _isLoading = false;
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

  /// Agrupa as solicitações por local de destino
  Map<String, List<Solicitacao>> _agruparPorLocal(List<Solicitacao> lista) {
    final Map<String, List<Solicitacao>> grupos = {};
    for (final s in lista) {
      final local = s.localDestino;
      grupos.putIfAbsent(local, () => []).add(s);
    }
    return grupos;
  }

  @override
  Widget build(BuildContext context) {
    final grupos = _agruparPorLocal(_solicitacoes);
    final locais = grupos.keys.toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _nomeEntregador != null
              ? 'Fila · $_nomeEntregador'
              : 'Fila de Entregas',
        ),
        actions: [
                    IconButton(
            icon: const Icon(Icons.assignment_ind_outlined),
            tooltip: 'Modo solicitante',
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const SolicitanteScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _carregarDados(),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Sair',
          ),
        ],
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
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: locais.length,
                      itemBuilder: (context, index) {
                        final local = locais[index];
                        final items = grupos[local]!;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Cabeçalho do grupo (local)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                              child: Row(
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
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '(${items.length})',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Cards das solicitações deste local
                            ...items.map((sol) => _buildCard(sol)),
                          ],
                        );
                      },
                    ),
            ),
    );
  }

  Widget _buildCard(Solicitacao sol) {
    final corUrgencia = AppConstantes.corUrgencia(sol.urgencia);
    final labelUrgencia = AppConstantes.formatarUrgencia(sol.urgencia);
    final labelStatus = AppConstantes.formatarStatus(sol.status);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SolicitacaoDetalheScreen(
                solicitacao: sol,
                onUpdated: () => _carregarDados(silent: true),
              ),
            ),
          );
          _carregarDados(silent: true);
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Linha 1: urgência + status + timer
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: corUrgencia,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      labelUrgencia,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppConstantes.corStatus(sol.status).withOpacity(0.15),
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
                  Icon(Icons.timer_outlined, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 3),
                  Text(
                    sol.tempoEsperaFormatado,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Descrição do item
              Text(
                sol.descricaoItem,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 6),

              // Rack / Slide + Solicitante
              Row(
                children: [
                  if (sol.rackOuSlide != null && sol.rackOuSlide!.isNotEmpty) ...[
                    Icon(Icons.view_module, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 3),
                    Text(
                      sol.rackOuSlide!,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Icon(Icons.person_outline, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      sol.solicitanteNome,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              // Entregador (se já tiver)
              if (sol.entregadorNome != null && sol.entregadorNome!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.delivery_dining, size: 14, color: Colors.blue.shade600),
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
    );
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