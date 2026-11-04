import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import 'helper.dart';
import 'theme.dart';

class SparkPainter extends CustomPainter {
  final List<num?> values;
  final List<int>? timestamps;
  final Color colorUp;
  final Color colorDown;
  final double strokeWidth;
  final double fillOpacity;

  SparkPainter(
    this.values, {
    this.timestamps,
    this.colorUp = Colors.green,
    this.colorDown = Colors.red,
    this.strokeWidth = 1,
    this.fillOpacity = 0.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    /*
    // draw outline of box
    final outlinePaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Colors.grey.withOpacity(0.2);
    canvas.drawRect(Rect.fromLTRB(0, 0, size.width, size.height), outlinePaint);
    */
    // set colors
    var firstValue = values.firstWhere(
      (element) => element != null,
      orElse: () => 0.0,
    );
    var lastValue = values.lastWhere(
      (element) => element != null,
      orElse: () => 0.0,
    );
    var color = firstValue! < lastValue! ? colorUp : colorDown;

    // Find min and max
    var yMin = double.infinity;
    var yMax = double.negativeInfinity;
    for (var v in values) {
      if (v != null) {
        if (yMax < v) yMax = v.toDouble();
        if (yMin > v) yMin = v.toDouble();
      }
    }
    if (yMin == yMax) {
      yMin -= 1;
      yMax += 1;
    }
    var yRange = yMax - yMin;
    var xInc = size.width / (values.length - 1);

    // Generate the sparkline path
    final path = Path();
    double xCur = 0.0;
    bool first = true;
    for (var i = 0; i < values.length; i++) {
      var v = values[i];
      if (v != null) {
        var y = size.height - ((v - yMin) / yRange * size.height);
        if (first) {
          path.moveTo(xCur, y);
          first = false;
        } else {
          path.lineTo(xCur, y);
        }
      }
      xCur += xInc;
    }

    // Create a fill path by closing the sparkline to the bottom
    final fillPath = Path.from(path);
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

    // Draw the fill with 50% opacity
    final fillPaint =
        Paint()
          ..style = PaintingStyle.fill
          ..color = color.withValues(alpha: fillOpacity);
    canvas.drawPath(fillPath, fillPaint);

    // Draw the sparkline path with opaque color
    final linePaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..color = color;
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(SparkPainter oldDelegate) =>
      strokeWidth != oldDelegate.strokeWidth ||
      fillOpacity != oldDelegate.fillOpacity ||
      colorUp != oldDelegate.colorUp ||
      colorDown != oldDelegate.colorDown ||
      timestamps != oldDelegate.timestamps ||
      values != oldDelegate.values;
}

/// Width-to-height ratio of the sparkline thumbnails (100x25).
const double sparklineAspectRatio = 100 / 25;

/// A sparkline that keeps [sparklineAspectRatio] at any size, centred in the
/// available space so large views are not stretched.
class SparkChart extends StatelessWidget {
  const SparkChart({super.key, required this.painter});

  final CustomPainter painter;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AspectRatio(
        aspectRatio: sparklineAspectRatio,
        child: CustomPaint(painter: painter),
      ),
    );
  }
}

/// A sparkline with a light grid: one vertical line per day and the top/bottom
/// of the value range labelled in a gutter on the left.
class SparkChartPainter extends SparkPainter {
  SparkChartPainter(
    super.values, {
    super.timestamps,
    super.colorUp,
    super.colorDown,
    super.strokeWidth,
    super.fillOpacity,
    this.dayFractions = const [],
    this.dayLabels = const [],
    this.topLabel,
    this.bottomLabel,
    required this.gridColor,
    required this.labelStyle,
  });

  /// Horizontal position (0..1 of the plot width) of each day's grid line.
  final List<double> dayFractions;

  /// Labels drawn under [dayFractions], e.g. "Mon".
  final List<String> dayLabels;

  final String? topLabel;
  final String? bottomLabel;
  final Color gridColor;
  final TextStyle labelStyle;

  static const double _topPadding = 10;
  static const double _bottomPadding = 24;
  static const double _labelGap = 8;

  TextPainter _layoutLabel(String text) => TextPainter(
    text: TextSpan(text: text, style: labelStyle),
    textDirection: TextDirection.ltr,
  )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    var gutter = 0.0;
    for (final label in [topLabel, bottomLabel]) {
      if (label == null) continue;
      gutter = math.max(gutter, _layoutLabel(label).width);
    }
    if (gutter > 0) gutter += _labelGap;

    final plot = Rect.fromLTRB(
      gutter,
      _topPadding,
      size.width,
      size.height - _bottomPadding,
    );
    if (plot.width <= 0 || plot.height <= 0) return;

    final gridPaint =
        Paint()
          ..color = gridColor
          ..strokeWidth = 1;

    canvas.drawLine(plot.topLeft, plot.topRight, gridPaint);
    canvas.drawLine(plot.bottomLeft, plot.bottomRight, gridPaint);
    for (final fraction in dayFractions) {
      // A day starting at 0 sits on the left axis, so it needs no line of its own.
      if (fraction <= 0) continue;
      final x = plot.left + fraction * plot.width;
      canvas.drawLine(Offset(x, plot.top), Offset(x, plot.bottom), gridPaint);
    }

    void paintPrice(String? label, double lineY) {
      if (label == null) return;
      final text = _layoutLabel(label);
      text.paint(
        canvas,
        Offset(plot.left - _labelGap - text.width, lineY - text.height / 2),
      );
    }

    paintPrice(topLabel, plot.top);
    paintPrice(bottomLabel, plot.bottom);

    for (var i = 0; i < dayLabels.length && i < dayFractions.length; i++) {
      final text = _layoutLabel(dayLabels[i]);
      final left = plot.left + dayFractions[i] * plot.width - text.width / 2;
      // Skip labels that would spill into the price gutter on the left; the
      // first day always lands there and the axis already marks the start.
      if (left < plot.left) continue;
      final x = left.clamp(0.0, size.width - text.width);
      text.paint(canvas, Offset(x, plot.bottom + 5));
    }

    canvas.save();
    canvas.translate(plot.left, plot.top);
    canvas.clipRect(Rect.fromLTWH(0, 0, plot.width, plot.height));
    super.paint(canvas, plot.size);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SparkChartPainter oldDelegate) =>
      super.shouldRepaint(oldDelegate) ||
      gridColor != oldDelegate.gridColor ||
      labelStyle != oldDelegate.labelStyle ||
      topLabel != oldDelegate.topLabel ||
      bottomLabel != oldDelegate.bottomLabel ||
      !listEquals(dayFractions, oldDelegate.dayFractions) ||
      !listEquals(dayLabels, oldDelegate.dayLabels);
}

/// Shows a full-screen view of a sparkline series.
///
/// [values] and [timestamps] are the same series as the thumbnail; the large
/// view adds a grid line per day plus the min/max price labels.
Future<void> showLargeSparkline(
  BuildContext context, {
  required String title,
  String? subtitle,
  String? priceText,
  String? secondaryText,
  double? changePercent24h,
  required List<num?> values,
  List<int>? timestamps,
  String note = 'Last 7 days',
}) {
  if (values.length < 2) {
    return Future<void>.value();
  }
  final colors = context.appColors;

  // One grid line per day covered by the sparkline.
  final dayFractions = <double>[];
  final dayLabels = <String>[];
  if (timestamps != null && timestamps.length == values.length) {
    final firstIndexByDay = <int, int>{};
    for (var i = 0; i < timestamps.length; i++) {
      final date = DateTime.fromMillisecondsSinceEpoch(timestamps[i]);
      final day = DateTime(date.year, date.month, date.day);
      firstIndexByDay.putIfAbsent(day.millisecondsSinceEpoch, () => i);
    }
    final days = firstIndexByDay.entries.toList();
    int countFor(int d) =>
        (d + 1 < days.length ? days[d + 1].value : values.length) -
        days[d].value;
    var fullDay = 0;
    for (var d = 0; d < days.length; d++) {
      fullDay = math.max(fullDay, countFor(d));
    }
    for (var d = 0; d < days.length; d++) {
      // Skip days without full data (e.g. a Sunday-evening open); the first
      // and last days are partial by nature of the window, so keep them.
      if (d > 0 && d < days.length - 1 && countFor(d) < fullDay * 0.5) {
        continue;
      }
      dayFractions.add(days[d].value / (values.length - 1));
      dayLabels.add(
        DateFormat(
          'E',
        ).format(DateTime.fromMillisecondsSinceEpoch(days[d].key)),
      );
    }
  }

  var maxValue = double.negativeInfinity;
  var minValue = double.infinity;
  for (final value in values) {
    if (value == null) continue;
    final amount = value.toDouble();
    if (amount > maxValue) maxValue = amount;
    if (amount < minValue) minValue = amount;
  }
  String? priceLabel(double value) =>
      value.isFinite ? formatPrice(value, currencyChar: '', space: '') : null;

  final isUp = (changePercent24h ?? 0) >= 0;
  final changeColor = isUp ? colors.gain : colors.loss;
  final changePrefix = isUp ? '+' : '';

  return showDialog<void>(
    context: context,
    builder:
        (dialogContext) => Dialog.fullscreen(
          child: Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Close',
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
              title: Text(title),
            ),
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (subtitle != null) ...[
                      Text(
                        subtitle,
                        style: Theme.of(dialogContext).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                    ],
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        if (priceText != null)
                          Text(
                            priceText,
                            style:
                                Theme.of(dialogContext).textTheme.headlineSmall,
                          ),
                        if (secondaryText != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            secondaryText,
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  Theme.of(
                                    dialogContext,
                                  ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        if (changePercent24h != null) ...[
                          const SizedBox(width: 12),
                          Text(
                            '$changePrefix${changePercent24h.toStringAsFixed(2)}%',
                            style: TextStyle(fontSize: 16, color: changeColor),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '24h',
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  Theme.of(
                                    dialogContext,
                                  ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: SparkChart(
                        painter: SparkChartPainter(
                          values,
                          timestamps: timestamps,
                          colorUp: colors.gain,
                          colorDown: colors.loss,
                          strokeWidth: 2,
                          fillOpacity: 0.2,
                          dayFractions: dayFractions,
                          dayLabels: dayLabels,
                          topLabel: priceLabel(maxValue),
                          bottomLabel: priceLabel(minValue),
                          gridColor:
                              Theme.of(
                                dialogContext,
                              ).colorScheme.outlineVariant,
                          labelStyle: TextStyle(
                            fontSize: 11,
                            color:
                                Theme.of(
                                  dialogContext,
                                ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        note,
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              Theme.of(
                                dialogContext,
                              ).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
  );
}
