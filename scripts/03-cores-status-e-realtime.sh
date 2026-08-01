#!/usr/bin/env bash
set -e

echo "=== [1/3] Atualizando constantes (Cores e Labels) ==="

cat > lib/utils/constantes.dart <<'EOF'
import 'package:flutter/material.dart';

class AppConstantes {
  // Mapeamento idêntico ao URGENCIA_COR do web (domain.ts)
  static Color corUrgencia(String urgencia) {
    switch (urgencia.toUpperCase()) {
      case 'LINHA_PARADA':
        return const Color(0xFFF43F5E); // Rose 500
      case 'CRITICA':
        return const Color(0xFFF59E0B); // Amber 500
      case 'MEDIA':
        return const Color(0xFF0EA5E9); // Sky 500
      case 'BAIXA':
      default:
        return const Color(0xFF71717A); // Zinc 500
    }
  }

  // Mapeamento idêntico ao STATUS_LABELS do web
  static const Map<String, String> statusLabels = {
    'PENDENTE': 'Pendente',
    'EM_CURSO': 'Aceito',
    'EM_ROTA': 'Em rota',
    'EM_BAIXA': 'Em baixa',
    'ENTREGUE': 'Entregue',
    'CANCELADA': 'Cancelada',
  };

  // Mapeamento idêntico ao TIPO_LABELS do web
  static const Map<String, String> tipoLabels = {
    'COMPONENTE_FISICO': 'Componente',
    'CIRCUITO_ELETRONICO': 'Circuito',
    'OUTROS': 'Outros',
  };

  static String formatarStatus(String status) =>
      statusLabels[status] ?? status;

  static String formatarTipo(String tipo) =>
      tipoLabels[tipo] ?? tipo;
}
EOF

echo "=== [2/3] Atualizando Main.dart para persistência de sessão ==="

cat > lib/main.dart <<'EOF'
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/api_client.dart';
import 'screens/login_screen.dart';
import 'screens/fila_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  AuthService().init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Entregas App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _checking = true;
  bool _authenticated = false;

  @override
  void initState() {
    super.initState();
    _verificarSessao();
  }

  Future<void> _verificarSessao() async {
    final token = await ApiClient.getToken();
    final user = AuthService().currentUser.value;

    setState(() {
      _authenticated = (token != null && token.isNotEmpty && user != null);
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_authenticated) {
      return const FilaScreen();
    }

    return const LoginScreen();
  }
}
EOF

echo "=== [3/3] Atualizando FilaScreen com Polling de 5s e Visual Atualizado ==="

cat > lib/screens/fila_screen.dart <<'EOF'
import 'dart:async';
import 'package:flutter/material.dart';
import '../models/solicitacao.dart';
import '../services/solicitacao_service.dart';
import '../services/auth_service.dart';
import '../utils/constantes.dart';
import 'solicitacao_detalhe_screen.dart';
import 'login_screen.dart';

class FilaScreen extends StatefulWidget {
  const FilaScreen({super.key});

  @override
  State<FilaScreen> createState() => _FilaScreenState();
}

class _FilaScreenState extends State<FilaScreen> {
  List<Solicitacao> _solicitacoes = [];
  bool _loading = true;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _carregar();
    // Polling a cada 5 segundos para sincronizar com o backend
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) => _carregar(silent: true));
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _carregar({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    final lista = await SolicitacaoService.listar();
    if (mounted) {
      setState(() {
        _solicitacoes = lista;
        _loading = false;
      });
    }
  }

  Future<void> _logout() async {
    await AuthService().logout();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fila de Entregas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _carregar(),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _carregar(),
              child: _solicitacoes.isEmpty
                  ? const Center(child: Text('Nenhuma solicitação encontrada.'))
                  : ListView.builder(
                      itemCount: _solicitacoes.length,
                      itemBuilder: (context, index) {
                        final item = _solicitacoes[index];
                        final corUrgencia = AppConstantes.corUrgencia(item.urgencia);
                        final labelStatus = AppConstantes.formatarStatus(item.status);

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: corUrgencia,
                              radius: 8,
                            ),
                            title: Text(
                              '#${item.id.substring(0, item.id.length > 6 ? 6 : item.id.length)} - ${item.solicitanteNome}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text('Status: $labelStatus | Urgência: ${item.urgencia}'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () async {
                              final mudou = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SolicitacaoDetalheScreen(solicitacao: item),
                                ),
                              );
                              if (mudou == true) {
                                _carregar();
                              }
                            },
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
EOF

echo "✨ Parte 2 concluída com sucesso!"