import 'dart:async';

import 'package:ackable/json.dart';
import 'package:collection/collection.dart' show IterableExtension;
import 'package:dispose/dispose.dart';
import 'package:logging/logging.dart';

import 'message.dart';

typedef CommandFn = FutureOr Function(CommandMessage message);
typedef MessageFn = FutureOr Function(Message message);
typedef ReplyFn = Future Function(AckedMessage message);

class Reply {
  final ReplyFn? loop;
  final Object? data;
  final Map<String, Object>? headers;

  Reply(this.loop, {this.data, this.headers});
}

abstract class ProcessMessage {
  FutureOr<bool> ackProcessMessage(Message message);
}

Logger logger = Logger('Ackable');

abstract class Ackable extends Disposable implements Incoming, Outgoing {
  late StreamController<Message> _ctrlMessage;
  late StreamController<CommandMessage> _ctrlUnknown;
  final Map<int, ReplyFn> _waiting = {};
  final Map<ReplyFn, Completer> _talking = {};
  final Map<Iterable<String>, CommandFn> _many = {};
  final Map<String, MessageFn> _one = {};
  final Map<Object, Iterable<FutureOr<bool> Function()>?> middlewares = {};
  bool _initiated = false;
  int _counter = 0;
  bool allowUnknown = false;
  late bool _procMsg;
  late ProcessMessage _asProcMsg;

  Stream<Message> get onMessage => _ctrlMessage.stream;
  Stream<CommandMessage> get onUnknownMessage => _ctrlUnknown.stream;

  void forwardOnce(String subject, Ackable ackable) {
    onCommand(subject, (message) async {
      print('ForwardOnce');
      print('SUBBBB $subject! ${message.data}');

      return ackable.once(subject, message.data);
    });
  }

  void _speak(String subject, Object? data, Map<String, Object>? headers,
      ReplyFn? onAck) {
    if (onAck != null) {
      headers ??= {};

      final id = ++_counter;
      headers['id'] = id;

      _waiting[id] = onAck;
    }

    shout(subject, data, headers: headers);
  }

  Future<void> talk(
    String subject,
    Object? data,
    ReplyFn? onAck, {
    Map<String, Object>? headers,
    Duration? timeout,
  }) async {
    final cmp = Completer<void>();

    onAck ??= (msg) async => null;
    _talking[onAck] = cmp;

    _speak(subject, data, headers, onAck);

    final ret = cmp.future;

    unawaited(ret.then((ev) => _talking.remove(onAck)));

    return timeout == null ? ret : ret.timeout(timeout);
  }

  Future<Object?> once(
    String subject,
    Object? data, {
    Map<String, Object>? headers,
    Duration? timeout,
  }) async =>
      (await acked(subject, data, headers: headers, timeout: timeout))!.data;

  Future<AckedMessage?> acked(
    String subject,
    Object? data, {
    Map<String, Object>? headers,
    Duration? timeout,
  }) async {
    AckedMessage? ret;

    await talk(subject, data, (ev) async {
      ret = ev;
    }, headers: headers, timeout: timeout);

    return ret;
  }

  void _checkKey(Iterable<String> keys) {
    assert(!keys.any((cmd) => _many.keys.any((cmd2) => cmd2.contains(cmd))));

    assert(!keys.any((cmd) => _one.keys.any((cmd2) => cmd2 == cmd)));
  }

  void onCommand(String command, MessageFn exec,
      {Iterable<FutureOr<bool> Function()>? middlewares}) {
    _checkKey([command]);

    _one[command] = exec;

    this.middlewares[exec] = middlewares;
  }

  void onCommands(Iterable<String> commands, CommandFn exec,
      {Iterable<FutureOr<bool> Function()>? middlewares}) {
    _checkKey(commands);

    _many[commands] = exec;
    this.middlewares[exec] = middlewares;
  }

  void _checkReply(Object? reply, Object? id) {
    assert(
        id is int || reply == null,
        'We have reply or id is not int! id: $id ${id?.runtimeType}, '
        'reply: $reply');

    if (id is int) {
      final outHeaders = <String, Object>{'reply': id};

      if (reply is Reply && reply.loop != null) {
        if (reply.headers?.isNotEmpty == true) {
          outHeaders.addAll(reply.headers!);
        }
        _speak('_', reply.data, outHeaders, reply.loop);
      } else {
        shout('_', reply, headers: outHeaders);
      }
    } else if (reply != null) {
      logger.warning(
          'There is a reply object but the other part is not waiting for it.');
    }
  }

  void _initiate() {
    if (_initiated) {
      throw 'Can not initiate Ackable twice.';
    }

    _initiated = true;

    if (_procMsg = this is ProcessMessage) {
      _asProcMsg = this as ProcessMessage;
    }

    logger.info('Ackable initiated. is ProccessMessage: $_procMsg');

    uniqueEach(#rawMessages, onRawMessage, (ev) async {
      final h = ev['headers'];
      final headers = h is Map ? h.cast<String, Object>() : <String, Object>{};
      final data = ev['data'];
      final cmd = ev['cmd'] as String?;

      logger.info('RawMessage $cmd. headers: $headers, data: $data');

      if (cmd == '_') {
        if (headers['reply'] is int) {
          final id = headers['reply'] as int?;
          final ack = _waiting[id!];

          if (ack != null) {
            _waiting.remove(id);

            final cmp = _talking[ack];
            final msg = AckedMessage(id, data, headers: headers);

            _ctrlMessage.add(msg);

            if (_procMsg && !(await _asProcMsg.ackProcessMessage(msg))) {
              return;
            }

            final reply = await ack(msg);

            if (cmp != null) {
              if (reply is Reply && reply.loop != null) {
                _talking.remove(ack);
                _talking[reply.loop!] = cmp;
              } else {
                assert(!cmp.isCompleted);

                cmp.complete();
              }
            }

            _checkReply(reply, id);
          } else {
            logger.info('Ack fn for id $id not found');
          }
        } else {
          logger.warning('Unexpected reply command without id');
        }
      } else {
        final one = _one.keys.firstWhereOrNull((it) => it == cmd);
        final many =
            _many.keys.firstWhereOrNull((it) => it.any((str) => str == cmd));

        Future<bool> can(Object? fn) async {
          var ret = true;
          final mids = middlewares[fn!];

          if (mids?.isNotEmpty == true) {
            for (final mid in mids!) {
              if (!await mid()) {
                ret = false;
                headers['error'] = 'forbidden';
                break;
              }
            }
          }

          return ret;
        }

        final cmdMsg = CommandMessage(cmd, data, headers: headers);

        _ctrlMessage.add(cmdMsg);

        if (many != null || one != null) {
          Object? reply;

          if (many != null) {
            final fn = _many[many];

            if (await can(fn)) {
              reply = await fn!(CommandMessage(cmd, data, headers: headers));
            }
          } else {
            final fn = _one[one!];

            if (await can(fn)) {
              reply = await fn!(Message(data, headers: headers));
            }
          }

          _checkReply(reply, headers['id']);
        } else {
          if (allowUnknown) {
            //print(_one.keys);
            //print(_many.keys);
            logger.info('Couldnt find a command, so broadcasting: $cmd');
            _ctrlUnknown.add(cmdMsg);
          } else {
            throw 'Command not found: $cmd. Msg: $ev.\n'
                'Commands: ${[..._one.keys, ..._many.keys]}\n'
                'Type: $runtimeType';
          }
        }
      }
    });
  }

  Ackable() {
    _ctrlMessage = controller(broadcast: true);
    _ctrlUnknown = controller(broadcast: true);

    _initiate();
  }
}

extension AdvAckable on Ackable {
  Future<Map<String, Object>?> json(String subject, Object? data,
          {Map<String, Object>? headers, Duration? timeout}) async =>
      (await acked(subject, data, headers: headers, timeout: timeout))!.asMap();
}

Map<String, Object?> mountJson(
        String command, Object? data, Map<String, Object>? headers) =>
    {'cmd': command, 'data': data, 'headers': headers};

abstract class Outgoing {
  void shout(String subject, Object? data, {Map<String, Object>? headers});

  Object? mount(String command, Object? data, {Map<String, Object>? headers});
}

mixin OutgoingString implements Outgoing {
  @override
  String? mount(String command, Object? data, {Map<String, Object>? headers}) {
    return jsonEncode(mountJson(command, data, headers));
  }
}

mixin OutgoingDictionary implements Outgoing {
  void shoutDictionary(Map<String, dynamic> msg);

  @override
  Map<String, dynamic> mount(String command, Object? data,
      {Map<String, Object>? headers}) {
    return mountJson(command, data, headers);
  }

  @override
  void shout(String subject, Object? data, {Map<String, Object>? headers}) {
    print('ShouldOutoing $data');
    final msg = mountJson(subject, data, headers);

    shoutDictionary(msg);
  }
}

Map<String, Object>? _headers(Object? headers) {
  if (headers != null) {
    if (headers is Map) {
      if (headers is Map<String, Object>?) {
        return headers as Map<String, Object>?;
      }

      return headers.cast<String, Object>();
    }

    throw 'Unknown headers type (${headers.runtimeType}) $headers';
  }

  return null;
}

Map<String, Object> _parse(String? rawData) {
  final parsed = jsonDecode(rawData);

  return parsed is Map
      ? parsed.cast<String, Object>()
      : (throw 'Unknown data type: $parsed');
}

abstract class Incoming {
  Stream<Map<String, Object?>> get onRawMessage;
}

mixin IncomingString implements Incoming {
  Map<String, Object?> parse(String? rawData) {
    final parsed = _parse(rawData);
    final command = parsed['cmd'];

    if (command is String && command.isNotEmpty) {
      return mountJson(command, parsed['data'], _headers(parsed['headers']));
    } else {
      throw 'Unknown command $command';
    }
  }
}

mixin IncomingCommandAndData implements Incoming {
  Map<String, Object?> parse(String command, String rawData) {
    final parsed = _parse(rawData);

    return mountJson(command, parsed['data'], _headers(parsed['headers']));
  }
}

mixin FnOutgoingString implements OutgoingString {
  void Function(String?) get outgoing;

  @override
  void shout(String subject, Object? data, {Map<String, Object>? headers}) {
    final outs = mount(subject, data, headers: headers);

    logger.info('AckableStringStream Shout $subject: '
        '\nheaders: $headers\nData: $data');

    outgoing(outs);
  }
}

class AckableInStringStreamOutFnString extends Ackable
    with IncomingString, OutgoingString, FnOutgoingString {
  final Stream<String> incoming;
  @override
  final void Function(String?) outgoing;

  @override
  Stream<Map<String, Object?>> get onRawMessage =>
      incoming.map((ev) => parse(ev));

  AckableInStringStreamOutFnString(this.incoming, this.outgoing);
}

class AckableInMapStreamOutFnString extends Ackable
    with OutgoingString, FnOutgoingString
    implements Incoming {
  @override
  final void Function(String?) outgoing;
  @override
  final Stream<Map<String, Object>> onRawMessage;

  AckableInMapStreamOutFnString(this.onRawMessage, this.outgoing);
}
