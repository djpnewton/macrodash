import 'package:macrodash_models/models.dart';
import 'package:macrodash_preview/macrodash_preview.dart';
import 'package:test/test.dart';

CustomTickerResult ticker({
  int points = 60,
  DateTime? start,
  List<double>? amounts,
}) {
  final from = start ?? DateTime(2026, 10, 25, 9);
  final values =
      amounts ?? [for (var i = 0; i < points; i++) 100.0 + i.toDouble()];
  return CustomTickerResult(
    ticker1: 'GC=F',
    ticker2: null,
    shortName: 'GC=F',
    longName: 'Gold Dec 26',
    sources: const ['https://finance.yahoo.com/'],
    priceData: [
      for (var i = 0; i < values.length; i++)
        AmountEntry(date: from.add(Duration(hours: i)), amount: values[i]),
    ],
    dividendData: const [],
    currency: 'USD',
  );
}

void main() {
  group('tickerAppUrl', () {
    test('encodes the ticker and keeps the app hash route', () {
      expect(
        tickerAppUrl(
          appUrl: 'https://macrodash.me/',
          ticker1: 'GC=F',
          params: {'title': 'Gold'},
        ),
        'https://macrodash.me/#/ticker?ticker1=GC%3DF&title=Gold',
      );
    });

    test('includes ticker2 and range when present', () {
      expect(
        tickerAppUrl(
          appUrl: 'https://macrodash.me',
          ticker1: 'BTC-USD',
          params: {'ticker2': 'GC=F', 'zoom': 'oneYear'},
        ),
        'https://macrodash.me/#/ticker?ticker1=BTC-USD&ticker2=GC%3DF&zoom=oneYear',
      );
    });
  });

  group('tickerShareUrl', () {
    test('puts the ticker in the path, not the query', () {
      expect(
        tickerShareUrl(
          previewUrl: 'https://ln.macrodash.me/',
          ticker1: 'BTC-USD',
          params: {'title': 'Bitcoin'},
        ),
        'https://ln.macrodash.me/t/BTC-USD?title=Bitcoin',
      );
    });

    test('encodes index tickers', () {
      expect(
        tickerShareUrl(previewUrl: 'https://ln.macrodash.me', ticker1: '^GSPC'),
        'https://ln.macrodash.me/t/%5EGSPC',
      );
    });
  });

  group('TickerPreviewData', () {
    test('keeps only the requested window and reports the change', () {
      final data = TickerPreviewData.fromTicker(
        ticker(points: 24 * 10),
        title: 'Gold',
        days: 7,
      );

      expect(data.title, 'Gold');
      expect(data.subtitle, 'Gold Dec 26');
      expect(data.currency, 'USD');
      // The window covers the last 7 days; the plotted span is 6d of points.
      expect(data.series.length, lessThanOrEqualTo(7 * 24 + 1));
      expect(data.isGain, isTrue);
      expect(data.change, startsWith('+'));
      expect(data.windowLabel, '6d');
    });

    test('falls back to the ticker symbols when there is no long name', () {
      final result = CustomTickerResult(
        ticker1: 'BTC-USD',
        ticker2: 'GC=F',
        shortName: 'BTC-USD',
        longName: '',
        sources: const [],
        priceData: [AmountEntry(date: DateTime(2026, 10, 25), amount: 1)],
        dividendData: const [],
        currency: 'USD',
      );
      expect(TickerPreviewData.fromTicker(result).subtitle, 'BTC-USD / GC=F');
    });

    test('downsamples long series', () {
      final data = TickerPreviewData.fromTicker(ticker(points: 5000));
      expect(data.series.length, lessThanOrEqualTo(240));
    });

    test('falls back to the whole series when the window is too sparse', () {
      // Monthly points over ~26 years, like a "max" range.
      final monthly = ticker(
        amounts: [for (var i = 0; i < 312; i++) 100.0 + i.toDouble()],
        start: DateTime(2000, 9, 1),
      );
      final sparse = CustomTickerResult(
        ticker1: monthly.ticker1,
        ticker2: null,
        shortName: monthly.shortName,
        longName: monthly.longName,
        sources: monthly.sources,
        priceData: [
          for (var i = 0; i < 312; i++)
            AmountEntry(
              date: DateTime(2000, 9 + i, 1),
              amount: 100.0 + i.toDouble(),
            ),
        ],
        dividendData: const [],
        currency: 'USD',
      );

      final data = TickerPreviewData.fromTicker(sparse);
      expect(data.series.length, greaterThan(2), reason: 'chart needs a curve');
      expect(data.windowLabel, endsWith('y'));
      expect(data.change, isNot('+0.00%'));
    });

    test('labels the window from the plotted span', () {
      expect(spanLabel(DateTime(2026, 10, 25), DateTime(2026, 11, 1)), '7d');
      expect(spanLabel(DateTime(2026, 1, 1), DateTime(2026, 6, 1)), '5mo');
      expect(spanLabel(DateTime(2000, 1, 1), DateTime(2026, 1, 1)), '26y');
    });
  });

  test('renders a png', () async {
    final png = await renderTickerPreviewPng(
      TickerPreviewData.fromTicker(ticker(), title: 'Gold'),
    );

    expect(png.length, greaterThan(1000));
    expect(png.take(8).toList(), [
      137,
      80,
      78,
      71,
      13,
      10,
      26,
      10,
    ], reason: 'PNG signature');
  });
}
