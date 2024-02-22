import 'dart:async';
import 'dart:convert';
import 'package:typings/d/ws.dart' as ws;
import '../../interface.dart';
import '../base_socket.dart';

class AckableWsWebSocket extends AckableBaseSocket
    with IncomingString, OutgoingString {
  AckableWsWebSocket(this.webSocket);

  factory AckableWsWebSocket.connect(
      {String host = '127.0.0.1', int port = 4040}) {
    final socket = ws.WebSocket('ws://$host:$port');
    final ret = AckableWsWebSocket(socket);

    return ret;
  }

  final ws.WebSocket webSocket;

  @override
  void sendString(String? buf) => webSocket.send(buf!);

  @override
  void close() => webSocket.destroy();

  Stream<T> _makeStream<T>(String event, StreamController<T>? Function() getter,
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

      webSocket.on(event, ([a, b]) {
        fnCall(value, a, b);
      });
    }

    return getter()!.stream;
  }

  StreamController? _onClose;
  @override
  Stream get onClose {
    return _makeStream('close', () => _onClose, (value) => _onClose = value);
  }

  StreamController? _onOpen;
  @override
  Stream get onOpen =>
      _makeStream('open', () => _onOpen, (value) => _onOpen = value);

  StreamController<String?>? _onMsg;
  @override
  Stream<String?> get onStringMessage =>
      _makeStream('message', () => _onMsg, (value) => _onMsg = value,
          onData: (ctrl, data, _) {
        ctrl.add(utf8.decode(data));
      });

  @override
  bool get isOpen => webSocket.readyState == ws.WebSocketReadyState.open;
}
