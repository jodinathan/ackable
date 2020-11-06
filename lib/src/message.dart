

import 'package:ackable/json.dart';

class Message {
  final Object/*?*/ data;
  final Map<String, Object>/*?*/ headers;

  Map<String, Object> asMap() {
    var d = data;

    if (d == null) {
      return null;
    } else if (d is String) {
      return jsonDecode(d) as Map<String, Object>;
    } else if (d is Map) {
      return d.cast<String, Object>();
    }

    throw 'Unknown data type to use as map: ${d}';
  }

  const Message(this.data, {this.headers});


  @override
  String toString() => '''
    data: $data,
    headers: $headers
    ''';
}

class CommandMessage extends Message {
  final String command;

  CommandMessage(this.command, Object data,
      {Map<String, Object> headers}) :
        super(data, headers: headers);
}

class AckedMessage extends Message {
  final int id;

  AckedMessage(this.id, Object data,
      {Map<String, Object> headers}) :
        super(data, headers: headers);
}

