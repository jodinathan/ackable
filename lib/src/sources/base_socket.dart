import 'dart:async';
import '../interface.dart';

abstract class AckableBaseSocket extends Ackable
    with IncomingString, OutgoingString {
  bool closeOnDispose = true;
  Completer<bool> _gettingReady = Completer<bool>();

  bool get isOpen;
  bool get isReady => _gettingReady.isCompleted;
  void sendString(String? buf);
  void close();
  Stream get onClose;
  Stream get onOpen;
  Stream<String?> get onStringMessage;

  @override
  void shout(String subject, Object? data, {Map<String, Object>? headers}) {
    final outs = mount(subject, data, headers: headers);

    logger.info('Shout $subject: '
        '\nheaders: $headers\nData: $data');

    _gettingReady.future.then((value) => sendString(outs));
  }

  @override
  Future<void> dispose() {
    if (closeOnDispose && isOpen) {
      close();
    }
    return super.dispose();
  }

  void _open() {
    assert(!isReady);

    _gettingReady.complete(true);
  }

  @override
  Stream<Map<String, Object?>> get onRawMessage => onStringMessage.map((ev) {
        final ret = parse(ev);

        logger.info('AckableBaseSocket ${ret['cmd']}');
        return ret;
      });

  AckableBaseSocket() {
    each(onClose, (ev) {
      if (!isReady) {
        _gettingReady.completeError(ev);
      }

      _gettingReady = Completer<bool>();
    });

    if (isOpen) {
      _open();
    } else {
      onOpen.first.then((ev) => _open());
    }
  }
}
