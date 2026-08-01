import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';
import '../models/solicitacao.dart';

class PusherService {
  static final PusherChannelsFlutter _pusher = PusherChannelsFlutter.getInstance();
  static bool _iniciado = false;

  // pusher_channels_flutter só tem implementação nativa pra Android, iOS,
  // Web e macOS. Em outras plataformas (ex: Linux desktop) isso lança
  // MissingPluginException — por isso o try/catch abaixo, pra não derrubar
  // o app inteiro. Nessas plataformas o real-time simplesmente fica
  // desativado; a fila continua funcionando via REST + pull-to-refresh.
  static Future<void> conectar({
    required void Function(Solicitacao) onNovaEntrega,
  }) async {
    if (_iniciado) return;

    try {
      await _pusher.init(
        apiKey: "ca0c59bac023ae560131",
        cluster: "sa1",
      );

      await _pusher.subscribe(
        channelName: "painel-entregas",
        onEvent: (event) {
          if (event.eventName == "nova-entrega" && event.data != null) {
            final Map<String, dynamic> json = jsonDecode(event.data!);
            onNovaEntrega(Solicitacao.fromJson(json));
          }
        },
      );

      await _pusher.connect();
      _iniciado = true;
    } catch (e) {
      debugPrint('PusherService: real-time indisponível nesta plataforma ($e)');
    }
  }

  static Future<void> desconectar() async {
    if (!_iniciado) return;
    try {
      await _pusher.disconnect();
    } catch (_) {
      // ignora erro de desconexão em plataforma sem suporte
    }
    _iniciado = false;
  }
}
