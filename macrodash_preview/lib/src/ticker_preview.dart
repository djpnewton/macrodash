import 'package:macrodash_models/models.dart';

/// A single point of the preview chart.
class PreviewPoint {
  const PreviewPoint({required this.time, required this.amount});

  final DateTime time;
  final double amount;
}

/// Everything the preview renderer needs, decoupled from the wire models so
/// the app and the server can both build it.
class TickerPreviewData {
  const TickerPreviewData({
    required this.title,
    required this.subtitle,
    required this.price,
    required this.currency,
    required this.change,
    required this.isGain,
    required this.windowLabel,
    required this.series,
  });

  /// Short display name, e.g. "Gold".
  final String title;

  /// Longer description, e.g. "Gold Dec 26".
  final String subtitle;

  /// Compact price, e.g. "3.90K".
  final String price;

  final String currency;

  /// Change over [series], already formatted, e.g. "-3.42%".
  final String change;

  final bool isGain;

  /// Label for the charted window, e.g. "7d".
  final String windowLabel;

  final List<PreviewPoint> series;

  /// Builds preview data from a ticker result, charting the last [days] days.
  ///
  /// Sparse series (e.g. a monthly "max" range) have fewer than two points in
  /// the window; those fall back to the whole series so the chart always has a
  /// curve, and the window label reflects what is actually plotted.
  factory TickerPreviewData.fromTicker(
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

    return TickerPreviewData(
      title: title?.isNotEmpty == true ? title! : result.shortName,
      subtitle:
          result.longName.isNotEmpty
              ? result.longName
              : [
                result.ticker1,
                if (result.ticker2 != null && result.ticker2!.isNotEmpty)
                  result.ticker2!,
              ].join(' / '),
      price: formatCompactAmount(last ?? 0),
      currency: result.currency,
      change: '$sign${changePercent.toStringAsFixed(2)}%',
      isGain: isGain,
      windowLabel:
          points.length >= 2
              ? spanLabel(points.first.time, points.last.time)
              : '${days}d',
      series: points,
    );
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

/// Mirrors the app's compact price formatting ("7.61K", "1.20M").
String formatCompactAmount(double value) {
  if (value >= 1e6) return '${(value / 1e6).toStringAsFixed(2)}M';
  if (value >= 1e3) return '${(value / 1e3).toStringAsFixed(2)}K';
  return value.toStringAsFixed(2);
}
