import 'package:dart_frog/dart_frog.dart';
import 'package:logging/logging.dart';
import 'package:macrodash_models/models.dart';

import '_middleware.dart';

final _log = Logger('sov_bond_rates');

Future<Response> onRequest(RequestContext context) async {
  final dataDownloader = context.read<SovData>();

  final request = context.request;
  final params = request.uri.queryParameters;

  // Parse the region parameter into the Region enum
  final regionParam = params['region']?.toLowerCase();
  final region = BondRateRegion.values.firstWhere(
    (r) => r.name.toLowerCase() == regionParam,
    orElse: () => BondRateRegion.usa,
  );

  // Parse the term parameter into the BondTerm enum
  final termParam = params['term']?.toLowerCase();
  final term = BondTerm.values.firstWhere(
    (t) => t.name.toLowerCase() == termParam,
    orElse: () => BondTerm.thirtyYear,
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

  // Fetch data based on the region
  List<BondRateData>? bondRateData;
  switch (region) {
    case BondRateRegion.usa:
      bondRateData = await dataDownloader.usBondRateData();
  }

  if (bondRateData == null) {
    return Response(statusCode: 500, body: 'Failed to fetch debt data.');
  }

  final data = bondRateData.firstWhere((entry) {
    return entry.term == term;
  });

  List<String> sources;
  switch (region) {
    case BondRateRegion.usa:
      sources = [SovData.usTreasurySource];
  }

  final description = switch (term) {
    BondTerm.thirtyYear => '30-Year Treasury Rate',
    BondTerm.twentyYear => '20-Year Treasury Rate',
    BondTerm.tenYear => '10-Year Treasury Rate',
    BondTerm.fiveYear => '5-Year Treasury Rate',
    BondTerm.oneYear => '1-Year Treasury Rate',
  };

  final result = AmountSeries(
    description: description,
    sources: sources,
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
