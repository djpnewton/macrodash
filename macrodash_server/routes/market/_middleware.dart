import 'package:dart_frog/dart_frog.dart';
import 'package:logging/logging.dart';

// ignore: avoid_relative_lib_imports
import '../../lib/cache.dart';
// ignore: avoid_relative_lib_imports
import '../../lib/market_data.dart';

export '../../lib/cache.dart';
export '../../lib/market_data.dart';

final Logger log = Logger('market_middleware');

Handler middleware(Handler handler) {
  return handler
      .use(
        provider<MarketData>((_) => MarketData()),
      )
      .use(
        provider<Cache>((_) => Cache()),
      );
}
