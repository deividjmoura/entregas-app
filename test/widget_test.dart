// Teste básico de smoke: confirma que o app sobe e mostra a tela de login.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:entregas_app/main.dart';

void main() {
  testWidgets('App carrega a tela de login', (WidgetTester tester) async {
    await tester.pumpWidget(const EntregasApp());
    expect(find.text('Central de Despacho'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });
}
