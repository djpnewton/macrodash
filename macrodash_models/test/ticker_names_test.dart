import 'package:macrodash_models/models.dart';
import 'package:test/test.dart';

void main() {
  group('shortTickerLabel', () {
    test('trims futures contract months from quote symbols', () {
      expect(shortTickerLabel(ticker: 'GC=F', name: 'Gold Dec 26'), 'Gold');
      expect(
        shortTickerLabel(ticker: 'CL=F', name: 'Crude Oil Dec 26'),
        'Crude Oil',
      );
      expect(
        shortTickerLabel(ticker: 'NG=F', name: 'Natural Gas Jan 27'),
        'Natural Gas',
      );
    });

    test('trims quote currencies from crypto pairs', () {
      expect(
        shortTickerLabel(ticker: 'BTC-USD', name: 'Bitcoin USD'),
        'Bitcoin',
      );
      expect(
        shortTickerLabel(ticker: 'ETH-USD', name: 'Ethereum USD'),
        'Ethereum',
      );
      expect(shortTickerLabel(ticker: 'SOL-EUR', name: 'Solana EUR'), 'Solana');
    });

    test('keeps names that are already short', () {
      expect(shortTickerLabel(ticker: '^GSPC', name: 'S&P 500'), 'S&P 500');
      expect(shortTickerLabel(ticker: 'EURUSD=X', name: 'EUR/USD'), 'EUR/USD');
    });

    test('keeps ordinary share tickers', () {
      expect(shortTickerLabel(ticker: 'AAPL', name: 'Apple Inc.'), 'AAPL');
      expect(
        shortTickerLabel(ticker: 'brk-b', name: 'Berkshire Hathaway'),
        'BRK-B',
      );
      expect(
        shortTickerLabel(ticker: 'BRK.A', name: 'Berkshire Hathaway'),
        'BRK.A',
      );
    });

    test('falls back to the symbol when the name adds nothing', () {
      expect(shortTickerLabel(ticker: 'GC=F', name: ''), 'GC=F');
      expect(shortTickerLabel(ticker: 'GC=F', name: 'Dec 26'), 'GC=F');
      expect(shortTickerLabel(ticker: '', name: 'Gold'), '');
    });

    test('keeps long names inside the label gutter', () {
      final label = shortTickerLabel(
        ticker: 'XX=F',
        name: 'A Very Long Commodity Name Dec 26',
      );
      expect(label, 'A Very Long C…');
      expect(label.length, maxTickerLabelLength);
    });
  });
}
