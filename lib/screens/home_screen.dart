import 'package:flutter/material.dart';
import '../services/api_client.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _status = 'Verificando conexão autenticada...';

  @override
  void initState() {
    super.initState();
    _testarConexao();
  }

  Future<void> _testarConexao() async {
    final token = await ApiClient.getToken();
    setState(() {
      _status = token != null
          ? 'Conectado ✅\nToken salvo com sucesso.'
          : 'Nenhum token encontrado ❌';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Central de Despacho')),
      body: Center(
        child: Text(_status, textAlign: TextAlign.center),
      ),
    );
  }
}