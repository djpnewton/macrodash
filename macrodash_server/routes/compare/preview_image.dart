import 'package:dart_frog/dart_frog.dart';
import 'package:macrodash_preview/macrodash_preview.dart';

import 'package:macrodash_server/comparison_preview.dart';
import '_middleware.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405);
  }
  final request = context.request;
  final link = ComparisonLink.parse(request.uri.queryParameters);
  if (link == null) {
    return Response(statusCode: 400, body: 'Invalid comparison link.');
  }
  final cache = context.read<Cache>();
  final key = request.uri.toString();
  final cached = cache.get(key);
  if (cached is List<int>) return _pngResponse(cached);
  final series = await buildComparisonPreview(
    link: link,
    marketData: context.read<MarketData>(),
    cache: cache,
  );
  if (series == null) {
    return Response(
      statusCode: 502,
      body: 'Failed to build comparison preview.',
    );
  }
  final png = await renderComparisonPreviewPng(
    series,
    rangeLabel: comparisonRangeLabel(link.range),
  );
  cache.add(key, png, expirationDuration: const Duration(minutes: 15));
  return _pngResponse(png);
}

Response _pngResponse(List<int> bytes) => Response.bytes(
      body: bytes,
      headers: {
        'Content-Type': 'image/png',
        'Cache-Control': 'public, max-age=900',
      },
    );
