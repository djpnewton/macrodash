import 'package:logging/logging.dart';

final log = Logger('non web specific');

void reloadPageImpl() {
  log.warning('Reloading is not supported on this platform.');
}

void enterFullscreenImpl() {
  log.warning('Fullscreen is not supported on this platform.');
}

bool isFullscreenImpl() {
  log.warning('Fullscreen is not supported on this platform.');
  return false;
}

void exitFullscreenImpl() {
  log.warning('Exiting fullscreen is not supported on this platform.');
}
