import 'package:macrodash_models/models.dart';
import 'package:macrodash_server/market_data.dart';
import 'package:test/test.dart';

MarketOverviewEntry _entry(String ticker, String name) => MarketOverviewEntry(
      supply: 0,
      price: 1,
      high24h: 0,
      low24h: 0,
      priceChangePercent24h: 0,
      marketCap: 1,
      ticker: ticker,
      name: name,
      image: null,
      type: MarketCategory.stocks,
      moreInfoLink: null,
    );

void main() {
  group('MarketData.dedupeStockListings', () {
    test('collapses a company listed on several exchanges to one row', () {
      final entries = MarketData.dedupeStockListings([
        _entry('ABEA', 'Alphabet Inc. Class A'),
        _entry('ABEC', 'Alphabet Inc. Class C'),
        _entry('A14Y6F', 'Alphabet Inc. Class A'),
        _entry('GOOG', 'Alphabet Inc.'),
      ]);

      expect(entries, hasLength(1));
      expect(entries.single.ticker, 'GOOG');
    });

    test('prefers the primary listing even when it appears later', () {
      final entries = MarketData.dedupeStockListings([
        _entry('ABEA', 'Alphabet Inc. Class A'),
        _entry('AAPL', 'Apple Inc.'),
        _entry('GOOG', 'Alphabet Inc. Class C'),
      ]);

      expect(entries.map((e) => e.ticker), ['GOOG', 'AAPL']);
    });

    test('keeps the first primary listing when several are known', () {
      final entries = MarketData.dedupeStockListings([
        _entry('GOOG', 'Alphabet Inc. Class C'),
        _entry('GOOGL', 'Alphabet Inc. Class A'),
      ]);

      expect(entries.single.ticker, 'GOOG');
    });

    test('collapses depositary receipts of the same company', () {
      final entries = MarketData.dedupeStockListings([
        _entry(
          'GOGLB',
          'Alphabet Inc. Shs A Cert Deposito Arg Repr 0.01724138 Shs',
        ),
        _entry('GOOG', 'Alphabet Inc. Class C'),
        _entry('BABA', 'Alibaba Group Holding Ltd. Sponsored ADR'),
      ]);

      expect(entries.map((e) => e.ticker), ['GOOG', 'BABA']);
    });

    test('keeps the first listing when no primary listing is known', () {
      final entries = MarketData.dedupeStockListings([
        _entry('XYZ', 'Example Ltd'),
        _entry('XYZ.DE', 'Example Ltd'),
      ]);

      expect(entries.single.ticker, 'XYZ');
    });

    test('keeps distinct companies in their original order', () {
      final entries = MarketData.dedupeStockListings([
        _entry('AAPL', 'Apple Inc.'),
        _entry('NVDA', 'NVIDIA Corporation'),
        _entry('MSFT', 'Microsoft Corporation'),
      ]);

      expect(entries.map((e) => e.ticker), ['AAPL', 'NVDA', 'MSFT']);
    });
  });
}
