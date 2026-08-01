import 'dart:async';
import 'package:flutter/material.dart';
import '../models/solicitacao.dart';
import '../services/api_service.dart';

class SolicitacaoProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<Solicitacao> _disponiveis = [];
  List<Solicitacao> _minhas = [];
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _pollingTimer;

  List<Solicitacao> get disponiveis => _disponiveis;
  List<Solicitacao> get minhas => _minhas;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  SolicitacaoProvider() {
    iniciarPolling();
  }

  void iniciarPolling() {
    _pollingTimer?.cancel();
    // Atualiza automaticamente a cada 10 segundos
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      carregarTodas(silencioso: true);
    });
  }

  void pararPolling() {
    _pollingTimer?.cancel();
  }

  Future<void> carregarTodas({bool silencioso = false}) async {
    if (!silencioso) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final resultados = await Future.wait([
        _apiService.getSolicitacoesDisponiveis(),
        _apiService.getMinhasSolicitacoes(),
      ]);

      _disponiveis = resultados[0];
      _minhas = resultados[1];
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> assumir(String id) async {
    try {
      await _apiService.assumirSolicitacao(id);
      await carregarTodas();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> finalizar(String id) async {
    try {
      await _apiService.finalizarSolicitacao(id);
      await carregarTodas();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> cancelar(String id, String motivo) async {
    try {
      await _apiService.cancelarSolicitacao(id, motivo);
      await carregarTodas();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    pararPolling();
    super.dispose();
  }
}
