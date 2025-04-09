import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:logging/logging.dart';

import '../../lib/data.dart';
export '../../lib/data.dart';

final Logger log = Logger('sov_middleware');

Handler middleware(Handler handler) {
  return handler.use(
    provider<DataDownloader>((_) {
      final apiKey = Platform.environment['FRED_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        log.severe('FRED_API_KEY is not set in the environment');
      }
      return DataDownloader(
        fredApiKey: apiKey ?? '',
      );
    }),
  );
}
