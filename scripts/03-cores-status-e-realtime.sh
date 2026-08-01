#!/bin/bash
# scripts/03-cores-status-e-realtime.sh
# Parte 2 — Cores de urgência, labels e tempo real (polling)
# Rode DEPOIS dos scripts 01 e 02
# Na raiz do projeto: ~/entregas_app
set -e

echo "=============================================="
echo "  03 - Cores + Labels + Polling + Sessão"
echo "=============================================="
echo ""

# ============================================================
# 1. Atualiza lib/utils/constantes.dart (cores oficiais do web)
# ============================================================
echo "→ Atualizando lib/utils/constantes.dart..."

cat > lib/utils/constantes.dart <<'EOF'
import 'package:flutter/material.dart';

class AppConstantes {
  // ===================== STORAGE KEYS =====================
  static const String storageKeyToken = 'token';
  static const String storageKeyEntregadorNome = 'entregador_nome';
  static const String storageKeyCodigoAcesso = 'codigo_acesso_empresa';

  // ===================== STATUS =====================
  static const String statusPendente = 'PENDENTE';
  static const String statusEmCurso = 'EM_CURSO';
  static const String statusEmRota = 'EM_ROTA';
  static const String statusEmBaixa = 'EM_BAIXA';
  static const String statusEntregue = 'ENTREGUE';
  static const String statusCancelada = 'CANCELADA';

  /// Labels iguais ao web (STATUS_LABELS)
  static const Map<String, String> statusLabels = {
    'PENDENTE': 'Pendente',
    'EM_CURSO': 'Aceito',
    'EM_ROTA': 'Em rota',
    'EM_BAIXA': 'Em baixa',
    'ENTREGUE': 'Entregue',
    'CANCELADA': 'Cancelada',
  };

  static String formatarStatus(String? status) {
    if (status == null) return 'Desconhecido';
    return statusLabels[status.toUpperCase()] ?? status;
  }

  static Color corStatus(String? status) {
    switch ((status ?? '').toUpperCase()) {
      case 'PENDENTE':
        return Colors.orange;
      case 'EM_CURSO':
        return Colors.blue;
      case 'EM_ROTA':
        return Colors.purple;
      case 'EM_BAIXA':
        return Colors.indigo;
      case 'ENTREGUE':
        return Colors.green;
      case 'CANCELADA':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // ===================== URGÊNCIA =====================
  // Cores oficiais do web (URGENCIA_COR em lib/domain.ts)
  static const String urgenciaBaixa = 'BAIXA';
  static const String urgenciaMedia = 'MEDIA';
  static const String urgenciaCritica = 'CRITICA';
  static const String urgenciaLinhaParada = 'LINHA_PARADA';

  static const Map<String, String> urgenciaLabels = {
    'BAIXA': 'Baixa',
    'MEDIA': 'Média',
    'CRITICA': 'Crítica',
    'LINHA_PARADA': 'Linha parada',
  };

  /// Peso para ordenação (maior = mais prioritário)
  static const Map<String, int> urgenciaPeso = {
    'LINHA_PARADA': 10,
    'CRITICA': 3,
    'MEDIA': 2,
    'BAIXA': 1,
  };

  static String formatarUrgencia(String? urgencia) {
    if (urgencia == null) return 'Baixa';
    return urgenciaLabels[urgencia.toUpperCase()] ?? urgencia;
  }

  /// Cores oficiais do web:
  /// LINHA_PARADA → Rose 500
  /// CRITICA      → Amber 500
  /// MEDIA        → Sky 500
  /// BAIXA        → Zinc 500
  static Color corUrgencia(String? urgencia) {
    switch ((urgencia ?? '').toUpperCase()) {
      case 'LINHA_PARADA':
        return const Color(0xFFF43F5E); // Rose 500
      case 'CRITICA':
        return const Color(0xFFF59E0B); // Amber 500
      case 'MEDIA':
        return const Color(0xFF0EA5E9); // Sky 500
      case 'BAIXA':
        return const Color(0xFF71717A); // Zinc 500
      default:
        return Colors.grey;
    }
  }

  static int pesoUrgencia(String? urgencia) {
    return urgenciaPeso[(urgencia ?? 'BAIXA').toUpperCase()] ?? 1;
  }

  // ===================== TIPO =====================
  static const Map<String, String> tipoLabels = {
    'COMPONENTE_FISICO': 'Componente',
    'CIRCUITO_ELETRONICO': 'Circuito',
    'OUTROS': 'Outros',
  };

  static String formatarTipo(String? tipo) {
    if (tipo == null) return 'Outros';
    return tipoLabels[tipo.toUpperCase()] ?? tipo;
  }

  // ===================== API =====================
  static const String baseUrl = 'https://entregas-teste.vercel.app';
  static const String apiBaseUrl = '$baseUrl/api';
}
EOF

echo "  ✓ constantes.dart atualizado (cores oficiais do web)"

# ============================================================
# 2. Garante polling de 5 segundos em fila_screen.dart
# ============================================================
echo "→ Ajustando polling em fila_screen.dart (5 segundos)..."

if grep -q "Timer.periodic" lib/screens/fila_screen.dart 2>/dev/null; then
  sed -i 's/Duration(seconds: [0-9]\+)/Duration(seconds: 5)/g' lib/screens/fila_screen.dart
  echo "  ✓ intervalo de polling ajustado para 5 segundos"
else
  echo "  ⚠ fila_screen.dart não tem Timer.periodic ainda."
  echo "    Verifique manualmente se o polling está ativo."
fi

# ============================================================
# 3. Garante que main.dart e AuthGate estão corretos
# ============================================================
echo "→ Verificando main.dart e AuthGate..."

cat > lib/main.dart <<'EOF'
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'widgets/auth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Entregas App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}
EOF

echo "  ✓ main.dart confirmado"

mkdir -p lib/widgets

cat > lib/widgets/auth_gate.dart <<'EOF'
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/auth_service.dart';
import '../utils/constantes.dart';
import '../screens/login_screen.dart';
import '../screens/fila_screen.dart';

/// Decide a tela inicial:
/// - Tem código de acesso + identidade → FilaScreen
/// - Caso contrário → LoginScreen
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isLoading = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    const storage = FlutterSecureStorage();
    final authService = AuthService();

    final codigo =
        await storage.read(key: AppConstantes.storageKeyCodigoAcesso);
    final nome = await authService.entregadorNome;
    final user = authService.currentUser;

    final temCodigo = codigo != null && codigo.isNotEmpty;
    final temIdentificacao =
        (nome != null && nome.isNotEmpty) || user != null;

    if (mounted) {
      setState(() {
        _isAuthenticated = temCodigo && temIdentificacao;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_isAuthenticated) {
      return const FilaScreen();
    }

    return const LoginScreen();
  }
}
EOF

echo "  ✓ auth_gate.dart confirmado (sessão persistente)"

echo ""
echo "=============================================="
echo "✅ Parte 2 concluída com sucesso!"
echo "=============================================="
echo ""
echo "O que foi feito:"
echo "  • Cores de urgência alinhadas com o web (Rose/Amber/Sky/Zinc)"
echo "  • Labels de status e tipo iguais ao web"
echo "  • Polling de 5 segundos na fila (igual ao web)"
echo "  • Sessão persiste entre aberturas do app (AuthGate)"
echo ""
echo "Próximos passos (opcional - backlog):"
echo "  • foto, chat, presença (peça se precisar)"
echo ""
echo "Agora rode:"
echo "  flutter clean"
echo "  flutter pub get"
echo "  flutter run"
echo ""
