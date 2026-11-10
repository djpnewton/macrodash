import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:macrodash/api.dart';
import 'package:macrodash/config.dart';
import 'package:macrodash/result.dart';
import 'package:macrodash_models/models.dart';

const _customTickerJson = {
  'ticker1': 'TSLA',
  'ticker2': 'GC=F',
  'shortName': 'Tesla',
  'longName': 'Tesla Inc',
  'sources': ['yahoo'],
  'priceData': [
    {'date': '2024-01-01T00:00:00.000', 'amount': 100.0},
    {'date': '2024-01-02T00:00:00.000', 'amount': 110.0},
  ],
  'dividendData': <Object>[],
  'currency': 'USD',
};

/// Runs [body] against a client that answers every request with [response].
Future<T> _withResponse<T>(
  Future<T> Function() body,
  http.Response response, {
  void Function(http.BaseRequest request)? onRequest,
}) {
  return http.runWithClient(
    body,
    () => MockClient((request) async {
      onRequest?.call(request);
      return response;
    }),
  );
}

/// Runs [body] against a client whose requests always fail.
Future<T> _withFailure<T>(Future<T> Function() body) {
  return http.runWithClient(
    body,
    () => MockClient((_) async => throw http.ClientException('offline')),
  );
}

void main() {
  group('downloadFile', () {
    test('returns the body of a 200 response', () async {
      Uri? requested;
      final result = await _withResponse(
        () =>
            ServerApi().downloadFile('$macrodashServerUrl/thing', {'a': 'b c'}),
        http.Response('hello', 200),
        onRequest: (request) => requested = request.url,
      );

      expect(result, isA<Ok<String>>());
      expect((result as Ok<String>).value, 'hello');
      expect(requested?.path, '/thing');
      expect(requested?.queryParameters, {'a': 'b c'});
    });

    test('returns an error result for a non-200 response', () async {
      final result = await _withResponse(
        () => ServerApi().downloadFile('$macrodashServerUrl/thing', null),
        http.Response('nope', 503),
      );

      expect(result, isA<Error<String>>());
    });

    test('returns an error result when the request fails', () async {
      final result = await _withFailure(
        () => ServerApi().downloadFile('$macrodashServerUrl/thing', null),
      );

      expect(result, isA<Error<String>>());
    });
  });

  group('fetchCustomTicker', () {
    test('sends both tickers and the range, and parses the result', () async {
      Uri? requested;
      final result = await _withResponse(
        () => ServerApi().fetchCustomTicker(
          const DashTicker(title: 'Tesla', ticker1: 'TSLA', ticker2: 'GC=F'),
          DataRange.sevenDays,
        ),
        http.Response(jsonEncode(_customTickerJson), 200),
        onRequest: (request) => requested = request.url,
      );

      expect(requested?.path, '/market/custom');
      expect(requested?.queryParameters, {
        'ticker1': 'TSLA',
        'ticker2': 'GC=F',
        'range': 'sevenDays',
      });
      final ticker = (result as Ok<CustomTickerResult>).value;
      expect(ticker.ticker1, 'TSLA');
      expect(ticker.priceData.map((entry) => entry.amount), [100.0, 110.0]);
      expect(ticker.sources, ['yahoo']);
    });

    test('sends an empty comparison ticker as an empty value', () async {
      Uri? requested;
      await _withResponse(
        () => ServerApi().fetchCustomTicker(
          const DashTicker(title: null, ticker1: 'TSLA', ticker2: ''),
          DataRange.oneDay,
        ),
        http.Response(jsonEncode(_customTickerJson), 200),
        onRequest: (request) => requested = request.url,
      );

      expect(requested?.queryParameters, {
        'ticker1': 'TSLA',
        'ticker2': '',
        'range': 'oneDay',
      });
    });

    test('returns an error result when the request fails', () async {
      final result = await _withFailure(
        () => ServerApi().fetchCustomTicker(
          const DashTicker(title: null, ticker1: 'TSLA', ticker2: null),
          DataRange.sevenDays,
        ),
      );

      expect(result, isA<Error<CustomTickerResult>>());
    });

    test('returns an error result for a body that is not json', () async {
      final result = await _withResponse(
        () => ServerApi().fetchCustomTicker(
          const DashTicker(title: null, ticker1: 'TSLA', ticker2: null),
          DataRange.sevenDays,
        ),
        http.Response('<html>bad gateway</html>', 200),
      );

      expect(result, isA<Error<CustomTickerResult>>());
    });

    test(
      'returns an error result for json that does not match the parser',
      () async {
        final result = await _withResponse(
          () => ServerApi().fetchCustomTicker(
            const DashTicker(title: null, ticker1: 'TSLA', ticker2: null),
            DataRange.sevenDays,
          ),
          http.Response(jsonEncode([1, 2, 3]), 200),
        );

        expect(result, isA<Error<CustomTickerResult>>());
      },
    );

    test('returns an error result for json missing expected fields', () async {
      final result = await _withResponse(
        () => ServerApi().fetchCustomTicker(
          const DashTicker(title: null, ticker1: 'TSLA', ticker2: null),
          DataRange.sevenDays,
        ),
        http.Response(jsonEncode({'ticker1': 'TSLA'}), 200),
      );

      expect(result, isA<Error<CustomTickerResult>>());
    });
  });

  group('parseResponse', () {
    test('parses a json object with the given factory', () {
      final result = ServerApi().parseResponse(
        jsonEncode(_customTickerJson),
        CustomTickerResult.fromJson,
        'url',
      );

      expect((result as Ok<CustomTickerResult>).value.shortName, 'Tesla');
    });

    test('returns an error result when json is null', () {
      final result = ServerApi().parseResponse(
        'null',
        CustomTickerResult.fromJson,
        'url',
      );

      expect(result, isA<Error<CustomTickerResult>>());
    });
  });

  group('searchTicker', () {
    test('sends the query and parses the matches', () async {
      Uri? requested;
      final result = await _withResponse(
        () => ServerApi().searchTicker('tesla'),
        http.Response(
          jsonEncode({
            'data': [
              {'ticker': 'TSLA', 'name': 'Tesla', 'exchange': 'NASDAQ'},
            ],
          }),
          200,
        ),
        onRequest: (request) => requested = request.url,
      );

      expect(requested?.path, '/market/search');
      expect(requested?.queryParameters, {'query': 'tesla'});
      final matches = (result as Ok<TickerSearchResult>).value.data;
      expect(matches.single.ticker, 'TSLA');
      expect(matches.single.exchange, 'NASDAQ');
    });

    test('returns an error result when the request fails', () async {
      final result = await _withFailure(() => ServerApi().searchTicker('x'));

      expect(result, isA<Error<TickerSearchResult>>());
    });
  });
}
