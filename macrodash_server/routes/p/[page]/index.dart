import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:logging/logging.dart';
import 'package:macrodash_preview/macrodash_preview.dart';

// ignore: avoid_relative_lib_imports
import '../../../lib/page_preview.dart';
// ignore: avoid_relative_lib_imports
import '../../../lib/preview_html.dart';
import '../_middleware.dart';

final _log = Logger('page_link_preview');

/// Serves the page that link unfurlers read for a dashboard page, e.g.
/// `https://ln.macrodash.me/p/m2?region=usa&zoom=oneYear`.
///
/// Scrapers do not run JavaScript, so the Open Graph tags have to be server
/// rendered. People who follow the link are redirected into the app.
Future<Response> onRequest(RequestContext context, String page) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405);
  }
  if (!isPreviewPage(page)) {
    return Response(statusCode: 404);
  }

  final params = context.request.uri.queryParameters;
  final host = context.request.headers['host'] ?? 'ln.macrodash.me';
  final scheme = host.startsWith('localhost') || host.startsWith('127.0.0.1')
      ? 'http'
      : 'https';
  final baseUrl = '$scheme://$host';
  final appUrl = Platform.environment['APP_URL'] ?? 'https://macrodash.me';

  final shareUrl = pageShareUrl(
    previewUrl: baseUrl,
    page: page,
    params: params,
  );
  final appLink = pageAppUrl(appUrl: appUrl, page: page, params: params);
  final imageUrl = pagePreviewImageUrl(
    previewUrl: baseUrl,
    page: page,
    params: params,
  );

  PreviewData? preview;
  try {
    preview = await buildPagePreview(
      page: page,
      params: params,
      marketData: context.read<MarketData>(),
      sovData: context.read<SovData>(),
      cache: context.read<Cache>(),
      serverUrl: baseUrl,
    );
  } catch (e) {
    _log.warning('Failed to build preview for $page: $e');
  }

  final fallbackTitle = _pageTitle(page);
  var pageTitle = fallbackTitle;
  var description = 'Live $fallbackTitle chart on MacroDash.';
  var ogImage = imageUrl;

  if (preview == null) {
    _log.warning('No data for page $page, falling back to the site image');
    ogImage = '$appUrl/og-image.png';
  } else {
    pageTitle = preview.unit.isEmpty
        ? '${preview.title} (${preview.value})'
        : '${preview.title} (${preview.value} ${preview.unit})';
    description = preview.change.isNotEmpty && preview.windowLabel.isNotEmpty
        ? '${preview.subtitle}: ${preview.value} ${preview.unit}, '
            '${preview.change} over ${preview.windowLabel}. MacroDash.'
        : '${preview.subtitle}. Live chart on MacroDash.';
  }

  final html = renderLinkPreviewHtml(
    title: pageTitle,
    description: description,
    shareUrl: shareUrl,
    imageUrl: ogImage,
    imageAlt: 'MacroDash chart for ${preview?.title ?? fallbackTitle}',
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

String _pageTitle(String page) => switch (page.toLowerCase()) {
      'm2' => 'M2 Money Supply',
      'debt' => 'Public Debt',
      'bondrates' => 'Bond Rates',
      'indices' => 'Indices',
      'futures' => 'Futures',
      'marketcap' => 'Market Caps',
      _ => 'MacroDash',
    };
