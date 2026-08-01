import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificacaoService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _iniciado = false;
  static int _id = 1000;

  static Future<void> init() async {
    if (_iniciado) return;
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const settings = InitializationSettings(android: android, iOS: ios);
      await _plugin.initialize(settings);

      // Android 13+ permission
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      _iniciado = true;
    } catch (e) {
      debugPrint('NotificacaoService.init: $e');
    }
  }

  static Future<void> mostrar({
    required String titulo,
    required String corpo,
    String? payload,
  }) async {
    if (!_iniciado) await init();
    try {
      const android = AndroidNotificationDetails(
        'entregas_canal',
        'Entregas',
        channelDescription: 'Avisos de entregas e chat',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
      );
      const ios = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      const details = NotificationDetails(android: android, iOS: ios);
      await _plugin.show(
        _id++,
        titulo,
        corpo,
        details,
        payload: payload,
      );
    } catch (e) {
      debugPrint('NotificacaoService.mostrar: $e');
    }
  }

  static Future<void> novaSolicitacao(String descricao, String local) async {
    await mostrar(
      titulo: 'Nova solicitação',
      corpo: '$descricao → $local',
      payload: 'nova',
    );
  }

  static Future<void> novaMensagem(String de, String trecho) async {
    await mostrar(
      titulo: 'Mensagem de $de',
      corpo: trecho,
      payload: 'chat',
    );
  }

  static Future<void> statusAlterado(String item, String status) async {
    await mostrar(
      titulo: 'Status atualizado',
      corpo: '$item → $status',
      payload: 'status',
    );
  }
}
