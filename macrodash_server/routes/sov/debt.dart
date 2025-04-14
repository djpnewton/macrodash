import 'package:dart_frog/dart_frog.dart';
import 'package:logging/logging.dart';
import 'package:macrodash_models/models.dart';

import '_middleware.dart';

final _log = Logger('sov_debt');

Future<Response> onRequest(RequestContext context) async {
  final dataDownloader = context.read<SovData>();

  final request = context.request;
  final params = request.uri.queryParameters;

  // Parse the region parameter into the Region enum
  final regionParam = params['region']?.toLowerCase();
  final region = DebtRegion.values.firstWhere(
    (r) => r.name == regionParam,
    orElse: () => DebtRegion.all,
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
  List<AmountEntry>? debtData;
  switch (region) {
    case DebtRegion.usa:
    case DebtRegion.all:
      debtData = await dataDownloader.usDebtData();
  }

  if (debtData == null) {
    return Response(statusCode: 500, body: 'Failed to fetch debt data.');
  }

  List<String> sources;
  switch (region) {
    case DebtRegion.all:
    case DebtRegion.usa:
      sources = [SovData.usTreasurySource];
  }

  final result = AmountSeries(
    description: 'Trillions of Dollars',
    sources: sources,
    data: debtData,
  );

  // Cache the response
  final resultJson = result.toJson();
  cache.add(key, resultJson);

  return Response.json(
    body: resultJson,
    headers: {'Content-Type': 'application/json'},
  );
}
