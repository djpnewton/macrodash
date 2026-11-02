import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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
