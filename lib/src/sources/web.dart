import 'dart:html';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'web/datachannel.dart';
import 'web/websocket.dart';
import 'websocketchannel.dart';
import '../interface.dart';

Ackable from(Object source) {
  if (source is RtcDataChannel) {
    return AckableRtcDataChannel(source);
  } else if (source is WebSocket) {
    return AckableWebSocket(source);
  } else if (source is WebSocketChannel) {
    return AckableWebSocketChannel(source);
  }

  throw UnimplementedError('Unknown WEB source: $source');
}
