import 'dart:convert';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:logging/logging.dart';
import 'package:macrodash_models/models.dart';
import 'package:macrodash_preview/macrodash_preview.dart';

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
  final rangeParam =
      (params['range'] ?? params['zoom'])?.toLowerCase();
  final range = DataRange.values.firstWhere(
    (r) => r.name.toLowerCase() == rangeParam,
    // "max" is monthly, which is a single point over a short window.
    orElse: () => DataRange.fiveDays,
  );

  final imageUrl = Uri.parse('$baseUrl/market/custom_preview_image').replace(
    queryParameters: {
      'ticker1': ticker1,
      if (ticker2 != null) 'ticker2': ticker2,
      if (title != null) 'title': title,
      'range': range.name,
    },
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
  var ogImage = imageUrl.toString();

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
    final data = TickerPreviewData.fromTicker(result, title: title);
    pageTitle = '${data.title} (${data.price} ${data.currency})';
    description =
        '${data.subtitle}: ${data.price} ${data.currency}, '
        '${data.change} over ${data.windowLabel}. MacroDash.';
  }

  final html = '''
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${_escape(pageTitle)} — MacroDash</title>
<meta name="description" content="${_escape(description)}">
<meta property="og:type" content="website">
<meta property="og:site_name" content="MacroDash">
<meta property="og:title" content="${_escape(pageTitle)}">
<meta property="og:description" content="${_escape(description)}">
<meta property="og:url" content="${_escape(shareUrl)}">
<meta property="og:image" content="${_escape(ogImage)}">
<meta property="og:image:type" content="image/png">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
<meta property="og:image:alt" content="${_escape('MacroDash chart for $ticker1')}">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="${_escape(pageTitle)}">
<meta name="twitter:description" content="${_escape(description)}">
<meta name="twitter:image" content="${_escape(ogImage)}">
<meta name="twitter:image:alt" content="${_escape('MacroDash chart for $ticker1')}">
<meta name="theme-color" content="#0B1B33">
<meta http-equiv="refresh" content="0; url=${_escape(appLink)}">
<script>window.location.replace(${jsonEncode(appLink)});</script>
</head>
<body>
<p>Opening MacroDash… <a href="${_escape(appLink)}">Continue to the chart</a></p>
</body>
</html>
''';

  return Response(
    body: html,
    headers: {
      'Content-Type': 'text/html; charset=utf-8',
      'Cache-Control': 'public, max-age=300',
    },
  );
}

String _escape(String value) =>
    const HtmlEscape(HtmlEscapeMode.attribute).convert(value);
