import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/constantes.dart';
import 'auth_service.dart';
import 'solicitacao_service.dart';

/// IDs de ação usados nas notificações interativas.
class NotifActions {
  static const aceitar = 'ACEITAR';
  static const responder = 'RESPONDER';
  static const abrir = 'ABRIR';
}

/// Tipos de payload embutidos no `payload` da notificação (JSON).
class NotifPayload {
  static const tipoNova = 'nova_solicitacao';
  static const tipoMensagem = 'mensagem';
}

/// Serviço de notificações locais com:
/// - canais separados (nova solicitação / mensagem)
/// - sons customizados (não são o padrão do sistema)
/// - ação "Aceitar" em novas solicitações
/// - ação "Responder" com campo de texto (RemoteInput) em mensagens
class NotificacaoService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _iniciado = false;
  static int _idSeq = 2000;

  /// Canal: novas solicitações na fila.
  static const canalNovaId = 'entregas_nova_v2';
  static const canalNovaNome = 'Novas solicitações';

  /// Canal: mensagens de chat.
  static const canalMsgId = 'entregas_msg_v2';
  static const canalMsgNome = 'Mensagens do chat';

  /// Chat atualmente aberto (evita notificar a conversa em foco).
  static String? chatAbertoId;

  // ─── init ───────────────────────────────────────────────────────────────

  static Future<void> init() async {
    if (_iniciado) return;
    try {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      await _plugin.initialize(
        const InitializationSettings(android: androidInit, iOS: iosInit),
        onDidReceiveNotificationResponse: _onResponse,
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );

      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      await androidPlugin?.requestNotificationsPermission();

      // Canais novos (v2) com sons customizados.
      // Se o canal antigo já existia no device, o som não muda — por isso IDs novos.
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          canalNovaId,
          canalNovaNome,
          description: 'Avisos de novas solicitações na fila',
          importance: Importance.high,
          playSound: true,
          sound: RawResourceAndroidNotificationSound('notif_solicitacao'),
        ),
      );
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          canalMsgId,
          canalMsgNome,
          description: 'Mensagens recebidas no chat da entrega',
          importance: Importance.high,
          playSound: true,
          sound: RawResourceAndroidNotificationSound('notif_mensagem'),
        ),
      );

      _iniciado = true;
    } catch (e, st) {
      debugPrint('NotificacaoService.init: $e\n$st');
    }
  }

  // ─── handlers de ação ────────────────────────────────────────────────────

  @pragma('vm:entry-point')
  static void notificationTapBackground(NotificationResponse response) {
    // Processa em isolate de background.
    _processarResponse(response);
  }

  static void _onResponse(NotificationResponse response) {
    _processarResponse(response);
  }

  static Future<void> _processarResponse(NotificationResponse response) async {
    try {
      final payloadRaw = response.payload;
      if (payloadRaw == null || payloadRaw.isEmpty) return;

      final Map<String, dynamic> data =
          jsonDecode(payloadRaw) as Map<String, dynamic>;
      final tipo = data['tipo']?.toString();
      final solicitacaoId = data['solicitacaoId']?.toString();
      if (solicitacaoId == null || solicitacaoId.isEmpty) return;

      final actionId = response.actionId;

      if (actionId == NotifActions.aceitar && tipo == NotifPayload.tipoNova) {
        await _acaoAceitar(solicitacaoId);
        return;
      }

      if (actionId == NotifActions.responder &&
          tipo == NotifPayload.tipoMensagem) {
        final texto = response.input?.trim();
        if (texto != null && texto.isNotEmpty) {
          await _acaoResponder(solicitacaoId, texto);
        }
        return;
      }

      // Toque simples na notificação: sem navegação profunda por enquanto
      // (FilaScreen / ChatScreen já atualizam via polling).
    } catch (e, st) {
      debugPrint('NotificacaoService._processarResponse: $e\n$st');
    }
  }

  static Future<void> _acaoAceitar(String solicitacaoId) async {
    try {
      String? nome = await AuthService().entregadorNome;
      if (nome == null || nome.isEmpty) {
        const storage = FlutterSecureStorage();
        nome = await storage.read(key: AppConstantes.storageKeyEntregadorNome);
      }
      if (nome == null || nome.isEmpty) {
        debugPrint('NotificacaoService: sem nome para aceitar');
        return;
      }
      final r = await SolicitacaoService.assumir(solicitacaoId, nome);
      debugPrint('NotificacaoService.aceitar: $r ($solicitacaoId)');
      // Feedback visual curto
      if (r == AcaoResultado.sucesso) {
        await mostrarSimples(
          titulo: 'Solicitação aceita',
          corpo: 'Você assumiu a entrega.',
        );
      } else if (r == AcaoResultado.conflito) {
        await mostrarSimples(
          titulo: 'Já foi assumida',
          corpo: 'Outro entregador pegou essa solicitação.',
        );
      }
    } catch (e) {
      debugPrint('NotificacaoService._acaoAceitar: $e');
    }
  }

  static Future<void> _acaoResponder(
    String solicitacaoId,
    String texto,
  ) async {
    try {
      String? nome = await AuthService().entregadorNome;
      if (nome == null || nome.isEmpty) {
        const storage = FlutterSecureStorage();
        nome = await storage.read(key: AppConstantes.storageKeyEntregadorNome);
      }
      if (nome == null || nome.isEmpty) return;

      await SolicitacaoService.enviarMensagem(
        solicitacaoId,
        texto,
        autorNome: nome,
      );
      debugPrint('NotificacaoService.responder: ok ($solicitacaoId)');
    } catch (e) {
      debugPrint('NotificacaoService._acaoResponder: $e');
    }
  }

  // ─── exibir ──────────────────────────────────────────────────────────────

  static Future<void> mostrarSimples({
    required String titulo,
    required String corpo,
  }) async {
    if (!_iniciado) await init();
    try {
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          canalNovaId,
          canalNovaNome,
          channelDescription: 'Avisos de entregas',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          playSound: false,
        ),
        iOS: DarwinNotificationDetails(presentSound: false),
      );
      await _plugin.show(_idSeq++, titulo, corpo, details);
    } catch (e) {
      debugPrint('NotificacaoService.mostrarSimples: $e');
    }
  }

  /// Notificação de nova solicitação com botão **Aceitar**.
  static Future<void> novaSolicitacao({
    required String solicitacaoId,
    required String descricao,
    required String local,
    String? urgencia,
  }) async {
    if (!_iniciado) await init();
    try {
      final payload = jsonEncode({
        'tipo': NotifPayload.tipoNova,
        'solicitacaoId': solicitacaoId,
      });

      final urg = (urgencia ?? '').isNotEmpty ? ' · $urgencia' : '';
      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          canalNovaId,
          canalNovaNome,
          channelDescription: 'Avisos de novas solicitações na fila',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          sound: const RawResourceAndroidNotificationSound('notif_solicitacao'),
          category: AndroidNotificationCategory.message,
          actions: <AndroidNotificationAction>[
            const AndroidNotificationAction(
              NotifActions.aceitar,
              'Aceitar',
              showsUserInterface: false,
              cancelNotification: true,
            ),
          ],
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      await _plugin.show(
        _stableId('nova_$solicitacaoId'),
        'Nova solicitação$urg',
        '$descricao → $local',
        details,
        payload: payload,
      );
    } catch (e) {
      debugPrint('NotificacaoService.novaSolicitacao: $e');
    }
  }

  /// Notificação de mensagem com campo **Responder** na barra.
  static Future<void> novaMensagem({
    required String solicitacaoId,
    required String autorNome,
    required String texto,
    String? descricaoItem,
  }) async {
    if (!_iniciado) await init();

    // Não notifica se o usuário já está no chat dessa solicitação.
    if (chatAbertoId != null && chatAbertoId == solicitacaoId) return;

    try {
      final payload = jsonEncode({
        'tipo': NotifPayload.tipoMensagem,
        'solicitacaoId': solicitacaoId,
      });

      final titulo = descricaoItem != null && descricaoItem.isNotEmpty
          ? 'Chat · $descricaoItem'
          : 'Nova mensagem';

      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          canalMsgId,
          canalMsgNome,
          channelDescription: 'Mensagens recebidas no chat da entrega',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          sound: const RawResourceAndroidNotificationSound('notif_mensagem'),
          category: AndroidNotificationCategory.message,
          actions: <AndroidNotificationAction>[
            AndroidNotificationAction(
              NotifActions.responder,
              'Responder',
              inputs: [
                const AndroidNotificationActionInput(
                  label: 'Escreva sua resposta…',
                  allowFreeFormInput: true,
                ),
              ],
              cancelNotification: true,
            ),
          ],
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      await _plugin.show(
        _stableId('msg_$solicitacaoId'),
        titulo,
        '$autorNome: $texto',
        details,
        payload: payload,
      );
    } catch (e) {
      debugPrint('NotificacaoService.novaMensagem: $e');
    }
  }

  /// ID estável por chave (evita spam de várias notificações do mesmo item).
  static int _stableId(String key) {
    return key.hashCode & 0x7fffffff;
  }
}
