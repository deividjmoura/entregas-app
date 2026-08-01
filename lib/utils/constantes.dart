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
