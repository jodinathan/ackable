import 'dart:async';
import 'dart:io';

import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../ackable.dart';
import '../src/sources/websocketchannel.dart';
import 'interface.dart';

class WebSocketAckableServer extends AckableBroadcaster {
  final String host;
  final int port;
  HttpServer _server;
  StreamController<Ackable> _ctrlAckable;
  @override
  Stream<Ackable> get onAckable {
    _ctrlAckable ??= controller();

    return _ctrlAckable.stream;
  }

  WebSocketAckableServer(Function(AckableClient) onClient,
      {this.host = 'localhost', this.port = 8080}) :
        super(onClient) {
    var _handler = webSocketHandler((WebSocketChannel webSocket) {
      _ctrlAckable.add(AckableWebSocketChannel(webSocket));
    });

    shelf_io.serve(_handler, host, port).then((server) {
      logger.info('Serving at ws://${server.address.host}:${server.port}');
    }).then((ev) => _server = ev);
  }

  @override
  Future<void> dispose() async {
    await _server?.close();
    return super.dispose();
  }
}