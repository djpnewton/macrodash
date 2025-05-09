import 'package:dart_frog/dart_frog.dart';
import 'package:logging/logging.dart';
import 'package:macrodash_models/models.dart';

import '_middleware.dart';

final _log = Logger('ticker_search');

Future<Response> onRequest(RequestContext context) async {
  final dataDownloader = context.read<MarketData>();

  final request = context.request;
  final params = request.uri.queryParameters;

  // Parse the ticker1 parameter
  final ticker1 = params['ticker1'];
  if (ticker1 == null || ticker1.isEmpty) {
    return Response(
      statusCode: 400,
      body: 'Ticker1 parameter is required.',
    );
  }

  // Parse the ticker2 parameter
  final ticker2 = params['ticker2'];

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

  final result = await dataDownloader.custom(ticker1, ticker2, range);
  if (result == null) {
    return Response(statusCode: 500, body: 'Failed to fetch ticker data.');
  }

  // Cache the response
  final resultJson = result.toJson();
  cache.add(key, resultJson);

  return Response.json(
    body: resultJson,
    headers: {'Content-Type': 'application/json'},
  );
}
