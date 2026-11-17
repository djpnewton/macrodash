import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';
import 'package:macrodash_models/models.dart';
import 'package:macrodash_server/cache.dart';
import 'package:macrodash_server/market_data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../routes/compare/index.dart' as html;
import '../../routes/compare/preview_image.dart' as image;

class MockContext extends Mock implements RequestContext {}

class MockMarketData extends Mock implements MarketData {}

CustomTickerResult ticker(String symbol, double end) => CustomTickerResult(
      ticker1: symbol,
      ticker2: null,
      shortName: symbol,
      longName: symbol,
      sources: const ['yahoo'],
      priceData: [
        AmountEntry(date: DateTime.utc(2025), amount: 100),
        AmountEntry(date: DateTime.utc(2025, 1, 2), amount: end),
      ],
      dividendData: const [],
      currency: 'USD',
    );

void main() {
  test('HTML and PNG share normalized data and preserve link parameters',
      () async {
    final params = {
      'tickers': jsonEncode(['BTC-USD', 'GC=F', '^GSPC']),
      'baseCount': '2',
      'range': 'oneMonth',
      'yearOffset': '-240',
    };
    final uri = Uri(
      scheme: 'https',
      host: 'ln.example.test',
      path: '/compare',
      queryParameters: params,
    );
    final market = MockMarketData();
    for (final symbol in ['BTC-USD', 'GC=F', '^GSPC']) {
      when(() => market.custom(symbol, null, DataRange.oneMonth, null))
          .thenAnswer((_) async => ticker(symbol, symbol == 'GC=F' ? 80 : 120));
    }
    final context = MockContext();
    final cache = Cache();
    when(() => context.request).thenReturn(Request.get(uri));
    when(() => context.read<MarketData>()).thenReturn(market);
    when(() => context.read<Cache>()).thenReturn(cache);
    final response = await html.onRequest(context);
    expect(response.statusCode, 200);
    final body = await response.body();
    expect(body, contains('BTC-USD vs GC=F vs ^GSPC - 1M'));
    expect(body, contains('property="og:image"'));
    expect(body, contains('/compare/preview_image?'));
    expect(body, contains('/#/compare?'));
    expect(body, contains('%5EGSPC'));

    final pngContext = MockContext();
    when(() => pngContext.request).thenReturn(
      Request.get(uri.replace(path: '/compare/preview_image')),
    );
    when(() => pngContext.read<MarketData>()).thenReturn(market);
    when(() => pngContext.read<Cache>()).thenReturn(cache);
    final png = await image.onRequest(pngContext);
    expect(png.statusCode, 200);
    expect(png.headers['content-type'], 'image/png');
    final bytes = await png.bytes().expand((chunk) => chunk).toList();
    expect(bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
    expect(bytes.length, greaterThan(1000));
    for (final symbol in ['BTC-USD', 'GC=F', '^GSPC']) {
      verify(() => market.custom(symbol, null, DataRange.oneMonth, null))
          .called(1);
    }
  });

  test('invalid and unavailable data return explicit failures', () async {
    final context = MockContext();
    when(() => context.request).thenReturn(
      Request.get(
        Uri.parse('https://ln.example.test/compare?tickers=invalid'),
      ),
    );
    expect((await html.onRequest(context)).statusCode, 400);
    expect((await image.onRequest(context)).statusCode, 400);
    final market = MockMarketData();
    when(() => market.custom('MISSING-TEST', null, DataRange.oneYear, null))
        .thenAnswer((_) async => null);
    final params = {
      'tickers': jsonEncode(['MISSING-TEST']),
      'baseCount': '1',
      'range': 'oneYear',
    };
    when(() => context.request).thenReturn(
      Request.get(Uri.https('ln.example.test', '/compare', params)),
    );
    when(() => context.read<MarketData>()).thenReturn(market);
    when(() => context.read<Cache>()).thenReturn(Cache());
    final htmlResponse = await html.onRequest(context);
    expect(await htmlResponse.body(), contains('/og-image.png'));
    expect((await image.onRequest(context)).statusCode, 502);
  });
}
