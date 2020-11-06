import 'package:web_socket_channel/web_socket_channel.dart';

import 'websocketchannel.dart';
import '../interface.dart';

Ackable from(Object source) {
  if (source is WebSocketChannel) {
    return AckableWebSocketChannel(source);
  }

  throw UnimplementedError('Unknown IO source: $source');
}
