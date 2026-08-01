import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/solicitacao_service.dart';

class FotoItem extends StatefulWidget {
  final String solicitacaoId;
  final double height;

  const FotoItem({super.key, required this.solicitacaoId, this.height = 220});

  @override
  State<FotoItem> createState() => _FotoItemState();
}

class _FotoItemState extends State<FotoItem> {
  Uint8List? _bytes;
  bool _loading = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _loading = true;
      _erro = null;
    });
    try {
      final data = await SolicitacaoService.buscarFoto(widget.solicitacaoId);
      if (data == null || data.isEmpty) {
        setState(() {
          _loading = false;
          _erro = 'Sem foto';
        });
        return;
      }
      final idx = data.indexOf('base64,');
      final raw = idx >= 0 ? data.substring(idx + 7) : data;
      setState(() {
        _bytes = base64Decode(raw);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _erro = 'Erro ao carregar foto';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return SizedBox(
        height: widget.height,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_erro != null || _bytes == null) {
      return SizedBox(
        height: 48,
        child: Center(child: Text(_erro ?? 'Sem foto', style: const TextStyle(color: Colors.grey))),
      );
    }
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (_) => Dialog(
            child: InteractiveViewer(
              child: Image.memory(_bytes!, fit: BoxFit.contain),
            ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(
          _bytes!,
          height: widget.height,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
