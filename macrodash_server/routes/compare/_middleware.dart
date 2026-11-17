import 'package:dart_frog/dart_frog.dart';

import 'package:macrodash_server/cache.dart';
import 'package:macrodash_server/market_data.dart';

export 'package:macrodash_server/cache.dart';
export 'package:macrodash_server/market_data.dart';

Handler middleware(Handler handler) => handler
    .use(provider<MarketData>((_) => MarketData()))
    .use(provider<Cache>((_) => Cache()));
