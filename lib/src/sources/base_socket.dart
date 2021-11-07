import 'dart:async';
import '../interface.dart';

abstract class AckableBaseSocket extends Ackable
    with IncomingString, OutgoingString {
  bool closeOnDispose = true;
  Completer<bool> ready = Completer<bool>();

  bool get open;
  void sendString(String buf);
  void close();
  Stream<Object> get onClose;
  Stream<Object> get onOpen;
  Stream<String> get onStringMessage;

  @override
  void shout(String subject, Object/*?*/ data,
      {Map<String, Object>/*?*/ headers}) {
    final outs = mount(subject, data, headers: headers);

    logger.info('Shout $subject: '
        '\nheaders: $headers\nData: $data');

    ready.future.then((value) => sendString(outs));
  }

  @override
  Future<void> dispose() {
    if (closeOnDispose && open) {
      close();
    }
    return super.dispose();
  }

  void _open() {
    assert(!ready.isCompleted);

    ready.complete(true);
  }

  @override
  Stream<Map<String, Object>> get onRawMessage => onStringMessage.map(
          (ev) {
            final ret = parse(ev);

        logger.info('AckableBaseSocket ${ret['cmd']}');
        return ret;
      });

  AckableBaseSocket(){
    each<Object>(onClose, (ev) {
      if (!ready.isCompleted) {
        ready.completeError(ev);
      }

      ready = Completer<bool>();
    });

    if (open) {
      _open();
    } else {
      onOpen.first.then((Object ev) => _open());
    }
  }
}