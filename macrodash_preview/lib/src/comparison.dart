import 'dart:convert';

import 'package:macrodash_models/models.dart';

/// Maximum number of series supported by comparison previews.
const maxComparisonTickers = 12;

/// Validated share parameters for a comparison.
class ComparisonLink {
  const ComparisonLink({
    required this.tickers,
    required this.baseCount,
    required this.range,
    this.yearOffsetMinutes,
  });

  final List<String> tickers;
  final int baseCount;
  final String range;
  final int? yearOffsetMinutes;

  static ComparisonLink? parse(Map<String, String> params) {
    final value = params['tickers'];
    if (value == null) return null;
    Object? decoded;
    try {
      decoded = jsonDecode(value);
    } on FormatException {
      return null;
    }
    if (decoded is! List ||
        decoded.isEmpty ||
        decoded.length > maxComparisonTickers ||
        !decoded.every(
          (item) =>
              item is String &&
              item.isNotEmpty &&
              item.length <= 128 &&
              item == item.trim() &&
              !RegExp(r'[\x00-\x1f\x7f]').hasMatch(item),
        )) {
      return null;
    }
    final tickers = decoded.cast<String>();
    final baseCount = int.tryParse(params['baseCount'] ?? '');
    final range = params['range'];
    final offset = int.tryParse(params['yearOffset'] ?? '');
    if (baseCount == null ||
        baseCount < 1 ||
        baseCount > 2 ||
        baseCount > tickers.length ||
        !const [
          'oneDay',
          'sevenDays',
          'oneMonth',
          'oneYear',
          'yearToDate',
        ].contains(range) ||
        (params.containsKey('yearOffset') &&
            (offset == null || offset < -720 || offset > 840)) ||
        tickers.map((item) => item.toUpperCase()).toSet().length !=
            tickers.length) {
      return null;
    }
    return ComparisonLink(
      tickers: tickers,
      baseCount: baseCount,
      range: range!,
      yearOffsetMinutes: offset,
    );
  }
}

/// Calendar-year start for the offset stored in a comparison share link.
DateTime comparisonYearStart(DateTime now, int offsetMinutes) {
  final offset = Duration(minutes: offsetMinutes);
  final year = now.toUtc().add(offset).year;
  return DateTime.utc(year).subtract(offset);
}

/// Starting index for each normalized series (zero percent change).
const comparisonBaseline = 100.0;

/// Chart colors shared by the app and preview renderer.
const comparisonColorValues = [
  0xff2196f3,
  0xffff5722,
  0xff009688,
  0xff9c27b0,
  0xff795548,
  0xffe91e63,
];

/// A price series and its source metadata.
class ComparisonSeries {
  const ComparisonSeries({
    required this.label,
    required this.prices,
    required this.dividends,
    required this.currency,
    this.sources = const [],
  });

  final String label;
  final List<AmountEntry> prices;
  final List<AmountEntry> dividends;
  final String currency;
  final List<String> sources;
}

/// Positions all observations on a shared, evenly spaced timeline.
///
/// Matching timestamps align across series; periods without observations in
/// any series take no horizontal space, as in the dashboard sparklines.
class ComparisonTimeline {
  ComparisonTimeline(List<ComparisonSeries> series) {
    final timestamps =
        series
            .expand((item) => item.prices)
            .map((point) => point.date.microsecondsSinceEpoch)
            .toSet()
            .toList()
          ..sort();
    _positions = {for (var i = 0; i < timestamps.length; i++) timestamps[i]: i};
  }

  late final Map<int, int> _positions;

  int get length => _positions.length;

  int position(DateTime date) => _positions[date.microsecondsSinceEpoch]!;
}

/// Clips to the common window and indexes each series to 100.
/// When [window] is set, it ends at the earliest series' last timestamp.
List<ComparisonSeries>? normalizeComparison(
  List<ComparisonSeries> input, {
  DateTime? cutoff,
  Duration? window,
}) {
  if (input.isEmpty) return null;
  final sorted = [
    for (final series in input)
      ComparisonSeries(
        label: series.label,
        prices:
            series.prices
                .where(
                  (entry) =>
                      entry.amount.isFinite &&
                      (cutoff == null || !entry.date.isBefore(cutoff)),
                )
                .toList()
              ..sort((a, b) => a.date.compareTo(b.date)),
        dividends: series.dividends,
        currency: series.currency,
        sources: series.sources,
      ),
  ];
  if (sorted.any((series) => series.prices.length < 2)) return null;
  final start = sorted
      .map((series) => series.prices.first.date)
      .reduce((a, b) => a.isAfter(b) ? a : b);
  final end = sorted
      .map((series) => series.prices.last.date)
      .reduce((a, b) => a.isBefore(b) ? a : b);
  if (!start.isBefore(end)) return null;
  final windowStart = window == null ? start : end.subtract(window);
  final effectiveStart = windowStart.isAfter(start) ? windowStart : start;

  DateTime day(DateTime date) => DateTime(date.year, date.month, date.day);
  final output = <ComparisonSeries>[];
  for (final series in sorted) {
    final prices =
        series.prices
            .where(
              (entry) =>
                  !entry.date.isBefore(effectiveStart) &&
                  !entry.date.isAfter(end),
            )
            .toList();
    if (prices.length < 2 || prices.first.amount == 0) return null;
    final base = prices.first.amount;
    if (prices.any((entry) => !(entry.amount / base * 100).isFinite)) {
      return null;
    }
    output.add(
      ComparisonSeries(
        label: series.label,
        prices: [
          for (final entry in prices)
            AmountEntry(date: entry.date, amount: entry.amount / base * 100),
        ],
        dividends:
            series.dividends
                .where(
                  (entry) =>
                      !day(entry.date).isBefore(day(effectiveStart)) &&
                      !day(entry.date).isAfter(day(end)),
                )
                .toList()
              ..sort((a, b) => a.date.compareTo(b.date)),
        currency: series.currency,
        sources: series.sources,
      ),
    );
  }
  return output;
}
