import 'package:macrodash_models/models.dart';

/// A single point of the preview chart.
class PreviewPoint {
  const PreviewPoint({required this.time, required this.amount});

  final DateTime time;
  final double amount;
}

/// A single bar in a bar-chart preview, used for list pages like market caps.
class PreviewBar {
  const PreviewBar({
    required this.label,
    required this.value,
    required this.valueLabel,
  });

  /// Short label drawn next to the bar, e.g. "AAPL".
  final String label;

  /// Bar length, relative to the other bars.
  final double value;

  /// Formatted value drawn at the end of the bar, e.g. "\$5.03T".
  final String valueLabel;
}

/// How the headline change is expressed.
enum PreviewChangeMode {
  /// Relative change, e.g. "+2.79%".
  percent,

  /// Absolute change, e.g. "+0.12 pts" (bond rates).
  points,
}

/// Everything the preview renderer needs, decoupled from the wire models so
/// the app and the server can both build it.
class PreviewData {
  const PreviewData({
    required this.title,
    required this.subtitle,
    required this.value,
    this.unit = '',
    this.change = '',
    this.isGain = true,
    this.windowLabel = '',
    this.series = const [],
    this.bars = const [],
  });

  /// Short display name, e.g. "Gold".
  final String title;

  /// Longer description, e.g. "Gold Dec 26".
  final String subtitle;

  /// Compact headline value, e.g. "3.90K".
  final String value;

  /// Unit shown next to [value], e.g. "USD", "T USD", "%".
  final String unit;

  /// Change over [series], already formatted, e.g. "-3.42%".
  final String change;

  final bool isGain;

  /// Label for the charted window, e.g. "7d".
  final String windowLabel;

  /// The line chart's points. Ignored when [bars] is not empty.
  final List<PreviewPoint> series;

  /// Bars to draw instead of a line chart (e.g. a market cap ranking).
  final List<PreviewBar> bars;

  /// Builds preview data from a ticker result, charting the last [days] days.
  ///
  /// Sparse series (e.g. a monthly "max" range) have fewer than two points in
  /// the window; those fall back to the whole series so the chart always has a
  /// curve, and the window label reflects what is actually plotted.
  factory PreviewData.fromTicker(
    CustomTickerResult result, {
    String? title,
    int days = 7,
    int maxPoints = 240,
  }) {
    final sorted = [...result.priceData]
      ..sort((a, b) => a.date.compareTo(b.date));
    final cutoff =
        sorted.isEmpty ? null : sorted.last.date.subtract(Duration(days: days));
    final windowed =
        cutoff == null
            ? const <AmountEntry>[]
            : sorted.where((e) => e.date.isAfter(cutoff)).toList();
    final selected = windowed.length >= 2 ? windowed : sorted;
    final points = _downsample(selected, maxPoints);

    final first = points.isEmpty ? null : points.first.amount;
    final last = points.isEmpty ? null : points.last.amount;
    final changePercent =
        (first == null || last == null || first == 0)
            ? 0.0
            : (last - first) / first * 100;
    final isGain = changePercent >= 0;
    final sign = isGain ? '+' : '';

    return PreviewData(
      title: title?.isNotEmpty == true ? title! : result.shortName,
      subtitle:
          result.longName.isNotEmpty
              ? result.longName
              : [
                result.ticker1,
                if (result.ticker2 != null && result.ticker2!.isNotEmpty)
                  result.ticker2!,
              ].join(' / '),
      value: formatCompactAmount(last ?? 0),
      unit: result.currency,
      change: '$sign${changePercent.toStringAsFixed(2)}%',
      isGain: isGain,
      windowLabel:
          points.length >= 2
              ? spanLabel(points.first.time, points.last.time)
              : '${days}d',
      series: points,
    );
  }

  /// Builds preview data for an amount series (M2, debt, bond rates, indices,
  /// futures), optionally clipped to [range].
  ///
  /// Sparse series (e.g. monthly data on a one-month zoom) have fewer than two
  /// points in the window; those fall back to the whole series so the chart
  /// always has a curve.
  factory PreviewData.fromSeries({
    required String title,
    required String subtitle,
    required List<AmountEntry> data,
    required String unit,
    DataRange? range,
    PreviewChangeMode changeMode = PreviewChangeMode.percent,
    int maxPoints = 240,
  }) {
    final sorted = [...data]..sort((a, b) => a.date.compareTo(b.date));
    final windowed = _window(sorted, range);
    final selected = windowed.length >= 2 ? windowed : sorted;
    final points = _downsample(selected, maxPoints);

    final first = points.isEmpty ? null : points.first.amount;
    final last = points.isEmpty ? null : points.last.amount;
    final isGain = (last ?? 0) >= (first ?? 0);
    final sign = isGain ? '+' : '';

    final change = switch (changeMode) {
      PreviewChangeMode.percent =>
        first == null || last == null || first == 0
            ? '0.00%'
            : '$sign${((last - first) / first * 100).toStringAsFixed(2)}%',
      PreviewChangeMode.points =>
        first == null || last == null
            ? '0.00 pts'
            : '$sign${(last - first).toStringAsFixed(2)} pts',
    };

    return PreviewData(
      title: title,
      subtitle: subtitle,
      value: formatCompactAmount(last ?? 0),
      unit: unit,
      change: change,
      isGain: isGain,
      windowLabel:
          points.length >= 2
              ? spanLabel(points.first.time, points.last.time)
              : '',
      series: points,
    );
  }

  /// Builds a bar-chart preview for a list of market caps.
  factory PreviewData.fromMarketCap({
    required String title,
    required String subtitle,
    required List<MarketOverviewEntry> entries,
    int maxBars = 6,
  }) {
    final sorted = [...entries]
      ..sort((a, b) => b.marketCap.compareTo(a.marketCap));
    final total = sorted.fold<double>(0, (sum, entry) => sum + entry.marketCap);
    return PreviewData(
      title: title,
      subtitle: subtitle,
      value: formatCompactMoney(total),
      bars: [
        for (final entry in sorted.take(maxBars))
          PreviewBar(
            label: entry.ticker.toUpperCase(),
            value: entry.marketCap,
            valueLabel: formatCompactMoney(entry.marketCap),
          ),
      ],
    );
  }

  /// Filters [entries] to [range], measured back from the latest data point.
  ///
  /// Using the last point rather than `DateTime.now()` keeps previews stable
  /// for cached or slow sources.
  static List<AmountEntry> _window(
    List<AmountEntry> entries,
    DataRange? range,
  ) {
    if (range == null || range == DataRange.max || entries.isEmpty) {
      return entries;
    }
    final years = switch (range) {
      DataRange.oneDay => 1 / 365,
      DataRange.fiveDays => 5 / 365,
      DataRange.oneMonth => 1 / 12,
      DataRange.threeMonths => 3 / 12,
      DataRange.sixMonths => 6 / 12,
      DataRange.oneYear => 1,
      DataRange.twoYears => 2,
      DataRange.fiveYears => 5,
      DataRange.tenYears => 10,
      DataRange.max => throw StateError('handled above'),
    };
    final cutoff = entries.last.date.subtract(
      Duration(days: (years * 365).toInt()),
    );
    return entries.where((e) => e.date.isAfter(cutoff)).toList();
  }

  static List<PreviewPoint> _downsample(
    List<AmountEntry> entries,
    int maxPoints,
  ) {
    if (entries.length <= maxPoints) {
      return entries
          .map((e) => PreviewPoint(time: e.date, amount: e.amount))
          .toList();
    }
    final step = entries.length / maxPoints;
    return [
      for (var i = 0; i < maxPoints; i++)
        PreviewPoint(
          time: entries[(i * step).floor()].date,
          amount: entries[(i * step).floor()].amount,
        ),
    ];
  }
}

/// Human label for the time between [from] and [to], e.g. "7d" or "26y".
String spanLabel(DateTime from, DateTime to) {
  final days = to.difference(from).inDays;
  if (days <= 1) return '1d';
  if (days < 60) return '${days}d';
  if (days < 730) return '${(days / 30).round()}mo';
  return '${(days / 365).round()}y';
}

/// Mirrors the app's compact amount formatting ("7.61K", "1.20M", "3.40T").
String formatCompactAmount(double value) {
  if (value >= 1e12) return '${(value / 1e12).toStringAsFixed(2)}T';
  if (value >= 1e9) return '${(value / 1e9).toStringAsFixed(2)}B';
  if (value >= 1e6) return '${(value / 1e6).toStringAsFixed(2)}M';
  if (value >= 1e3) return '${(value / 1e3).toStringAsFixed(2)}K';
  return value.toStringAsFixed(2);
}

/// Compact dollar amount, e.g. "\$5.03T".
String formatCompactMoney(double value) => '\$${formatCompactAmount(value)}';
