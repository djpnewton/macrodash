/// Builds the links that get shared, so the app and the server always agree on
/// the shape of a shareable URL.
///
/// A share link points at the preview host (e.g. `https://ln.macrodash.me`),
/// which serves HTML with per-ticker Open Graph tags for scrapers and
/// redirects people to [tickerAppUrl].
library;

import 'package:macrodash_models/models.dart';

/// The in-app URL for a ticker, e.g.
/// `https://macrodash.me/#/ticker?ticker1=GC%3DF&title=Gold`.
///
/// [params] are forwarded verbatim (e.g. `zoom`), so app settings survive the
/// redirect from the preview page.
String tickerAppUrl({
  required String appUrl,
  required String ticker1,
  Map<String, String> params = const {},
}) {
  final query = _query({...params, 'ticker1': ticker1});
  return '${_trimSlashes(appUrl)}/#/ticker?$query';
}

/// The shareable preview URL, e.g.
/// `https://ln.macrodash.me/t/GC%3DF?title=Gold`.
///
/// [params] are forwarded verbatim and must not include `ticker1`, which is
/// carried in the path.
String tickerShareUrl({
  required String previewUrl,
  required String ticker1,
  Map<String, String> params = const {},
}) {
  final base = '${_trimSlashes(previewUrl)}/t/${Uri.encodeComponent(ticker1)}';
  final query = _query(params);
  return query.isEmpty ? base : '$base?$query';
}

/// App route names that have a server-rendered link preview, e.g. "m2".
const previewPageNames = {
  'm2',
  'debt',
  'bondrates',
  'indices',
  'futures',
  'marketcap',
};

/// Whether [page] (an app route name) has a link preview.
bool isPreviewPage(String page) =>
    previewPageNames.contains(page.toLowerCase());

/// The chart range a share link's preview image is drawn over.
///
/// Mirrors the server: `range` wins over the `zoom` used by some pages, and
/// unknown or missing values fall back to a five-day window, which is dense
/// enough to show a curve.
DataRange previewImageRange(Map<String, String> params) {
  final name = (params['range'] ?? params['zoom'])?.toLowerCase();
  return DataRange.values.firstWhere(
    (range) => range.name.toLowerCase() == name,
    orElse: () => DataRange.fiveDays,
  );
}

/// The image a ticker share link advertises, e.g.
/// `https://ln.macrodash.me/market/custom_preview_image?range=fiveDays&ticker1=GC%3DF`.
///
/// This is the same PNG the preview page puts in its Open Graph tags, so the
/// share dialog shows recipients exactly what will unfurl.
String tickerPreviewImageUrl({
  required String previewUrl,
  required String ticker1,
  Map<String, String> params = const {},
}) {
  final ticker2 = params['ticker2'];
  final title = params['title'];
  final query = _query({
    'ticker1': ticker1,
    if (ticker2 != null && ticker2.isNotEmpty) 'ticker2': ticker2,
    if (title != null && title.isNotEmpty) 'title': title,
    'range': previewImageRange(params).name,
  });
  return '${_trimSlashes(previewUrl)}/market/custom_preview_image?$query';
}

/// The image a page share link advertises, e.g.
/// `https://ln.macrodash.me/p/m2/preview_image?region=usa`.
String pagePreviewImageUrl({
  required String previewUrl,
  required String page,
  Map<String, String> params = const {},
}) {
  final base =
      '${_trimSlashes(previewUrl)}/p/${Uri.encodeComponent(page)}/preview_image';
  final query = _query(params);
  return query.isEmpty ? base : '$base?$query';
}

/// The in-app URL for a non-ticker page, e.g.
/// `https://macrodash.me/#/m2?region=usa&zoom=oneYear`.
String pageAppUrl({
  required String appUrl,
  required String page,
  Map<String, String> params = const {},
}) {
  final query = _query(params);
  final path = '/#/${Uri.encodeComponent(page)}';
  return '${_trimSlashes(appUrl)}$path${query.isEmpty ? '' : '?$query'}';
}

/// The shareable preview URL for a page, e.g.
/// `https://ln.macrodash.me/p/m2?region=usa&zoom=oneYear`.
String pageShareUrl({
  required String previewUrl,
  required String page,
  Map<String, String> params = const {},
}) {
  final base = '${_trimSlashes(previewUrl)}/p/${Uri.encodeComponent(page)}';
  final query = _query(params);
  return query.isEmpty ? base : '$base?$query';
}

String _query(Map<String, String> params) {
  final keys = params.keys.where((k) => params[k]!.isNotEmpty).toList()..sort();
  return keys
      .map((k) => '$k=${Uri.encodeQueryComponent(params[k]!)}')
      .join('&');
}

String _trimSlashes(String url) =>
    url.endsWith('/') ? url.substring(0, url.length - 1) : url;
