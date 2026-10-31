import 'dart:math' as math;
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pcanvas/pcanvas.dart';

import 'palette.dart';
import 'ticker_preview.dart';

const int defaultPreviewWidth = 1200;
const int defaultPreviewHeight = 630;

/// Renders the link-preview card as a PNG.
///
/// Pure Dart (no Flutter), so the same code renders on the server and in the
/// app. The in-memory canvas only supports bitmap fonts (arial 14/24/48) and
/// stroked paths, so everything here is built from those primitives.
Future<Uint8List> renderPreviewPng(
  PreviewData data, {
  int width = defaultPreviewWidth,
  int height = defaultPreviewHeight,
}) async {
  final canvas = PCanvas(width, height, _TickerPreviewPainter(data));
  await canvas.waitLoading();
  canvas.callPainter();
  return canvas.toPNG();
}

PColor _color(int argb) =>
    PColorRGB((argb >> 16) & 0xff, (argb >> 8) & 0xff, argb & 0xff);

PColor _blend(int background, int foreground, double amount) {
  int channel(int shift) {
    final a = (background >> shift) & 0xff;
    final b = (foreground >> shift) & 0xff;
    return (a + (b - a) * amount).round().clamp(0, 255);
  }

  return PColorRGB(channel(16), channel(8), channel(0));
}

class _TickerPreviewPainter extends PCanvasPainter {
  _TickerPreviewPainter(this.data);

  final PreviewData data;

  static final _ink = _color(MacroDashPalette.ink);
  static final _muted = _color(MacroDashPalette.muted);
  static final _subtle = _color(MacroDashPalette.subtle);
  static final _grid = _color(MacroDashPalette.grid);
  static final _emerald = _color(MacroDashPalette.emerald300);
  static final _emeraldLight = _color(MacroDashPalette.emeraldLight);

  @override
  bool paint(PCanvas canvas) {
    final width = canvas.width.toDouble();
    final height = canvas.height.toDouble();

    canvas.fillTopDownGradient(
      0,
      0,
      width,
      height,
      _color(MacroDashPalette.navy700),
      _color(MacroDashPalette.navy800),
    );

    _paintMark(canvas, 80, 74, 96);
    _paintHeader(canvas);
    if (data.bars.isNotEmpty) {
      _paintBars(canvas, left: 150, top: 318, right: width - 80, bottom: 540);
    } else {
      _paintChart(canvas, left: 150, top: 318, right: width - 80, bottom: 540);
    }
    _paintFooter(canvas, height);

    return true;
  }

  /// The "M" chart-line monogram from assets/macrodash.svg.
  void _paintMark(PCanvas canvas, double x, double y, double size) {
    Point p(double svgX, double svgY) =>
        Point(x + svgX / 64 * size, y + svgY / 64 * size);

    final points = [p(15, 48), p(15, 22), p(32, 38), p(49, 16), p(49, 48)];
    _strokeThick(canvas, points, 9, _emerald);
    for (final (svgX, svgY) in [(15, 22), (49, 16)]) {
      final c = p(svgX.toDouble(), svgY.toDouble());
      canvas.fillCircle(c.x, c.y, 5, PStyle(color: _emeraldLight));
    }
  }

  void _paintHeader(PCanvas canvas) {
    const left = 205.0;
    final brand = PFont('Arial', 24, bold: true);
    final large = PFont('Arial', 48, bold: true);
    final small = PFont('Arial', 24);

    canvas.drawText('MacroDash', left, 78, brand, PStyle(color: _subtle));
    canvas.drawText(data.title, left, 112, large, PStyle(color: _ink));
    canvas.drawText(data.subtitle, left, 172, small, PStyle(color: _muted));

    canvas.drawText(data.value, left, 208, large, PStyle(color: _ink));
    final valueWidth = canvas.measureText(data.value, large).actualWidth;

    final currencyFont = PFont('Arial', 24);
    final changeFont = PFont('Arial', 24, bold: true);
    var nextX = left + valueWidth + 12;
    final changeColor = _color(
      data.isGain ? MacroDashPalette.emerald300 : MacroDashPalette.loss,
    );

    // The bitmap fonts have different ascent/descent, so align on the bottom
    // of a common baseline row instead of the glyph box top.
    const baseline = 232.0;
    void drawAligned(String text, double x, PFont font, PColor color) {
      final height = canvas.measureText(text, font).actualHeight;
      canvas.drawText(text, x, baseline - height, font, PStyle(color: color));
    }

    if (data.unit.isNotEmpty) {
      drawAligned(data.unit, nextX, currencyFont, _muted);
      nextX += canvas.measureText(data.unit, currencyFont).actualWidth + 26;
    }
    if (data.change.isNotEmpty) {
      final change =
          data.windowLabel.isEmpty
              ? data.change
              : '${data.change} (${data.windowLabel})';
      drawAligned(change, nextX, changeFont, changeColor);
    }
  }

  /// Horizontal bars for list previews (market caps), one row per bar.
  void _paintBars(
    PCanvas canvas, {
    required double left,
    required double top,
    required double right,
    required double bottom,
  }) {
    final bars = data.bars;
    final maxValue = bars.fold<double>(
      0,
      (max, bar) => math.max(max, bar.value),
    );
    if (bars.isEmpty || maxValue <= 0) return;

    final rowHeight = (bottom - top) / bars.length;
    final barHeight = math.min(rowHeight * 0.55, 34.0);
    final barRight = right - 130;
    final labelFont = PFont('Arial', 24);
    final valueFont = PFont('Arial', 14);
    final barColor = _color(MacroDashPalette.emerald500);

    for (var i = 0; i < bars.length; i++) {
      final bar = bars[i];
      final y = top + i * rowHeight + (rowHeight - barHeight) / 2;
      final barWidth = (barRight - left) * (bar.value / maxValue);
      canvas.fillRect(
        left,
        y,
        barWidth < 1 ? 1.0 : barWidth,
        barHeight,
        PStyle(color: barColor),
      );

      final labelWidth = canvas.measureText(bar.label, labelFont).actualWidth;
      final labelHeight = canvas.measureText(bar.label, labelFont).actualHeight;
      canvas.drawText(
        bar.label,
        left - 12 - labelWidth,
        y + (barHeight - labelHeight) / 2,
        labelFont,
        PStyle(color: _ink),
      );
      canvas.drawText(
        bar.valueLabel,
        left + barWidth + 10,
        y + barHeight / 2 - 7,
        valueFont,
        PStyle(color: _muted),
      );
    }
  }

  void _paintChart(
    PCanvas canvas, {
    required double left,
    required double top,
    required double right,
    required double bottom,
  }) {
    final series = data.series;
    if (series.length < 2) return;

    canvas.strokePath([
      Point(left, top),
      Point(right, top),
    ], PStyle(color: _grid));
    canvas.strokePath([
      Point(left, bottom),
      Point(right, bottom),
    ], PStyle(color: _grid));

    var minValue = series.first.amount;
    var maxValue = series.first.amount;
    for (final point in series) {
      minValue = math.min(minValue, point.amount);
      maxValue = math.max(maxValue, point.amount);
    }
    if (minValue == maxValue) {
      minValue -= 1;
      maxValue += 1;
    }
    final span = maxValue - minValue;

    double yFor(double value) =>
        bottom - (value - minValue) / span * (bottom - top);
    double xFor(int index) =>
        left + (right - left) * index / (series.length - 1);

    final dayFont = PFont('Arial', 14);
    final spanDays = series.last.time.difference(series.first.time).inDays;
    if (spanDays <= 31) {
      // Short windows: one vertical line per day, labelled with the weekday.
      // The first day sits on the left axis, so it gets no line or label.
      final firstIndexByDay = <String, int>{};
      for (var i = 0; i < series.length; i++) {
        final day = DateFormat('yyyy-MM-dd').format(series[i].time);
        firstIndexByDay.putIfAbsent(day, () => i);
      }
      for (final entry in firstIndexByDay.entries) {
        if (entry.value == 0) continue;
        final x = xFor(entry.value);
        canvas.strokePath([
          Point(x, top),
          Point(x, bottom),
        ], PStyle(color: _grid));
        final label = DateFormat('E').format(series[entry.value].time);
        final labelWidth = canvas.measureText(label, dayFont).actualWidth;
        final labelLeft = x - labelWidth / 2;
        if (labelLeft < left) continue;
        canvas.drawText(
          label,
          labelLeft,
          bottom + 6,
          dayFont,
          PStyle(color: _muted),
        );
      }
    } else {
      // Long windows (months/years): a handful of date ticks instead of one
      // per point, which would overlap.
      const tickCount = 6;
      final format = DateFormat(spanDays > 730 ? 'yyyy' : 'yyyy-MM');
      for (var i = 1; i < tickCount; i++) {
        final index = (series.length - 1) * i ~/ tickCount;
        if (index <= 0) continue;
        final x = xFor(index);
        canvas.strokePath([
          Point(x, top),
          Point(x, bottom),
        ], PStyle(color: _grid));
        final label = format.format(series[index].time);
        final labelWidth = canvas.measureText(label, dayFont).actualWidth;
        final labelLeft = x - labelWidth / 2;
        if (labelLeft < left) continue;
        canvas.drawText(
          label,
          labelLeft,
          bottom + 6,
          dayFont,
          PStyle(color: _muted),
        );
      }
    }

    final lineColor = _color(
      data.isGain ? MacroDashPalette.emerald300 : MacroDashPalette.loss,
    );
    final fillColor = _blend(
      MacroDashPalette.navy800,
      data.isGain ? MacroDashPalette.emerald300 : MacroDashPalette.loss,
      0.22,
    );

    // Area fill: the in-memory canvas has no path filling, so fill a column per
    // x pixel between the curve and the baseline.
    final points = [
      for (var i = 0; i < series.length; i++)
        Point(xFor(i), yFor(series[i].amount)),
    ];
    for (var i = 1; i < points.length; i++) {
      final p0 = points[i - 1];
      final p1 = points[i];
      final startX = p0.x.floor();
      final endX = p1.x.ceil();
      for (var x = startX; x < endX; x++) {
        final t = (x - p0.x) / (p1.x - p0.x);
        final y = p0.y + (p1.y - p0.y) * t;
        canvas.fillRect(
          x.toDouble(),
          y,
          1,
          bottom - y,
          PStyle(color: fillColor),
        );
      }
    }

    canvas.strokePath(points, PStyle(color: lineColor));

    // Price labels in the left gutter, centred on the grid lines.
    final priceFont = PFont('Arial', 14);
    for (final (label, y) in [
      (formatCompactAmount(maxValue), top),
      (formatCompactAmount(minValue), bottom),
    ]) {
      final labelWidth = canvas.measureText(label, priceFont).actualWidth;
      canvas.drawText(
        label,
        left - 12 - labelWidth,
        y - 14,
        priceFont,
        PStyle(color: _muted),
      );
    }
  }

  void _paintFooter(PCanvas canvas, double height) {
    canvas.drawText(
      'macrodash.me',
      80,
      height - 44,
      PFont('Arial', 14),
      PStyle(color: _subtle),
    );
  }

  /// The bitmap canvas strokes 1px paths, so thick lines are "painted" by
  /// stamping a filled circle along the path.
  void _strokeThick(
    PCanvas canvas,
    List<Point> points,
    int width,
    PColor color,
  ) {
    final style = PStyle(color: color);
    final radius = width / 2;
    for (var i = 1; i < points.length; i++) {
      final from = points[i - 1];
      final to = points[i];
      final dx = to.x - from.x;
      final dy = to.y - from.y;
      final steps = math.max(math.sqrt(dx * dx + dy * dy).ceil(), 1);
      for (var step = 0; step <= steps; step++) {
        canvas.fillCircle(
          from.x + dx * step / steps,
          from.y + dy * step / steps,
          radius,
          style,
        );
      }
    }
  }
}
