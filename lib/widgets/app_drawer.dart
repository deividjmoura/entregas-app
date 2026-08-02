import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/tema_provider.dart';

/// Menu lateral padrão do app — espelha o sidebar da versão web
/// (components/app-shell.tsx), reunindo as ações que antes ficavam
/// espalhadas como ícones na AppBar.
class AppDrawer extends StatelessWidget {
  final String? nomeEntregador;
  final int online;
  final VoidCallback onPainelGeral;
  final VoidCallback onModoSolicitante;
  final VoidCallback onSair;

  const AppDrawer({
    super.key,
    required this.nomeEntregador,
    required this.online,
    required this.onPainelGeral,
    required this.onModoSolicitante,
    required this.onSair,
  });

  @override
  Widget build(BuildContext context) {
    final tema = context.watch<TemaProvider>();
    final nome = (nomeEntregador != null && nomeEntregador!.isNotEmpty)
        ? nomeEntregador!
        : 'Entregador';
    final iniciais = nome.substring(0, 1).toUpperCase();
    final corPrimaria = Theme.of(context).colorScheme.primary;

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
              color: corPrimaria,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.white.withOpacity(0.18),
                    child: Text(
                      iniciais,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'ENTREGADOR',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.75),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          nome,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.circle,
                                size: 8, color: Colors.greenAccent),
                            const SizedBox(width: 5),
                            Text(
                              '$online online',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  ListTile(
                    leading: const Icon(Icons.dashboard_outlined),
                    title: const Text('Painel geral'),
                    onTap: () {
                      Navigator.of(context).pop();
                      onPainelGeral();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.assignment_ind_outlined),
                    title: const Text('Modo solicitante'),
                    onTap: () {
                      Navigator.of(context).pop();
                      onModoSolicitante();
                    },
                  ),
                  ListTile(
                    leading: Icon(tema.icone),
                    title: const Text('Alternar tema'),
                    onTap: () => tema.ciclar(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Sair', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.of(context).pop();
                onSair();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
