import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/solicitacao_service.dart';

/// Mostra a foto de uma solicitação (busca sob demanda).
/// Só deve ser usado quando temFoto == true.
class FotoItem extends StatefulWidget {
  final String solicitacaoId;

  const FotoItem({super.key, required this.solicitacaoId});

  @override
  State<FotoItem> createState() => _FotoItemState();
}

class _FotoItemState extends State<FotoItem> {
  String? _base64;
  bool _loading = true;
  bool _erro = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final foto = await SolicitacaoService.buscarFoto(widget.solicitacaoId);
    if (!mounted) return;
    setState(() {
      _base64 = foto;
      _loading = false;
      _erro = foto == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 180,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_erro || _base64 == null) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image, size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text('Foto não disponível',
                style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      );
    }

    // Remove o prefixo data:image/...;base64, se existir
    String data = _base64!;
    if (data.contains(',')) {
      data = data.split(',').last;
    }

    try {
      final bytes = base64Decode(data);
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(
          bytes,
          fit: BoxFit.cover,
          width: double.infinity,
          height: 220,
          errorBuilder: (_, __, ___) => Container(
            height: 120,
            alignment: Alignment.center,
            child: const Text('Erro ao decodificar imagem'),
          ),
        ),
      );
    } catch (_) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        child: const Text('Erro ao processar foto'),
      );
    }
  }
}
