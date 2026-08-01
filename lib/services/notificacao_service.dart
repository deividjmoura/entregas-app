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
      const ios = DarwinInitializationSettings();
      await _plugin.initialize(
        const InitializationSettings(android: android, iOS: ios),
      );
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
  }) async {
    if (!_iniciado) await init();
    try {
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'entregas_canal',
          'Entregas',
          channelDescription: 'Avisos de entregas',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      );
      await _plugin.show(_id++, titulo, corpo, details);
    } catch (e) {
      debugPrint('NotificacaoService.mostrar: $e');
    }
  }

  static Future<void> novaSolicitacao(String desc, String local) async {
    await mostrar(titulo: 'Nova solicitação', corpo: '$desc → $local');
  }
}
