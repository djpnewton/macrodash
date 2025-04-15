import 'package:dart_frog/dart_frog.dart';
import 'package:logging/logging.dart';
import 'package:macrodash_models/models.dart';

import '_middleware.dart';

final _log = Logger('sov_m2');

Future<Response> onRequest(RequestContext context) async {
  final dataDownloader = context.read<SovData>();

  final request = context.request;
  final params = request.uri.queryParameters;

  // Parse the region parameter into the Region enum
  final regionParam = params['region']?.toLowerCase();
  final region = M2Region.values.firstWhere(
    (r) => r.name == regionParam,
    orElse: () => M2Region.all,
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
  List<AmountEntry>? m2Data;
  switch (region) {
    case M2Region.japan:
      m2Data = await dataDownloader.japM2Data();
    case M2Region.euro:
      m2Data = await dataDownloader.ecbM2Data();
    case M2Region.usa:
      m2Data = await dataDownloader.fredM2Data();
    case M2Region.all:
      // Combine data from all sources for ALL
      final usaData = await dataDownloader.fredM2Data();
      final ecbData = await dataDownloader.ecbM2Data();
      final japData = await dataDownloader.japM2Data();

      if (usaData != null && ecbData != null && japData != null) {
        // Combine data by matching dates and summing amounts
        final usdMap = {for (final entry in usaData) entry.date: entry.amount};
        final japMap = {for (final entry in japData) entry.date: entry.amount};
        final combinedData = ecbData
            .where(
          (entry) =>
              usdMap.containsKey(entry.date) && japMap.containsKey(entry.date),
        )
            .map((entry) {
          final combinedAmount = entry.amount +
              (usdMap[entry.date] ?? 0.0) +
              (japMap[entry.date] ?? 0.0);
          return AmountEntry(date: entry.date, amount: combinedAmount);
        }).toList();

        m2Data = combinedData;
      } else {
        m2Data = null;
      }
  }

  if (m2Data == null) {
    return Response(statusCode: 500, body: 'Failed to fetch M2 data.');
  }

  List<String> sources;
  switch (region) {
    case M2Region.japan:
    case M2Region.euro:
      sources = [SovData.ecbSource];
    case M2Region.usa:
      sources = [SovData.fredSource];
    case M2Region.all:
      sources = [
        SovData.fredSource,
        SovData.ecbSource,
      ];
  }

  final result = AmountSeries(
    description: 'Trillions of Dollars',
    sources: sources,
    data: m2Data,
  );

  // Cache the response
  final resultJson = result.toJson();
  cache.add(key, resultJson);

  return Response.json(
    body: resultJson,
    headers: {'Content-Type': 'application/json'},
  );
}
