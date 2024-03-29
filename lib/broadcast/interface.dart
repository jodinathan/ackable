import 'dart:async';

import 'package:dispose/dispose.dart';
import 'package:quiver/collection.dart';

import '../ackable.dart';

abstract class AckableInit {
  FutureOr<void> ackOnInit();
}

Future<void> _initRoom(AckableRoom room) async {
  if (room is AckableInit) {
    await (room as AckableInit).ackOnInit();
  }
}

abstract class AckableBroadcaster
    extends AckableRoom with Disposable {
  Stream<AckableClient> get onClient;

  AckableBroadcaster(String name) : super(null, name);

  @override
  Future<void> dispose() async {
    for (final cli in this) {
      await cli.dispose();
    }

    return super.dispose();
  }
}

class AckableRoom<T extends AckableClient> extends DelegatingSet<T> {
  final AckableBroadcaster? caster;
  final Set<T> _clients = <T>{};
  final Map<String, AckableRoom> rooms = {};
  Set<T> get clients => _clients;

  final String _name;
  String get name => _name;

  @override
  Set<T> get delegate => _clients;

  FutureOr<AckableRoom> makeRoom(String name) =>
      AckableRoom(caster, name);

  Future<AckableRoom?> room(String name) async {
    if (!rooms.containsKey(name)) {
      final room = await makeRoom(name);

      await _initRoom(room);

      rooms[name] = room;
    }

    return rooms[name];
  }

  void shout(String subject, Object? data,
      {Map<String, Object>? headers}) {
    for (final cli in _clients) {
      cli.shout(subject, data, headers: headers);
    }
  }

  Future<void> talk(String subject,
      Object? data, {
        Future Function(AckableClient, AckedMessage)? onAck,
        Map<String, Object>? headers }) {
    final ret = _clients.map((cli) => cli.talk(subject, data, (ack) async {
      if (onAck != null) {
        return onAck(cli, ack);
      }
    }, headers: headers));

    return Future.wait(ret);
  }

  AckableRoom(this.caster, this._name) {
    print('AckableRoom $_name');
  }
}

mixin AckableClient implements Ackable {
  AckableBroadcaster get caster;

  Future<void> join(String room) => caster.room(room).then(
          (r) => r!.add(this));

  Future<void> leave(String room) => caster.room(room).then(
          (r) => r!.remove(this));
}
