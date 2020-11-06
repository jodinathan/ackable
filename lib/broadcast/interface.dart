import 'dart:async';

import 'package:ackable/src/delegate.dart';
import 'package:dispose/dispose.dart';
import 'package:quiver/collection.dart';

import '../ackable.dart';

abstract class AckableBroadcaster extends Disposable {
  final Function(AckableClient) onClient;
  final Map<String, AckableRoom> rooms = {};
  AckableRoom _defaultRoom;
  AckableRoom get defaultRoom => _defaultRoom;
  Stream<Ackable> get onAckable;

  AckableBroadcaster(this.onClient) {
    _defaultRoom = AckableRoom(this, 'default');

    disposable(_defaultRoom);

    each(onAckable, (ackable) {
      var cli = AckableClient(this, ackable);

      defaultRoom.add(cli);
      onClient(cli);
    });
  }

  AckableRoom room(String name) => rooms[name] ??= AckableRoom(this, name);

  @override
  Future<void> dispose() async {
    for (var cli in defaultRoom) {
      await cli.dispose();
    }

    return super.dispose();
  }
}

class AckableRoom extends DelegatingList<AckableClient>
    with Disposable {
  final AckableBroadcaster broadcaster;
  final List<AckableClient> _clients = <AckableClient>[];

  String _name;
  String get name => _name;

  @override
  List<AckableClient> get delegate => _clients;

  AckableRoom room(String name) =>
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

  void join(String room) => broadcaster.room(room).add(this);

  void lead(String room) => broadcaster.room(room)?.remove(this);

  AckableClient(this.broadcaster, Ackable delegate)
      : super(delegate);
}