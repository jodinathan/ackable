import 'dart:convert' as conv;

String/*?*/ Function(Object/*?*/) jsonEncode = (Object/*?*/ obj) {
  return conv.json.encode(obj, toEncodable: (obj) {
    if (obj == null) return null;
    if (obj is DateTime) return obj.toString();
    //return obj.toIso8601String();

    return obj.toString();
  });
};

Object Function(String) jsonDecode = (String buf) {
  return conv.json.decode(buf);
};