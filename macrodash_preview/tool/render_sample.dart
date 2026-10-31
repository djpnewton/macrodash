import 'dart:io';
import 'dart:math';

import 'package:macrodash_models/models.dart';
import 'package:macrodash_preview/macrodash_preview.dart';

/// Renders a sample preview to /tmp/preview.png for eyeballing layout changes:
///
///     dart run tool/render_sample.dart
Future<void> main(List<String> args) async {
  final output = args.isNotEmpty ? args.first : '/tmp/preview.png';
  final random = Random(7);
  final start = DateTime(2026, 10, 25, 9);
  var value = 1150.0;
  final priceData = <AmountEntry>[
    for (var i = 0; i < 420; i++)
      AmountEntry(
        date: start.add(Duration(minutes: 20 * i)),
        amount: value += (random.nextDouble() - 0.45) * 9,
      ),
  ];

  final result = CustomTickerResult(
    ticker1: 'GC=F',
    ticker2: null,
    shortName: 'GC=F',
    longName: 'Gold Dec 26',
    sources: const ['https://finance.yahoo.com/'],
    priceData: priceData,
    dividendData: const [],
    currency: 'USD',
  );

  final png = await renderTickerPreviewPng(
    TickerPreviewData.fromTicker(result, title: 'Gold'),
  );
  File(output).writeAsBytesSync(png);
  stdout.writeln('wrote $output (${png.length} bytes)');
}
