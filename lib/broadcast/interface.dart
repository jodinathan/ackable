import 'dart:async';

import 'package:ackable/src/delegate.dart';
import 'package:dispose/dispose.dart';
import 'package:quiver/collection.dart';

import '../ackable.dart';

abstract class AckableInit {
  FutureOr<void> ackOnInit();
}

abstract class AckableBroadcaster<T extends AckableRoom>
    extends AckableRoom with Disposable {
  final Map<String, T> rooms = {};
  Stream<AckableClient> get onClient;

  T makeRoom(String name) => AckableRoom(this, name) as T;

  AckableBroadcaster(String name) : super(null, name);

  @override
  Future<T> room(String name) async {
    if (!rooms.containsKey(name)) {
      final room = makeRoom(name);

      if (room is AckableInit) {
        await (room as AckableInit).ackOnInit();
      }

      rooms[name] = room;
    }

    return rooms[name];
  }

  @override
  Future<void> dispose() async {
    for (var cli in this) {
      await cli.dispose();
    }

    return super.dispose();
  }
}

class AckableRoom<T extends AckableClient> extends DelegatingSet<T> {
  final AckableBroadcaster broadcaster;
  final Set<T> _clients = <T>{};
  Set<T> get clients => _clients;

  String _name;
  String get name => _name;

  @override
  Set<T> get delegate => _clients;

  Future<AckableRoom> room(String name) =>
      broadcaster.room('${this.name}.$name');

  void shout(String subject, Object /*?*/ data,
      {Map<String, Object> /*?*/ headers}) {
    for (var cli in _clients) {
      cli.shout(subject, data, headers: headers);
    }
  }

  Future<void> talk(String subject,
      Object /*?*/ data, {
        FutureOr Function(AckableClient, AckedMessage) onAck,
        Map<String, Object> /*?*/ headers }) {
    var ret = _clients.map((cli) => cli.talk(subject, data, (ack) {
      if (onAck != null) {
        return onAck(cli, ack);
      }
    }, headers: headers));

    return Future.wait(ret);
  }

  AckableRoom(this.broadcaster, String name);
}

abstract class AckableClient implements Ackable {
  AckableBroadcaster get broadcaster;

  Future<void> join(String room) => broadcaster.room(room).then(
          (r) => r.add(this));

  Future<void> leave(String room) => broadcaster.room(room).then(
          (r) => r.remove(this));
}