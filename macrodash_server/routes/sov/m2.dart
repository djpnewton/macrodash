import 'package:dart_frog/dart_frog.dart';
import 'package:macrodash_models/models.dart';

import '_middleware.dart';

Future<Response> onRequest(RequestContext context) async {
  final dataDownloader = context.read<DataDownloader>();

  final request = context.request;
  final params = request.uri.queryParameters;

  // Parse the region parameter into the Region enum
  final regionParam = params['region']?.toLowerCase();
  final region = M2Region.values.firstWhere(
    (r) => r.name == regionParam,
    orElse: () => M2Region.all,
  );

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
      sources = [DataDownloader.ecbSource];
    case M2Region.usa:
      sources = [DataDownloader.fredSource];
    case M2Region.all:
      sources = [
        DataDownloader.fredSource,
        DataDownloader.ecbSource,
      ];
  }

  final result = AmountSeries(
    description: 'Billions of Dollars',
    sources: sources,
    data: m2Data,
  );

  return Response.json(
    body: result.toJson(),
    headers: {'Content-Type': 'application/json'},
  );
}
