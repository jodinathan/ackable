
export 'broadcast/interface.dart';
export 'src/delegate.dart';
export 'src/interface.dart';
export 'src/message.dart';
export 'src/sources/sources.dart'
if (dart.library.html) 'src/sources/web.dart'
if (dart.library.io) 'src/sources/io.dart';
export 'src/sources/websocketchannel.dart';

/// The default timeout of ack calls.
/// This is used if the timeout argument in ack calls is not used.
const defaultTimeout = Duration(minutes: 1);
