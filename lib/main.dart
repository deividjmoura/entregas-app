import 'package:flutter/material.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const EntregasApp());
}

class EntregasApp extends StatelessWidget {
  const EntregasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Central de Despacho',
      debugShowCheckedModeBanner: false,
      home: const LoginScreen(),
    );
  }
}