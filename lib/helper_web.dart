import 'dart:js_interop';

import 'package:web/web.dart' as web;
import 'package:logging/logging.dart';

final log = Logger('helper_web');

void reloadPageImpl() {
  web.window.location.reload(); // Reload the web page
}

void enterFullscreenImpl() {
  log.info('Attempting to enter fullscreen mode...');

  if (web.document.documentElement == null) {
    log.warning('Document element is null, cannot enter fullscreen.');
    return;
  }
  final promise = web.document.documentElement!.requestFullscreen();
  promise.toDart
      .then((value) {
        log.info('Entered fullscreen mode successfully.');
      })
      .onError((error, stackTrace) {
        log.warning('Failed to enter fullscreen mode: $error');
      })
      .catchError((error) {
        log.warning('Error entering fullscreen: $error');
      });

  log.info('Fullscreen request sent.');
}

bool isFullscreenImpl() {
  return web.document.fullscreenElement != null;
}

void exitFullscreenImpl() {
  web.document.exitFullscreen();
}
