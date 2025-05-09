import 'package:dart_frog/dart_frog.dart';
import 'package:logging/logging.dart';

import '_middleware.dart';

final _log = Logger('ticker_search');

Future<Response> onRequest(RequestContext context) async {
  final dataDownloader = context.read<MarketData>();

  final request = context.request;
  final params = request.uri.queryParameters;

  // Parse the query parameter
  final query = params['query'];
  if (query == null || query.isEmpty) {
    return Response(
      statusCode: 400,
      body: 'Query parameter is required.',
    );
  }

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

  final result = await dataDownloader.tickerSearch(query);
  if (result == null) {
    return Response(
      statusCode: 500,
      body: 'Failed to fetch ticker search data.',
    );
  }

  // Cache the response
  final resultJson = result.toJson();
  cache.add(key, resultJson);

  return Response.json(
    body: resultJson,
    headers: {'Content-Type': 'application/json'},
  );
}
