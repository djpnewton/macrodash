import 'package:dart_frog/dart_frog.dart';
import 'package:macrodash_models/models.dart';

import '_middleware.dart';

Future<Response> onRequest(RequestContext context) async {
  final dataDownloader = context.read<DataDownloader>();

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
      sources = [DataDownloader.usTreasurySource];
  }

  final description = switch (term) {
    BondTerm.thirtyYear => '30-Year Treasury Rate',
    BondTerm.twentyYear => '20-Year Treasury Rate',
  };

  final result = AmountSeries(
    description: description,
    sources: sources,
    data: data.data,
  );

  return Response.json(
    body: result.toJson(),
    headers: {'Content-Type': 'application/json'},
  );
}
