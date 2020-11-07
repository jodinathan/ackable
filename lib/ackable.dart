
export 'src/message.dart';

export 'src/interface.dart';
export 'src/delegate.dart';

export 'broadcast/interface.dart';

export 'src/sources/websocketchannel.dart';

export 'src/sources/sources.dart'
if (dart.library.html) 'src/sources/web.dart'
if (dart.library.io) 'src/sources/io.dart';

const defaultTimeout = Duration(minutes: 1);
