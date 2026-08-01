import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/solicitacao_provider.dart';
import '../widgets/solicitacao_card.dart';
import '../services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<SolicitacaoProvider>(context, listen: false).carregarTodas();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SolicitacaoProvider>(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Painel de Entregas'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => provider.carregarTodas(),
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await AuthService().signOut();
                if (context.mounted) {
                  Navigator.of(context).pushReplacementNamed('/login');
                }
              },
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.list_alt), text: 'Disponíveis'),
              Tab(icon: Icon(Icons.directions_run), text: 'Minhas Entregas'),
            ],
          ),
        ),
        body: provider.isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildList(provider.disponiveis, 'Nenhuma entrega disponível no momento.'),
                  _buildList(provider.minhas, 'Você não possui entregas em andamento.'),
                ],
              ),
      ),
    );
  }

  Widget _buildList(List solicitacoes, String emptyMessage) {
    if (solicitacoes.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => Provider.of<SolicitacaoProvider>(context, listen: false).carregarTodas(),
      child: ListView.builder(
        itemCount: solicitacoes.length,
        itemBuilder: (ctx, i) => SolicitacaoCard(solicitacao: solicitacoes[i]),
      ),
    );
  }
}
