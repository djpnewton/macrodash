import 'package:flutter_test/flutter_test.dart';
import 'package:macrodash/freshness.dart';

void main() {
  test('formats ages', () {
    expect(formatAge(const Duration(seconds: 20)), 'just now');
    expect(formatAge(const Duration(minutes: 5)), '5m ago');
    expect(formatAge(const Duration(hours: 3, minutes: 10)), '3h ago');
    expect(formatAge(const Duration(days: 2)), '2d ago');
  });

  test('labels a source by its host', () {
    expect(sourceLabel('https://finance.yahoo.com/'), 'finance.yahoo.com');
    expect(sourceLabel('https://www.coingecko.com/'), 'coingecko.com');
    expect(sourceLabel('not a url'), 'not a url');
  });

  test('describes load errors', () {
    expect(
      describeLoadError(Exception(Exception('Status code: 503'))),
      'Server returned 503',
    );
    expect(describeLoadError(Exception('Timed out')), 'Request timed out');
    expect(
      describeLoadError(Exception('Failed to parse data from x')),
      'Unexpected response from the server',
    );
    expect(
      describeLoadError(Exception('SocketException: nope')),
      'Could not reach the server',
    );
  });

  test('shows the time for today and the date for older prices', () {
    final now = DateTime(2024, 5, 10, 15, 30);
    expect(formatPriceTime(DateTime(2024, 5, 10, 9, 5), now), '09:05');
    expect(formatPriceTime(DateTime(2024, 5, 9, 21, 0), now), 'May 9, 21:00');
  });

  test('summarises source, last price, age and a failed reload', () {
    final now = DateTime(2024, 5, 10, 15, 30);
    final text = freshnessSummary(
      sources: ['https://finance.yahoo.com/', 'https://finance.yahoo.com/'],
      lastPoint: DateTime(2024, 5, 9, 21, 0),
      fetchedAt: now.subtract(const Duration(minutes: 7)),
      now: now,
      error: 'Request timed out',
    );
    expect(text.split('\n'), [
      'Source: finance.yahoo.com',
      'Last price: May 9, 21:00',
      'Updated 7m ago',
      'Reload failed: Request timed out',
    ]);
  });
}
