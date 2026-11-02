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

MarketOverviewEntry _marketEntry({
  required String ticker,
  required String name,
  required double cap,
}) => MarketOverviewEntry(
  supply: 0,
  price: 1,
  high24h: 0,
  low24h: 0,
  priceChangePercent24h: 0,
  marketCap: cap,
  ticker: ticker,
  name: name,
  image: null,
  type: MarketCategory.metals,
  moreInfoLink: null,
);

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

  group('PreviewData', () {
    test('keeps only the requested window and reports the change', () {
      final data = PreviewData.fromTicker(
        ticker(points: 24 * 10),
        title: 'Gold',
        days: 7,
      );

      expect(data.title, 'Gold');
      expect(data.subtitle, 'Gold Dec 26');
      expect(data.unit, 'USD');
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
      expect(PreviewData.fromTicker(result).subtitle, 'BTC-USD / GC=F');
    });

    test('downsamples long series', () {
      final data = PreviewData.fromTicker(ticker(points: 5000));
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

      final data = PreviewData.fromTicker(sparse);
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

  group('page URLs', () {
    test('pageShareUrl puts the page in the path', () {
      expect(
        pageShareUrl(
          previewUrl: 'https://ln.macrodash.me/',
          page: 'm2',
          params: {'region': 'usa', 'zoom': 'oneYear'},
        ),
        'https://ln.macrodash.me/p/m2?region=usa&zoom=oneYear',
      );
    });

    test('pageAppUrl keeps the app hash route', () {
      expect(
        pageAppUrl(
          appUrl: 'https://macrodash.me',
          page: 'bondRates',
          params: {'category': 'tenYear'},
        ),
        'https://macrodash.me/#/bondRates?category=tenYear',
      );
    });

    test('recognises previewable pages case-insensitively', () {
      expect(isPreviewPage('m2'), isTrue);
      expect(isPreviewPage('marketCap'), isTrue);
      expect(isPreviewPage('settings'), isFalse);
    });

    test('pagePreviewImageUrl points at the page image endpoint', () {
      expect(
        pagePreviewImageUrl(
          previewUrl: 'https://ln.macrodash.me/',
          page: 'm2',
          params: {'region': 'usa'},
        ),
        'https://ln.macrodash.me/p/m2/preview_image?region=usa',
      );
    });

    test('pagePreviewImageUrl drops the query when there are no params', () {
      expect(
        pagePreviewImageUrl(
          previewUrl: 'https://ln.macrodash.me',
          page: 'debt',
        ),
        'https://ln.macrodash.me/p/debt/preview_image',
      );
    });
  });

  group('tickerPreviewImageUrl', () {
    test('carries the ticker, title and range', () {
      expect(
        tickerPreviewImageUrl(
          previewUrl: 'https://ln.macrodash.me/',
          ticker1: 'GC=F',
          params: {'title': 'Gold', 'zoom': 'oneYear'},
        ),
        'https://ln.macrodash.me/market/custom_preview_image'
        '?range=oneYear&ticker1=GC%3DF&title=Gold',
      );
    });

    test('defaults to a five-day window with no params', () {
      expect(
        tickerPreviewImageUrl(
          previewUrl: 'https://ln.macrodash.me',
          ticker1: 'BTC-USD',
        ),
        'https://ln.macrodash.me/market/custom_preview_image'
        '?range=fiveDays&ticker1=BTC-USD',
      );
    });

    test('prefers range over zoom and ignores unknown ranges', () {
      expect(
        previewImageRange({'range': 'oneMonth', 'zoom': 'oneYear'}),
        DataRange.oneMonth,
      );
      expect(previewImageRange({'zoom': 'oneYear'}), DataRange.oneYear);
      expect(previewImageRange({'zoom': 'bogus'}), DataRange.fiveDays);
      expect(previewImageRange({}), DataRange.fiveDays);
    });

    test('forwards ticker2 for comparison charts', () {
      expect(
        tickerPreviewImageUrl(
          previewUrl: 'https://ln.macrodash.me',
          ticker1: 'BTC-USD',
          params: {'ticker2': 'GC=F', 'title': '', 'range': 'oneDay'},
        ),
        'https://ln.macrodash.me/market/custom_preview_image'
        '?range=oneDay&ticker1=BTC-USD&ticker2=GC%3DF',
      );
    });
  });

  group('PreviewData.fromTicker subtitle', () {
    CustomTickerResult named(String shortName, String longName) {
      final base = ticker();
      return CustomTickerResult(
        ticker1: base.ticker1,
        ticker2: null,
        shortName: shortName,
        longName: longName,
        sources: base.sources,
        priceData: base.priceData,
        dividendData: base.dividendData,
        currency: base.currency,
      );
    }

    test('keeps a subtitle that differs from the title', () {
      final data = PreviewData.fromTicker(named('Gold', 'Gold Dec 26'));

      expect(data.title, 'Gold');
      expect(data.subtitle, 'Gold Dec 26');
    });

    test('drops a subtitle that repeats the title', () {
      final data = PreviewData.fromTicker(named('S&P 500', 'S&P 500'));

      expect(data.title, 'S&P 500');
      expect(data.subtitle, isEmpty);
    });

    test('drops a subtitle that repeats an explicit title', () {
      final data = PreviewData.fromTicker(named('Gold', 'Gold'), title: 'Gold');

      expect(data.subtitle, isEmpty);
    });

    test('renders a preview without a subtitle', () async {
      final png = await renderPreviewPng(
        PreviewData.fromTicker(named('S&P 500', 'S&P 500')),
      );

      expect(png.length, greaterThan(1000));
    });
  });

  group('PreviewData.fromSeries', () {
    test('reports the value, unit and change over the range', () {
      final data = PreviewData.fromSeries(
        title: 'M2 Money Supply',
        subtitle: 'USA',
        data: [
          for (var i = 0; i < 24; i++)
            AmountEntry(
              date: DateTime(2025, 1 + i, 1),
              amount: 20 + i.toDouble(),
            ),
        ],
        unit: 'T USD',
        range: DataRange.oneYear,
      );

      expect(data.title, 'M2 Money Supply');
      expect(data.unit, 'T USD');
      expect(data.value, '43.00');
      expect(data.change, startsWith('+'));
      expect(data.change, endsWith('%'));
      expect(data.series.length, greaterThan(2));
      expect(data.windowLabel, isNotEmpty);
      expect(data.isGain, isTrue);
    });

    test('reports bond rate changes in points', () {
      final data = PreviewData.fromSeries(
        title: 'Bond Rates',
        subtitle: 'USA',
        data: [
          AmountEntry(date: DateTime(2025, 1), amount: 4.0),
          AmountEntry(date: DateTime(2025, 6), amount: 4.25),
        ],
        unit: '%',
        changeMode: PreviewChangeMode.points,
      );

      expect(data.change, '+0.25 pts');
    });
  });

  group('PreviewData.fromMarketCap', () {
    test('totals the caps and ranks the bars', () {
      MarketOverviewEntry entry(String ticker, double cap) =>
          MarketOverviewEntry(
            supply: 0,
            price: 1,
            high24h: 0,
            low24h: 0,
            priceChangePercent24h: 0,
            marketCap: cap,
            ticker: ticker,
            name: ticker,
            image: null,
            type: MarketCategory.crypto,
            moreInfoLink: null,
          );

      final data = PreviewData.fromMarketCap(
        title: 'Market Caps',
        subtitle: 'All',
        entries: [entry('btc', 2e12), entry('eth', 5e11), entry('aapl', 1e12)],
        maxBars: 2,
      );

      expect(data.value, '\$3.50T');
      expect(data.bars.length, 2);
      expect(data.bars.first.label, 'BTC');
      expect(data.bars.first.valueLabel, '\$2.00T');
      expect(data.series, isEmpty);
    });

    test('labels quote symbols with the asset name', () {
      final bars =
          PreviewData.fromMarketCap(
            title: 'Market Caps',
            subtitle: 'Metals',
            entries: [
              _marketEntry(ticker: 'GC=F', name: 'Gold', cap: 3e13),
              _marketEntry(ticker: 'SI=F', name: 'Silver', cap: 3e12),
              _marketEntry(ticker: '^GSPC', name: 'S&P 500', cap: 1e12),
            ],
          ).bars;

      expect(bars.map((bar) => bar.label), ['Gold', 'Silver', 'S&P 500']);
    });

    test('keeps plain tickers uppercase', () {
      final bars =
          PreviewData.fromMarketCap(
            title: 'Market Caps',
            subtitle: 'Stocks',
            entries: [
              _marketEntry(ticker: 'aapl', name: 'Apple Inc.', cap: 5e12),
              _marketEntry(
                ticker: 'BRK.A',
                name: 'Berkshire Hathaway Inc.',
                cap: 1e12,
              ),
            ],
          ).bars;

      expect(bars.map((bar) => bar.label), ['AAPL', 'BRK.A']);
    });

    test('truncates names that would overrun the label gutter', () {
      final bars =
          PreviewData.fromMarketCap(
            title: 'Market Caps',
            subtitle: 'Metals',
            entries: [
              _marketEntry(
                ticker: 'XX=F',
                name: 'A Very Long Commodity Name',
                cap: 1e12,
              ),
            ],
          ).bars;

      expect(bars.single.label, 'A Very Long C…');
    });
  });

  test('renders a png', () async {
    final png = await renderPreviewPng(
      PreviewData.fromTicker(ticker(), title: 'Gold'),
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
  test('renders a bar-chart png', () async {
    final png = await renderPreviewPng(
      const PreviewData(
        title: 'Market Caps',
        subtitle: 'All',
        value: '\$3.50T',
        bars: [
          PreviewBar(label: 'BTC', value: 2, valueLabel: '\$2.00T'),
          PreviewBar(label: 'ETH', value: 1, valueLabel: '\$1.00T'),
        ],
      ),
    );

    expect(png.length, greaterThan(1000));
  });
}
