import 'dart:async';
import 'dart:io';

import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../ackable.dart';
import '../src/sources/websocketchannel.dart';
import 'interface.dart';

class WebSocketAckableClient extends AckableWebSocketChannel
    with AckableClient {
  @override
  final WebSocketAckableServer broadcaster;

  WebSocketAckableClient(this.broadcaster,
      WebSocketChannel wsc) : super(wsc);
}

/// A broadcaster that generates a simple websocket server through
/// [shelf\_web\_socket](https://pub.dev/packages/shelf_web_socket)
class WebSocketAckableServer<T extends AckableRoom>
    extends AckableBroadcaster<T> {
  Object _host;
  /// The IP or the InternetAddress to bind the server.
  Object get host => _host;
  /// The port to bind the host.
  final int port;
  HttpServer _server;
  StreamController<WebSocketAckableClient> _ctrlClient;
  @override
  Stream<WebSocketAckableClient> get onClient => _ctrlClient.stream;

  /// [name] is used to identify the server.
  /// [host] is the IP or the InternetAddress to bind the server.
  /// [port] is the port to bind the host.
  ///
  /// To start the server, please use [start].
  WebSocketAckableServer(String name, {Object host,
    this.port = 8080}) : super(name) {
    _host = host ?? InternetAddress.anyIPv4;
    _ctrlClient = controller();
  }

  /// Starts the websocket server.
  Future<HttpServer> start() {
    var _handler = webSocketHandler((dynamic webSocket) {
      assert(webSocket is WebSocketChannel);
      _ctrlClient.add(WebSocketAckableClient(this,
          webSocket as WebSocketChannel));
    });

    return shelf_io.serve(_handler, _host, port).then((server) {
      logger.info('Serving at ws://${server.address.host}:${server.port}');

      return _server = server;
    });
  }

  @override
  Future<void> dispose() async {
    await _server?.close();
    return super.dispose();
  }
}