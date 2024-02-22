import 'dart:async';

import '../ackable.dart';

abstract class DelegatingAckable
    implements Ackable {
  Ackable get delegate;

  @override
  bool get allowUnknown => delegate.allowUnknown;

  @override
  set allowUnknown(bool n) => delegate.allowUnknown = n;

  @override
  Stream<Message> get onMessage => delegate.onMessage;

  @override
  Stream<CommandMessage> get onUnknownMessage => delegate.onUnknownMessage;

  @override
  Stream<Map<String, Object?>> get onRawMessage => delegate.onRawMessage;

  @override
  void shout(String subject, Object? data,
      {Map<String, Object>? headers}) =>
      delegate.shout(subject, data, headers: headers);

  @override
  Object? mount(String command, Object? data,
      {Map<String, Object>? headers}) =>
      delegate.mount(command, data, headers: headers);

  @override
  Future<void> talk(String subject,
      Object? data,
      ReplyFn? onAck, {
        Map<String, Object>? headers,
        Duration? timeout,
      }) =>
      delegate.talk(subject, data, onAck, headers: headers,
          timeout: timeout);

  @override
  Future<Object?> once(
      String subject,
      Object? data, {
        Map<String, Object>? headers,
        Duration? timeout,
      }) => delegate.once(subject, data, headers: headers,
      timeout: timeout);

  @override
  Future<AckedMessage?> acked(
      String subject,
      Object? data, {
        Map<String, Object>? headers,
        Duration? timeout,
      }) => delegate.acked(subject, data, headers: headers,
      timeout: timeout);

  @override
  void onCommand(String command, MessageFn exec,
      {Iterable<FutureOr<bool> Function()>? middlewares}) =>
      delegate.onCommand(command, exec, middlewares: middlewares);

  @override
  void onCommands(Iterable<String> commands, CommandFn exec,
  {Iterable<FutureOr<bool> Function()>? middlewares}) =>
  delegate.onCommands(commands, exec, middlewares: middlewares);

  @override
  Map<Object, Iterable<FutureOr<bool> Function()>?> get middlewares =>
      delegate.middlewares;
}