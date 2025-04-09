import 'package:dart_frog/dart_frog.dart';
import 'package:macrodash_models/models.dart';

import '_middleware.dart';

Future<Response> onRequest(RequestContext context) async {
  final dataDownloader = context.read<DataDownloader>();

  final request = context.request;
  final params = request.uri.queryParameters;

  // Parse the region parameter into the Region enum
  final regionParam = params['region']?.toLowerCase();
  final region = DebtRegion.values.firstWhere(
    (r) => r.name == regionParam,
    orElse: () => DebtRegion.all,
  );

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
      sources = [DataDownloader.usTreasurySource];
  }

  final result = AmountSeries(
    description: 'Trillions of Dollars',
    sources: sources,
    data: debtData,
  );

  return Response.json(
    body: result.toJson(),
    headers: {'Content-Type': 'application/json'},
  );
}
