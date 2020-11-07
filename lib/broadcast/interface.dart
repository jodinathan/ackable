import 'dart:async';

import 'package:ackable/src/delegate.dart';
import 'package:dispose/dispose.dart';
import 'package:quiver/collection.dart';

import '../ackable.dart';

abstract class AckableInit {
  FutureOr<void> ackOnInit();
}

abstract class AckableBroadcaster extends AckableRoom with Disposable {
  final Map<String, AckableRoom> rooms = {};
  Stream<Ackable> get onAckable;
  StreamController<AckableClient> _ctrlClient;
  Stream<AckableClient> get onClient => _ctrlClient.stream;

  AckableClient makeClient(covariant Ackable ackable) =>
      AckableClient(this, ackable);

  AckableRoom makeRoom(String name) =>
      AckableRoom(this, name);

  AckableBroadcaster(String name) : super(null, name) {
    _ctrlClient = controller();

    each<Ackable>(onAckable, (ackable) {
      var cli = makeClient(ackable);

      add(cli);
      _ctrlClient.add(cli);
    });
  }

  @override
  Future<AckableRoom> room(String name) async {
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

class AckableRoom extends DelegatingList<AckableClient> {
  final AckableBroadcaster broadcaster;
  final List<AckableClient> _clients = <AckableClient>[];

  String _name;
  String get name => _name;

  @override
  List<AckableClient> get delegate => _clients;

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

class AckableClient extends DelegatingAckable {
  final AckableBroadcaster broadcaster;

  Future<void> join(String room) => broadcaster.room(room).then(
          (r) => r.add(this));

  Future<void> leave(String room) => broadcaster.room(room).then(
          (r) => r.remove(this));

  AckableClient(this.broadcaster, Ackable delegate)
      : super(delegate);
}