import 'package:flutter_test/flutter_test.dart';
import 'package:macrodash/helper.dart';

void main() {
  group('formatPrice', () {
    test('leaves small prices with two decimals', () {
      expect(formatPrice(0), '\$0.00');
      expect(formatPrice(5.5), '\$5.50');
      expect(formatPrice(999.99), '\$999.99');
    });

    test('abbreviates thousands and above', () {
      expect(formatPrice(1000), '\$1.00 K');
      expect(formatPrice(2334.5), '\$2.33 K');
      expect(formatPrice(5.03e6), '\$5.03 M');
      expect(formatPrice(1.88e9), '\$1.88 B');
      expect(formatPrice(2.33e9), '\$2.33 B');
      expect(formatPrice(5.03e12), '\$5.03 T');
      expect(formatPrice(1.1e15), '\$1100.00 T');
    });

    test('keeps the sign in front of the currency', () {
      expect(formatPrice(-5.5), '-\$5.50');
      expect(formatPrice(-2.5e9), '-\$2.50 B');
    });

    test('keeps enough precision for sub-cent prices', () {
      expect(formatPrice(0.5), '\$0.50');
      expect(formatPrice(0.0099), '\$0.0099');
      expect(formatPrice(0.0000123), '\$1.23e-5');
    });

    test('honours the currency and spacing options', () {
      expect(formatPrice(1234, currencyChar: '', space: ''), '1.23K');
      expect(formatPrice(1234, currencyChar: '€'), '€1.23 K');
    });

    test('renders non-finite values as --', () {
      expect(formatPrice(double.nan), '--');
      expect(formatPrice(double.infinity), '--');
      expect(formatPrice(double.negativeInfinity), '--');
    });
  });
}
