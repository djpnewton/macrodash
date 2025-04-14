import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:logging/logging.dart';

// ignore: avoid_relative_lib_imports
import '../../lib/cache.dart';
// ignore: avoid_relative_lib_imports
import '../../lib/sov_data.dart';

export '../../lib/cache.dart';
export '../../lib/sov_data.dart';

final Logger log = Logger('sov_middleware');

Handler middleware(Handler handler) {
  return handler.use(
    provider<SovData>((_) {
      final apiKey = Platform.environment['FRED_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        log.severe('FRED_API_KEY is not set in the environment');
      }
      return SovData(
        fredApiKey: apiKey ?? '',
      );
    }),
  ).use(
    provider<Cache>((_) => Cache()),
  );
}
