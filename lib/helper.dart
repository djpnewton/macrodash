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

/// Makes the browser back action call [onBack] while active (web only).
/// Call the returned function once the guarded UI is closed.
void Function() installBackGuard(void Function() onBack) {
  return installBackGuardImpl(onBack);
}

bool isWebMobile() {
  return kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);
}

/// Formats [price] with a magnitude suffix, e.g. `$8.50 K` or `-$2.10 T`.
///
/// Values below one keep enough decimals to stay readable (crypto prices), and
/// non-finite values render as `--`.
String formatPrice(
  double price, {
  String currencyChar = '\$',
  String space = ' ',
}) {
  if (!price.isFinite) {
    return '--';
  }
  final sign = price < 0 ? '-' : '';
  final value = price.abs();
  for (final (threshold, suffix) in const [
    (1e12, 'T'),
    (1e9, 'B'),
    (1e6, 'M'),
    (1e3, 'K'),
  ]) {
    if (value >= threshold) {
      return '$sign$currencyChar${(value / threshold).toStringAsFixed(2)}'
          '$space$suffix';
    }
  }
  return '$sign$currencyChar${_formatSmallAmount(value)}';
}

String _formatSmallAmount(double value) {
  if (value == 0 || value >= 0.01) {
    return value.toStringAsFixed(2);
  }
  if (value >= 0.0001) {
    return value.toStringAsFixed(4);
  }
  return value.toStringAsExponential(2);
}
