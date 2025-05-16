import 'package:dart_frog/dart_frog.dart';
import 'package:logging/logging.dart';
import 'package:macrodash_models/models.dart';

import '_middleware.dart';

final _log = Logger('market_dividends');

Future<Response> onRequest(RequestContext context) async {
  final dataDownloader = context.read<MarketData>();

  final request = context.request;
  final params = request.uri.queryParameters;

  // Parse the ticker parameter
  final ticker = params['ticker']?.toUpperCase();
  if (ticker == null || ticker.isEmpty) {
    return Response(
      statusCode: 400,
      body: 'Ticker parameter is required.',
    );
  }

  // Parse the range parameter into the DataRange enum
  final rangeParam = params['range']?.toLowerCase();
  final range = DataRange.values.firstWhere(
    (t) => t.name.toLowerCase() == rangeParam,
    orElse: () => DataRange.max,
  );

  // check cache
  final cache = context.read<Cache>();
  final key = request.uri.toString();
  final cachedResponse = cache.get(key);
  if (cachedResponse != null) {
    _log.info('Cache hit: $key');
    return Response.json(
      body: cachedResponse,
      headers: {'Content-Type': 'application/json'},
    );
  }

  final data = await dataDownloader.custom(ticker, null, range, null);
  if (data == null) {
    return Response(statusCode: 500, body: 'Failed to fetch dividends data.');
  }

  final description = 'Dividends for $ticker (${data.currency})';

  final result = AmountSeries(
    description: description,
    sources: const [MarketData.yahooSource],
    data: data.dividendData,
  );

  // Cache the response
  final resultJson = result.toJson();
  cache.add(key, resultJson);

  return Response.json(
    body: resultJson,
    headers: {'Content-Type': 'application/json'},
  );
}
