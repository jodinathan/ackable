import 'dart:async';
import 'dart:html' as html;
import '../base_socket.dart';
import '../../interface.dart';

class AckableRtcDataChannel extends AckableBaseSocket
    with IncomingString, OutgoingString {
  final html.RtcDataChannel channel;
  @override
  void sendString(String? buf) => channel.sendString(buf!);

  @override
  void close() => channel.close();

  @override
  Stream<Object> get onClose => channel.onClose;

  @override
  Stream<Object> get onOpen => channel.onOpen;

  @override
  bool get open => channel.readyState == 'open';

  @override
  Stream<String?> get onStringMessage => channel.onMessage.map(
          (ev) => ev.data as String?);

  AckableRtcDataChannel(this.channel);
}
