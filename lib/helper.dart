import 'helper_stub.dart'
    if (dart.library.html) 'helper_web.dart'
    if (dart.library.io) 'helper_native.dart';

void reloadPage() {
  reloadPageImpl();
}

void enterFullscreen() {
  enterFullscreenImpl();
}

bool isFullscreen() {
  return isFullscreenImpl();
}

void exitFullscreen() {
  exitFullscreenImpl();
}
