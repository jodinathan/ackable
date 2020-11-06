import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../interface.dart';

class AckableWebSocketChannel extends Ackable
    with IncomingString, OutgoingString {
  final WebSocketChannel _channel;
  bool closeOnDispose = true;

  @override
  Stream<Map<String, Object>> get onRawMessage => _channel.stream.map(
          (ev) {
        var ret = parse(ev);

        logger.info('AckableWebSocketChannel ${ret['cmd']}');
        return ret;
      });

  @override
  void shout(String subject, Object/*?*/ data,
      {Map<String, Object>/*?*/ headers}) {
    var outs = mount(subject, data, headers: headers);

    logger.info('Shout $subject: '
        '\nheaders: $headers\nData: $data');

    _channel.sink.add(outs);
  }

  @override
  Future<void> dispose() {
    if (closeOnDispose) {
      _channel.sink.close();
    }

    return super.dispose();
  }

  AckableWebSocketChannel(this._channel);
}