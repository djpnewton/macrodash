import 'package:dart_frog/dart_frog.dart';
import 'package:logging/logging.dart';
import 'package:macrodash_models/models.dart';

import '_middleware.dart';

final _log = Logger('market_capitalization');

Future<Response> onRequest(RequestContext context) async {
  final dataDownloader = context.read<MarketData>();

  final request = context.request;
  final params = request.uri.queryParameters;

  // Parse the type parameter into the MarketCap enum
  final typeParam = params['type']?.toLowerCase();
  final type = MarketCap.values.firstWhere(
    (r) => r.name.toLowerCase() == typeParam,
    orElse: () => MarketCap.all,
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

  final serverUrl =
      '${context.request.uri.scheme}://${context.request.uri.authority}';
  final result = await dataDownloader.marketCapData(type, serverUrl);
  if (result == null) {
    return Response(statusCode: 500, body: 'Failed to fetch market cap data.');
  }

  // Cache the response
  final resultJson = result.toJson();
  cache.add(key, resultJson);

  return Response.json(
    body: resultJson,
    headers: {'Content-Type': 'application/json'},
  );
}
