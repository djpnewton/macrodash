import 'package:flutter/material.dart';

class SparkPainter extends CustomPainter {
  final List<num?> values;
  final List<int>? timestamps;
  final Color colorUp;
  final Color colorDown;

  SparkPainter(
    this.values, {
    this.timestamps,
    this.colorUp = Colors.green,
    this.colorDown = Colors.red,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // set colors
    var firstValue = values.firstWhere(
      (element) => element != null,
      orElse: () => 0,
    );
    var lastValue = values.lastWhere(
      (element) => element != null,
      orElse: () => 0,
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
          // ignore: deprecated_member_use
          ..color = color.withOpacity(0.5);
    canvas.drawPath(fillPath, fillPaint);

    // Draw the sparkline path with opaque color
    final linePaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = color;
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(SparkPainter oldDelegate) => false;
}
