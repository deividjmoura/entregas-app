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

  /// Peso para ordenação (quanto maior, mais prioritário)
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
  static const String baseUrl = 'https://entregas-teste.vercel.app'; // ajuste se for outro
  static const String apiBaseUrl = '$baseUrl/api';
}
