import 'package:logging/logging.dart';

final log = Logger('non web specific');

void reloadPageImpl() {
  log.warning('Reloading is not supported on this platform.');
}
