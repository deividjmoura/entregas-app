import 'solicitacao_service.dart';

class DashboardMetricas {
  final int pendentes;
  final int emCurso;
  final int entreguesHoje;
  final int canceladasHoje;
  final int totalHoje;
  final Map<String, int> porLocal;
  final Map<String, int> porUrgencia;

  DashboardMetricas({
    required this.pendentes,
    required this.emCurso,
    required this.entreguesHoje,
    required this.canceladasHoje,
    required this.totalHoje,
    required this.porLocal,
    required this.porUrgencia,
  });
}

class DashboardService {
  static bool _mesmoDia(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static Future<DashboardMetricas> carregar() async {
    final lista = await SolicitacaoService.listar();
    final agora = DateTime.now();

    int pendentes = 0;
    int emCurso = 0;
    int entreguesHoje = 0;
    int canceladasHoje = 0;
    final porLocal = <String, int>{};
    final porUrgencia = <String, int>{};

    for (final s in lista) {
      final st = s.status.toUpperCase();
      if (st == 'PENDENTE') pendentes++;
      if (st == 'EM_CURSO' || st == 'EM_ROTA' || st == 'EM_BAIXA') emCurso++;

      final ref = s.entregueEm ?? s.criadaEm;
      if (_mesmoDia(ref, agora)) {
        if (st == 'ENTREGUE') entreguesHoje++;
        if (st == 'CANCELADA') canceladasHoje++;
      }

      if (st == 'PENDENTE' ||
          st == 'EM_CURSO' ||
          st == 'EM_ROTA' ||
          st == 'EM_BAIXA') {
        final loc = s.localDestino.trim().isEmpty ? 'N/I' : s.localDestino;
        porLocal[loc] = (porLocal[loc] ?? 0) + 1;
        final urg = s.urgencia.toUpperCase();
        porUrgencia[urg] = (porUrgencia[urg] ?? 0) + 1;
      }
    }

    return DashboardMetricas(
      pendentes: pendentes,
      emCurso: emCurso,
      entreguesHoje: entreguesHoje,
      canceladasHoje: canceladasHoje,
      totalHoje: entreguesHoje + canceladasHoje,
      porLocal: porLocal,
      porUrgencia: porUrgencia,
    );
  }
}
