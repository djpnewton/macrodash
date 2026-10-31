/// Builds the links that get shared, so the app and the server always agree on
/// the shape of a shareable URL.
///
/// A share link points at the preview host (e.g. `https://ln.macrodash.me`),
/// which serves HTML with per-ticker Open Graph tags for scrapers and
/// redirects people to [tickerAppUrl].
library;

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

String _query(Map<String, String> params) {
  final keys = params.keys.where((k) => params[k]!.isNotEmpty).toList()..sort();
  return keys
      .map((k) => '$k=${Uri.encodeQueryComponent(params[k]!)}')
      .join('&');
}

String _trimSlashes(String url) =>
    url.endsWith('/') ? url.substring(0, url.length - 1) : url;
