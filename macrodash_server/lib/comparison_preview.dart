import 'package:logging/logging.dart';
import 'package:macrodash_models/models.dart';
import 'package:macrodash_preview/macrodash_preview.dart';

import 'package:macrodash_server/cache.dart';
import 'package:macrodash_server/market_data.dart';

final _log = Logger('comparison_preview');

/// Fetches and normalizes every ticker, caching the result for HTML and PNG.
Future<List<ComparisonSeries>?> buildComparisonPreview({
  required ComparisonLink link,
  required MarketData marketData,
  required Cache cache,
}) async {
  final key = 'comparison:${link.range}:${link.yearOffsetMinutes}:'
      '${link.tickers.join('\u0000')}';
  final cached = cache.get(key);
  if (cached is List<ComparisonSeries>) return cached;
  final range = switch (link.range) {
    'oneDay' => DataRange.sevenDays,
    'sevenDays' => DataRange.sevenDays,
    'oneMonth' => DataRange.oneMonth,
    'oneYear' || 'yearToDate' => DataRange.oneYear,
    _ => throw ArgumentError.value(link.range, 'range'),
  };
  final results = await Future.wait(
    link.tickers.map((symbol) => marketData.custom(symbol, null, range, null)),
  );
  if (results.any((result) => result == null)) {
    _log.warning('Could not fetch all comparison series');
    return null;
  }
  final series = [
    for (var i = 0; i < results.length; i++)
      ComparisonSeries(
        label: link.tickers[i],
        prices: results[i]!.priceData,
        dividends: results[i]!.dividendData,
        currency: results[i]!.currency,
        sources: results[i]!.sources,
      ),
  ];
  final cutoff = link.range == 'yearToDate'
      ? comparisonYearStart(DateTime.now(), link.yearOffsetMinutes ?? 0)
      : null;
  final normalized = normalizeComparison(
    series,
    cutoff: cutoff,
    window: link.range == 'oneDay' ? const Duration(hours: 24) : null,
  );
  if (normalized == null) {
    _log.warning('Not enough overlapping data for comparison preview');
    return null;
  }
  cache.add(key, normalized, expirationDuration: const Duration(minutes: 15));
  return normalized;
}

/// Human-readable label for a validated range.
String comparisonRangeLabel(String range) => switch (range) {
      'oneDay' => '24h',
      'sevenDays' => '7D',
      'oneMonth' => '1M',
      'oneYear' => '1Y',
      'yearToDate' => 'YTD',
      _ => throw ArgumentError.value(range, 'range'),
    };
