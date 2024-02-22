import 'dart:async';
import 'dart:html' as html;
import '../../interface.dart';
import '../base_socket.dart';

class AckableWebSocket extends AckableBaseSocket
    with IncomingString, OutgoingString {
  final html.WebSocket webSocket;

  @override
  void sendString(String? buf) => webSocket.sendString(buf!);

  @override
  void close() => webSocket.close();

  @override
  Stream<Object> get onClose => webSocket.onClose;

  @override
  Stream<Object> get onOpen => webSocket.onOpen;

  @override
  Stream<String?> get onStringMessage => webSocket.onMessage.map(
          (ev) => ev.data as String?);

  @override
  bool get isOpen => webSocket.readyState == html.WebSocket.OPEN;

  AckableWebSocket(this.webSocket);
}
