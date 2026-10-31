import 'package:dart_frog/dart_frog.dart';
import 'package:logging/logging.dart';
import 'package:macrodash_models/models.dart';
import 'package:macrodash_preview/macrodash_preview.dart';

import '_middleware.dart';

final _log = Logger('market_custom_preview_image');

/// Renders a ticker as a 1200x630 PNG for link previews.
Future<Response> onRequest(RequestContext context) async {
  final dataDownloader = context.read<MarketData>();

  final request = context.request;
  final params = request.uri.queryParameters;

  final ticker1 = params['ticker1'];
  if (ticker1 == null || ticker1.isEmpty) {
    return Response(statusCode: 400, body: 'Ticker1 parameter is required.');
  }
  final ticker2 = params['ticker2']?.isEmpty ?? true ? null : params['ticker2'];

  final rangeParam = params['range']?.toLowerCase();
  final range = DataRange.values.firstWhere(
    (r) => r.name.toLowerCase() == rangeParam,
    // Dense enough to draw a curve; "max" is monthly and would be a single
    // point over a 7-day window.
    orElse: () => DataRange.fiveDays,
  );
  final intervalParam = params['interval']?.toLowerCase();
  final interval = DataInterval.values
      .where((i) => i.name.toLowerCase() == intervalParam)
      .firstOrNull;

  final cache = context.read<Cache>();
  final key = request.uri.toString();
  final cached = cache.get(key) as List<int>?;
  if (cached != null) {
    _log.info('Cache hit: $key');
    return _pngResponse(cached);
  }

  final result = await dataDownloader.custom(ticker1, ticker2, range, interval);
  if (result == null) {
    return Response(statusCode: 502, body: 'Failed to fetch ticker data.');
  }

  final png = await renderPreviewPng(
    PreviewData.fromTicker(result, title: params['title']),
  );
  cache.add(key, png);
  return _pngResponse(png);
}

Response _pngResponse(List<int> bytes) => Response.bytes(
      body: bytes,
      headers: {
        'Content-Type': 'image/png',
        'Cache-Control': 'public, max-age=900',
      },
    );
