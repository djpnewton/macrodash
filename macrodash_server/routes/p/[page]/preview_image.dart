import 'package:dart_frog/dart_frog.dart';
import 'package:logging/logging.dart';
import 'package:macrodash_preview/macrodash_preview.dart';

// ignore: avoid_relative_lib_imports
import '../../../lib/page_preview.dart';
import '../_middleware.dart';

final _log = Logger('page_preview_image');

/// Renders a dashboard page as a 1200x630 PNG for link previews.
Future<Response> onRequest(RequestContext context, String page) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405);
  }
  if (!isPreviewPage(page)) {
    return Response(statusCode: 404);
  }

  final request = context.request;
  final cache = context.read<Cache>();
  final key = request.uri.toString();
  final cached = cache.get(key);
  if (cached is List<int>) {
    _log.info('Cache hit: $key');
    return _pngResponse(cached);
  }

  final host = request.headers['host'] ?? 'ln.macrodash.me';
  final scheme = host.startsWith('localhost') || host.startsWith('127.0.0.1')
      ? 'http'
      : 'https';
  final baseUrl = '$scheme://$host';

  final preview = await buildPagePreview(
    page: page,
    params: request.uri.queryParameters,
    marketData: context.read<MarketData>(),
    sovData: context.read<SovData>(),
    cache: cache,
    serverUrl: baseUrl,
  );
  if (preview == null) {
    return Response(statusCode: 502, body: 'Failed to build page preview.');
  }

  final png = await renderPreviewPng(preview);
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
