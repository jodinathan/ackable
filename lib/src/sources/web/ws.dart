import 'dart:async';
import 'dart:convert';
import 'package:web/web.dart' as web;
import '../../interface.dart';
import '../base_socket.dart';

class AckableWsWebSocket extends AckableBaseSocket
    with IncomingString, OutgoingString {
  AckableWsWebSocket(this.webSocket);

  factory AckableWsWebSocket.connect(
      {String host = '127.0.0.1', int port = 4040}) {
    final socket = web.WebSocket('ws://$host:$port');
    final ret = AckableWsWebSocket(socket);

    return ret;
  }

  final web.WebSocket webSocket;

  @override
  void sendString(String? buf) => webSocket.send(buf as dynamic);

  @override
  void close() => webSocket.close();

  Stream<T> _makeStream<T>(Stream event, StreamController<T>? Function() getter,
      void Function(StreamController<T>? value) setter,
      {void Function(StreamController<T> ctrl, dynamic a, dynamic b)? onData}) {
    final current = getter();
    void cancel() {
      final current = getter();

      setter(null);

      current?.close();
    }

    final fnCall = onData ??= (ctrl, a, b) => ctrl.add(a as T);

    if (current == null) {
      final value = controller<T>(onCancel: () {
        cancel();
      });

      setter(value);

      each(event, ([a, b]) {
        fnCall(value, a, b);
      });
    }

    return getter()!.stream;
  }

  StreamController? _onClose;
  @override
  Stream get onClose {
    return _makeStream(
        webSocket.onClose, () => _onClose, (value) => _onClose = value);
  }

  StreamController? _onOpen;
  @override
  Stream get onOpen =>
      _makeStream(webSocket.onOpen, () => _onOpen, (value) => _onOpen = value);

  StreamController<String?>? _onMsg;
  @override
  Stream<String?> get onStringMessage =>
      _makeStream(webSocket.onMessage, () => _onMsg, (value) => _onMsg = value,
          onData: (ctrl, data, _) {
        ctrl.add(utf8.decode(data));
      });

  @override
  bool get isOpen => webSocket.readyState == web.WebSocket.OPEN;
}
