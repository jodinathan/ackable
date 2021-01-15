import 'dart:async';
import 'dart:io';

import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../ackable.dart';
import '../src/sources/websocketchannel.dart';
import 'interface.dart';

class WebSocketAckableClient extends AckableWebSocketChannel
    with AckableClient {
  @override
  final BaseWebSocketAckableServer broadcaster;

  WebSocketAckableClient(this.broadcaster,
      WebSocketChannel wsc) : super(wsc);
}

class WebSocketAckableServer
    extends BaseWebSocketAckableServer<WebSocketAckableClient,
        AckableRoom<WebSocketAckableClient>> {
  @override
  FutureOr<AckableRoom<WebSocketAckableClient>> makeRoom(String name)
      => AckableRoom<WebSocketAckableClient>(this, name);

  @override
  FutureOr<WebSocketAckableClient> makeClient(WebSocketChannel wsc) =>
      WebSocketAckableClient(this, wsc);

  WebSocketAckableServer(String name, {Object host,
    int port}) : super(name, host: host, port: port);
}


/// A broadcaster that generates a simple websocket server through
/// [shelf\_web\_socket](https://pub.dev/packages/shelf_web_socket)
abstract class BaseWebSocketAckableServer
      <C extends WebSocketAckableClient, T extends AckableRoom<C>>
    extends AckableBroadcaster {
  Object _host;
  /// The IP or the InternetAddress to bind the server.
  Object get host => _host;
  /// The port to bind the host.
  final int port;
  HttpServer _server;
  StreamController<C> _ctrlClient;
  @override
  Stream<C> get onClient => _ctrlClient.stream;

  /// [name] is used to identify the server.
  /// [host] is the IP or the InternetAddress to bind the server.
  /// [port] is the port to bind the host.
  ///
  /// To start the server, please use [start].
  BaseWebSocketAckableServer(String name, {Object host,
    this.port = 8080}) : super(name) {
    _host = host ?? InternetAddress.anyIPv4;
    _ctrlClient = controller();
  }

  FutureOr<C> makeClient(WebSocketChannel wsc);

  FutureOr<bool> checkHeart() => true;

  /// Starts the websocket server.
  Future<HttpServer> start() {
    var _handler = webSocketHandler((dynamic webSocket) async {
      assert(webSocket is WebSocketChannel);
      var cli = await makeClient(webSocket as WebSocketChannel);

      add(cli);
      _ctrlClient.add(cli);
    });

    return shelf_io.serve((shelf.Request sock) async {
      if (sock.url.path == 'heartbeat') {
        return shelf.Response(await checkHeart() ? 200 : 500);
      }

      return _handler(sock);
    }, _host, port).then((server) {
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