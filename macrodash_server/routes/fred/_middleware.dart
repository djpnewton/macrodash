import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:logging/logging.dart';

final Logger log = Logger('fred_middleware');

class FredConfig {
  FredConfig({required this.apiKey});
  final String apiKey;
}

Handler middleware(Handler handler) {
  return handler.use(
    provider<FredConfig>((_) {
      final apiKey = Platform.environment['FRED_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        log.severe('FRED_API_KEY is not set in the environment');
      }
      return FredConfig(
        apiKey: apiKey ?? '',
      );
    }),
  );
}
