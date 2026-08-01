import 'package:flutter/material.dart';

/// Status possíveis de uma solicitação, na ordem em que aparecem no fluxo.
/// TODO: conferir com o backend se existem outros status além destes
/// (ex: ENTREGUE, CANCELADA) e completar a lista.
const statusDisponiveis = ['PENDENTE', 'EM_ROTA', 'EM_CURSO', 'EM_BAIXA'];

/// Valores válidos de urgência — espelha URGENCIAS_VALIDAS em
/// app/api/solicitacoes/[id]/route.ts no backend (entregas-teste).
const urgenciasValidas = ['BAIXA', 'MEDIA', 'CRITICA', 'LINHA_PARADA'];

/// Labels de exibição em português.
/// TODO: conferir se batem com URGENCIA_LABELS em lib/domain.ts no backend
/// (não conferido ainda — ajustar aqui se o texto do web for diferente).
const urgenciaLabels = {
  'BAIXA': 'Baixa',
  'MEDIA': 'Média',
  'CRITICA': 'Crítica',
  'LINHA_PARADA': 'Linha Parada',
};

/// Cor associada a cada nível de urgência.
/// TODO: conferir se bate com URGENCIA_COR em lib/domain.ts no backend
/// (mantido igual ao que já existia em fila_screen.dart).
Color corUrgencia(String urgencia) {
  switch (urgencia) {
    case 'CRITICA':
    case 'LINHA_PARADA':
      return Colors.red;
    case 'MEDIA':
      return Colors.orange;
    default:
      return Colors.green;
  }
}
