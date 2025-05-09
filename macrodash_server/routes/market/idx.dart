import 'package:dart_frog/dart_frog.dart';
import 'package:logging/logging.dart';
import 'package:macrodash_models/models.dart';

import '_middleware.dart';

final _log = Logger('market_indices');

Future<Response> onRequest(RequestContext context) async {
  final dataDownloader = context.read<MarketData>();

  final request = context.request;
  final params = request.uri.queryParameters;

  // Parse the region parameter into the Region enum
  final regionParam = params['region']?.toLowerCase();
  final region = MarketIndexRegion.values.firstWhere(
    (r) => r.name.toLowerCase() == regionParam,
    orElse: () => MarketIndexRegion.usa,
  );

  // Parse the term parameter into the market index enum
  final index = switch (region) {
    MarketIndexRegion.usa => MarketIndexUsa.values.firstWhere(
        (r) => r.name.toLowerCase() == params['index']?.toLowerCase(),
        orElse: () => MarketIndexUsa.sp500,
      ),
    MarketIndexRegion.europe => MarketIndexEurope.values.firstWhere(
        (r) => r.name.toLowerCase() == params['index']?.toLowerCase(),
        orElse: () => MarketIndexEurope.ftse100,
      ),
    MarketIndexRegion.asia => MarketIndexAsia.values.firstWhere(
        (r) => r.name.toLowerCase() == params['index']?.toLowerCase(),
        orElse: () => MarketIndexAsia.nikkei225,
      )
  };

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

  final data = await dataDownloader.indexData(index, range);
  if (data == null) {
    return Response(statusCode: 500, body: 'Failed to fetch index data.');
  }

  final description = marketIndexUsaLabels.containsKey(index)
      ? marketIndexUsaLabels[index]
      : marketIndexEuropeLabels.containsKey(index)
          ? marketIndexEuropeLabels[index]
          : marketIndexAsiaLabels[index];

  final result = AmountSeries(
    description: description ?? 'unknown index',
    sources: const [MarketData.yahooSource],
    data: data.data,
  );

  // Cache the response
  final resultJson = result.toJson();
  cache.add(key, resultJson);

  return Response.json(
    body: resultJson,
    headers: {'Content-Type': 'application/json'},
  );
}
