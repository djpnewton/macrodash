import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:logging/logging.dart';
import 'package:macrodash_preview/macrodash_preview.dart';

import 'package:macrodash_server/comparison_preview.dart';
import 'package:macrodash_server/preview_html.dart';
import '_middleware.dart';

final _log = Logger('comparison_link_preview');

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405);
  }
  final params = context.request.uri.queryParameters;
  final link = ComparisonLink.parse(params);
  if (link == null) {
    return Response(statusCode: 400, body: 'Invalid comparison link.');
  }
  final host = context.request.headers['host'] ?? 'ln.macrodash.me';
  final scheme = host.startsWith('localhost') || host.startsWith('127.0.0.1')
      ? 'http'
      : 'https';
  final baseUrl = '$scheme://$host';
  final appUrl = Platform.environment['APP_URL'] ?? 'https://macrodash.me';
  var imageUrl = comparisonPreviewImageUrl(previewUrl: baseUrl, params: params);
  try {
    final preview = await buildComparisonPreview(
      link: link,
      marketData: context.read<MarketData>(),
      cache: context.read<Cache>(),
    );
    if (preview == null) imageUrl = '$appUrl/og-image.png';
  } catch (error, stackTrace) {
    _log.warning('Failed to build comparison preview', error, stackTrace);
    imageUrl = '$appUrl/og-image.png';
  }
  final title =
      '${link.tickers.join(' vs ')} - ${comparisonRangeLabel(link.range)}';
  return Response(
    body: renderLinkPreviewHtml(
      title: title,
      description: 'Relative performance on MacroDash. '
          'Price changes exclude dividends.',
      shareUrl: comparisonShareUrl(previewUrl: baseUrl, params: params),
      imageUrl: imageUrl,
      imageAlt: 'MacroDash relative performance for ${link.tickers.join(', ')}',
      appLink: comparisonAppUrl(appUrl: appUrl, params: params),
    ),
    headers: {
      'Content-Type': 'text/html; charset=utf-8',
      'Cache-Control': 'public, max-age=300',
    },
  );
}
