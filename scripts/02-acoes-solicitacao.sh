#!/usr/bin/env bash
set -e

echo "=== [1/2] Atualizando SolicitacaoService ==="

cat > lib/services/solicitacao_service.dart <<'EOF'
import 'dart:convert';
import '../models/solicitacao.dart';
import 'api_client.dart';

enum AcaoResultado { sucesso, jaAssumido, conflitoStatus, erro }

class SolicitacaoService {
  static Future<List<Solicitacao>> listar() async {
    final res = await ApiClient.get('/api/solicitacoes');
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((json) => Solicitacao.fromJson(json)).toList();
    }
    return [];
  }

  static Future<AcaoResultado> assumir(String id, String entregadorNome) async {
    final res = await ApiClient.post('/api/solicitacoes/$id/assumir', {
      'entregadorNome': entregadorNome,
    });

    if (res.statusCode == 200) return AcaoResultado.sucesso;
    if (res.statusCode == 409) return AcaoResultado.jaAssumido;
    return AcaoResultado.erro;
  }

  static Future<bool> atualizarStatusEmRotaOuBaixa(String id, String novoStatus) async {
    if (novoStatus != 'EM_ROTA' && novoStatus != 'EM_BAIXA') {
      return false;
    }
    final res = await ApiClient.patch('/api/solicitacoes/$id', {'status': novoStatus});
    return res.statusCode == 200;
  }

  static Future<AcaoResultado> confirmar(String id) async {
    final res = await ApiClient.post('/api/solicitacoes/$id/confirmar', {});
    if (res.statusCode == 200) return AcaoResultado.sucesso;
    if (res.statusCode == 409) return AcaoResultado.conflitoStatus;
    return AcaoResultado.erro;
  }

  static Future<bool> cancelar(String id) async {
    final res = await ApiClient.delete('/api/solicitacoes/$id');
    return res.statusCode == 200;
  }

  static Future<bool> toggleFavorito(String id, bool favorito) async {
    final res = await ApiClient.patch('/api/solicitacoes/$id', {'favorito': favorito});
    return res.statusCode == 200;
  }
}
EOF

echo "=== [2/2] Atualizando Telas (Fila e Detalhe) com Botões Contextuais ==="

cat > lib/screens/solicitacao_detalhe_screen.dart <<'EOF'
import 'package:flutter/material.dart';
import '../models/solicitacao.dart';
import '../services/solicitacao_service.dart';
import '../services/auth_service.dart';

class SolicitacaoDetalheScreen extends StatefulWidget {
  final Solicitacao solicitacao;

  const SolicitacaoDetalheScreen({super.key, required this.solicitacao});

  @override
  State<SolicitacaoDetalheScreen> createState() => _SolicitacaoDetalheScreenState();
}

class _SolicitacaoDetalheScreenState extends State<SolicitacaoDetalheScreen> {
  late Solicitacao _item;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _item = widget.solicitacao;
  }

  void _mostrarMensagem(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _assumir() async {
    final nome = AuthService().entregadorNome;
    if (nome.isEmpty) {
      _mostrarMensagem('Usuário não autenticado.');
      return;
    }

    setState(() => _loading = true);
    final res = await SolicitacaoService.assumir(_item.id, nome);
    setState(() => _loading = false);

    if (res == AcaoResultado.sucesso) {
      _mostrarMensagem('Solicitação assumida com sucesso!');
      Navigator.pop(context, true);
    } else if (res == AcaoResultado.jaAssumido) {
      _mostrarMensagem('Erro: Esta solicitação já foi assumida por outro entregador.');
    } else {
      _mostrarMensagem('Erro ao assumir solicitação.');
    }
  }

  Future<void> _mudarStatus(String status) async {
    setState(() => _loading = true);
    final ok = await SolicitacaoService.atualizarStatusEmRotaOuBaixa(_item.id, status);
    setState(() => _loading = false);

    if (ok) {
      _mostrarMensagem('Status alterado para $status.');
      Navigator.pop(context, true);
    } else {
      _mostrarMensagem('Erro ao atualizar status.');
    }
  }

  Future<void> _confirmarEntrega() async {
    setState(() => _loading = true);
    final res = await SolicitacaoService.confirmar(_item.id);
    setState(() => _loading = false);

    if (res == AcaoResultado.sucesso) {
      _mostrarMensagem('Entrega confirmada com sucesso!');
      Navigator.pop(context, true);
    } else {
      _mostrarMensagem('Erro ao confirmar entrega.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuarioAtual = AuthService().entregadorNome;
    final eDoUsuario = _item.entregadorNome == usuarioAtual;

    return Scaffold(
      appBar: AppBar(title: Text('Solicitação #${_item.id.substring(0, 6)}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Solicitante: ${_item.solicitanteNome}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Status: ${_item.status}', style: const TextStyle(fontSize: 16)),
                  Text('Entregador: ${_item.entregadorNome ?? "Nenhum"}'),
                  Text('Urgência: ${_item.urgencia}'),
                  Text('Tipo: ${_item.tipo}'),
                  Text('Descrição: ${_item.descricao}'),
                  const Spacer(),
                  if (_item.status == 'PENDENTE') ...[
                    ElevatedButton(
                      onPressed: _assumir,
                      style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                      child: const Text('Aceitar Solicitação'),
                    ),
                  ] else if (eDoUsuario && (_item.status == 'EM_CURSO' || _item.status == 'EM_ROTA' || _item.status == 'EM_BAIXA')) ...[
                    if (_item.status == 'EM_CURSO' || _item.status == 'EM_BAIXA')
                      ElevatedButton(
                        onPressed: () => _mudarStatus('EM_ROTA'),
                        style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                        child: const Text('Marcar EM ROTA'),
                      ),
                    const SizedBox(height: 8),
                    if (_item.status == 'EM_CURSO' || _item.status == 'EM_ROTA')
                      ElevatedButton(
                        onPressed: () => _mudarStatus('EM_BAIXA'),
                        style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                        child: const Text('Marcar EM BAIXA'),
                      ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _item.status == 'EM_ROTA' ? _confirmarEntrega : null,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        backgroundColor: Colors.green,
                      ),
                      child: const Text('Confirmar Entrega', style: TextStyle(color: Colors.white)),
                    ),
                  ] else ...[
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(12.0),
                        child: Text('Esta entrega pertence a outro entregador ou já foi concluída.'),
                      ),
                    )
                  ],
                ],
              ),
            ),
    );
  }
}
EOF

echo "✨ Tarefa 1.2 concluída com sucesso!"