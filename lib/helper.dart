import 'package:flutter/foundation.dart';

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

bool isWebMobile() {
  return kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);
}

String formatPrice(
  double price, {
  String currencyChar = '\$',
  String space = ' ',
}) {
  if (price >= 1e6) {
    return '$currencyChar${(price / 1e6).toStringAsFixed(2)}${space}M';
  } else if (price >= 1e3) {
    return '$currencyChar${(price / 1e3).toStringAsFixed(2)}${space}K';
  } else {
    return '$currencyChar${price.toStringAsFixed(2)}';
  }
}
