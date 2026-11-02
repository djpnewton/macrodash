import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:logging/logging.dart';
import 'package:macrodash_models/models.dart';
import 'package:macrodash_preview/macrodash_preview.dart';

// ignore: avoid_relative_lib_imports
import '../../lib/preview_html.dart';
import '_middleware.dart';

final _log = Logger('link_preview');

/// Serves the page that link unfurlers read for a ticker, e.g.
/// `https://ln.macrodash.me/t/GC%3DF?title=Gold`.
///
/// Scrapers do not run JavaScript, so the Open Graph tags have to be server
/// rendered. People who follow the link are redirected into the app.
Future<Response> onRequest(RequestContext context, String ticker) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405);
  }

  final params = context.request.uri.queryParameters;
  final host = context.request.headers['host'] ?? 'ln.macrodash.me';
  final scheme = host.startsWith('localhost') || host.startsWith('127.0.0.1')
      ? 'http'
      : 'https';
  final baseUrl = '$scheme://$host';
  final appUrl = Platform.environment['APP_URL'] ?? 'https://macrodash.me';

  final ticker1 = Uri.decodeComponent(ticker);
  final ticker2 = params['ticker2']?.isEmpty ?? true ? null : params['ticker2'];
  final title = params['title']?.isEmpty ?? true ? null : params['title'];
  final rangeParam = (params['range'] ?? params['zoom'])?.toLowerCase();
  final range = DataRange.values.firstWhere(
    (r) => r.name.toLowerCase() == rangeParam,
    // "max" is monthly, which is a single point over a short window.
    orElse: () => DataRange.fiveDays,
  );

  final imageUrl = tickerPreviewImageUrl(
    previewUrl: baseUrl,
    ticker1: ticker1,
    params: params,
  );
  // Forward every query parameter to the app so page settings (e.g. `zoom`)
  // survive the redirect; `ticker1` is rebuilt from the path.
  final forwarded = {...params}..remove('ticker1');
  final shareUrl = tickerShareUrl(
    previewUrl: baseUrl,
    ticker1: ticker1,
    params: forwarded,
  );
  final appLink = tickerAppUrl(
    appUrl: appUrl,
    ticker1: ticker1,
    params: forwarded,
  );

  var pageTitle = title ?? ticker1;
  var description = 'Live chart and market data for $ticker1 on MacroDash.';
  var ogImage = imageUrl;

  final result = await context.read<MarketData>().custom(
        ticker1,
        ticker2,
        range,
        null,
      );
  if (result == null) {
    _log.warning('No data for $ticker1, falling back to the site image');
    ogImage = '$appUrl/og-image.png';
  } else {
    final data = PreviewData.fromTicker(result, title: title);
    pageTitle = '${data.title} (${data.value} ${data.unit})';
    description = '${data.subtitle}: ${data.value} ${data.unit}, '
        '${data.change} over ${data.windowLabel}. MacroDash.';
  }

  final html = renderLinkPreviewHtml(
    title: pageTitle,
    description: description,
    shareUrl: shareUrl,
    imageUrl: ogImage,
    imageAlt: 'MacroDash chart for $ticker1',
    appLink: appLink,
  );

  return Response(
    body: html,
    headers: {
      'Content-Type': 'text/html; charset=utf-8',
      'Cache-Control': 'public, max-age=300',
    },
  );
}
