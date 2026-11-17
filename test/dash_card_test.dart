import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:macrodash/dash.dart';
import 'package:macrodash/option_buttons.dart';
import 'package:macrodash/theme.dart';
import 'package:macrodash_models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/dash_harness.dart';

/// Pumps a single dashboard card, answered with [prices] unless [client] is
/// given.
Future<void> _pumpCard(
  WidgetTester tester, {
  List<(DateTime, double)>? prices,
  String shortName = 'Tesla',
  String longName = 'Tesla Inc',
  MockClient? client,
  DashTicker ticker = const DashTicker(
    title: 'Tesla',
    ticker1: 'TSLA',
    ticker2: null,
  ),
}) async {
  tester.view.physicalSize = const Size(800, 200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await http.runWithClient(
    () async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                height: 75,
                child: DashCard(
                  key: ObjectKey(ticker),
                  ticker: ticker,
                  dragHandle: const Icon(Icons.drag_indicator),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    },
    () =>
        client ??
        tickerClient(
          body: jsonEncode(
            tickerResponse(
              prices: prices,
              shortName: shortName,
              longName: longName,
            ),
          ),
        ),
  );
}

void main() {
  testWidgets(
    'shows configured ticker metadata while the first load is pending',
    (tester) async {
      final response = Completer<http.Response>();
      await _pumpCard(
        tester,
        ticker: const DashTicker(
          title: 'Tesla vs Gold',
          ticker1: 'TSLA',
          ticker2: 'GC=F',
        ),
        client: MockClient((_) => response.future),
      );

      expect(find.text('Tesla vs Gold'), findsOneWidget);
      expect(find.text('TSLA vs GC=F'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.drag_indicator), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsNothing);

      response.complete(http.Response(jsonEncode(tickerResponse()), 200));
      await tester.pump();
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Tesla vs Gold'), findsOneWidget);
      expect(find.text('TSLA vs GC=F'), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget);
    },
  );

  testWidgets('uses the symbol when a loading ticker has no title', (
    tester,
  ) async {
    final response = Completer<http.Response>();
    await _pumpCard(
      tester,
      ticker: const DashTicker(title: null, ticker1: 'TSLA', ticker2: ''),
      client: MockClient((_) => response.future),
    );

    expect(find.text('TSLA'), findsOneWidget);
    expect(find.text('TSLA / '), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    response.complete(http.Response('unavailable', 500));
    await tester.pump();
    await tester.pump();
    expect(find.text('Error loading ticker data'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets(
    'saved pairs display separate indexed changes and open comparison',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'dash_tickers': jsonEncode({
          'tickers': [
            {'title': 'Saved pair', 'ticker1': 'AAA', 'ticker2': 'BBB'},
          ],
        }),
      });
      final requests = <Uri>[];
      final now = DateTime.now();
      final client = MockClient((request) async {
        requests.add(request.url);
        final first = request.url.queryParameters['ticker1'] == 'AAA';
        return http.Response(
          jsonEncode(
            tickerResponse(
              prices: [
                (now.subtract(const Duration(days: 3)), first ? 50 : 100),
                (now.subtract(const Duration(hours: 12)), first ? 100 : 200),
                (now, first ? 120 : 180),
              ],
            ),
          ),
          200,
        );
      });
      await runDashPanelTest(tester, client: client, () async {
        expect(requests.map((r) => r.queryParameters['ticker1']), [
          'AAA',
          'BBB',
        ]);
        expect(
          requests.every((r) => r.queryParameters['ticker2']!.isEmpty),
          isTrue,
        );
        expect(find.text('AAA +20.00%'), findsOneWidget);
        expect(find.text('BBB -10.00%'), findsOneWidget);
        await tester.tap(find.byTooltip('Toggle 24h / 7d'));
        await tester.pump();
        expect(find.text('AAA +140.00%'), findsOneWidget);
        expect(find.text('BBB +80.00%'), findsOneWidget);
        await tester.tap(find.byTooltip('Show larger chart'));
        await tester.pumpAndSettle();
        expect(find.text('Compare prices'), findsOneWidget);
        expect(find.text('AAA'), findsOneWidget);
        expect(find.text('BBB'), findsOneWidget);
        expect(requests, hasLength(4));
        await tester.tap(find.byTooltip('Back to chart'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Saved pair'));
        await tester.pumpAndSettle();
        expect(find.text('Compare prices'), findsOneWidget);
      });
    },
  );

  testWidgets('comparison card fits at phone width', (tester) async {
    final now = DateTime.now();
    await _pumpCard(
      tester,
      ticker: const DashTicker(title: null, ticker1: 'AAA', ticker2: 'BBB'),
      prices: [(now.subtract(const Duration(hours: 2)), 100), (now, 110)],
    );
    tester.view.physicalSize = const Size(360, 600);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('AAA +10.00%'), findsOneWidget);
    expect(find.text('BBB +10.00%'), findsOneWidget);
  });

  testWidgets('failed component reload keeps both previous comparison values', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'dash_tickers': jsonEncode({
        'tickers': [
          {'title': 'Saved pair', 'ticker1': 'AAA', 'ticker2': 'BBB'},
        ],
      }),
    });
    final now = DateTime.now();
    var failing = false;
    final client = MockClient((request) async {
      final first = request.url.queryParameters['ticker1'] == 'AAA';
      if (failing && !first) return http.Response('error', 500);
      return http.Response(
        jsonEncode(
          tickerResponse(
            prices: [
              (now.subtract(const Duration(hours: 2)), first ? 100 : 200),
              (now, first ? (failing ? 150 : 120) : 180),
            ],
          ),
        ),
        200,
      );
    });
    await runDashPanelTest(tester, client: client, () async {
      expect(find.text('AAA +20.00%'), findsOneWidget);
      expect(find.text('BBB -10.00%'), findsOneWidget);
      failing = true;
      await tester.fling(find.byType(GridView), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();
      expect(find.text('AAA +20.00%'), findsOneWidget);
      expect(find.text('BBB -10.00%'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });
  });

  testWidgets('shows the 24h change and toggles to the 7d window', (
    tester,
  ) async {
    final now = DateTime.now();
    await _pumpCard(
      tester,
      prices: [
        (now.subtract(const Duration(days: 6)), 100),
        (now.subtract(const Duration(hours: 12)), 200),
        (now, 210),
      ],
    );

    expect(find.text('+5.00%'), findsOneWidget);
    expect(find.text('24h'), findsOneWidget);

    await tester.tap(find.byTooltip('Toggle 24h / 7d'));
    await tester.pump();

    expect(find.text('+110.00%'), findsOneWidget);
    expect(find.text('7d'), findsOneWidget);

    await tester.tap(find.byTooltip('Toggle 24h / 7d'));
    await tester.pump();

    expect(find.text('+5.00%'), findsOneWidget);
    expect(find.text('24h'), findsOneWidget);
  });

  testWidgets('shows a loss without a plus sign', (tester) async {
    final now = DateTime.now();
    await _pumpCard(
      tester,
      prices: [
        (now.subtract(const Duration(days: 6)), 300),
        (now.subtract(const Duration(hours: 12)), 200),
        (now, 150),
      ],
    );

    expect(find.text('-25.00%'), findsOneWidget);
  });

  testWidgets('shows the drag handle next to the loaded data', (tester) async {
    final now = DateTime.now();
    await _pumpCard(
      tester,
      prices: [(now.subtract(const Duration(hours: 1)), 100), (now, 110)],
    );

    expect(find.byIcon(Icons.drag_indicator), findsOneWidget);
    expect(find.byIcon(Icons.settings), findsOneWidget);
  });

  testWidgets('shows the handle and an error message when loading fails', (
    tester,
  ) async {
    await _pumpCard(tester, client: tickerClient(statusCode: 500));

    expect(find.text('Error loading ticker data'), findsOneWidget);
    expect(find.byIcon(Icons.drag_indicator), findsOneWidget);
  });

  testWidgets('shows an error instead of spinning on a malformed response', (
    tester,
  ) async {
    await _pumpCard(
      tester,
      client: tickerClient(body: '<html>bad gateway</html>'),
    );

    expect(find.text('Error loading ticker data'), findsOneWidget);
  });

  testWidgets('the price tooltip says where the data is from and how old', (
    tester,
  ) async {
    final now = DateTime.now();
    await _pumpCard(
      tester,
      prices: [(now.subtract(const Duration(hours: 1)), 100), (now, 110)],
    );

    final message =
        tester
            .widget<Tooltip>(find.byKey(const ValueKey('freshness-tooltip')))
            .message!;
    expect(message, contains('Source: yahoo'));
    expect(message, contains('Last price: '));
    expect(message, contains('Updated just now'));
    expect(message, isNot(contains('Reload failed')));
    expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
  });

  testWidgets('tapping the price shows the freshness without hover', (
    tester,
  ) async {
    final now = DateTime.now();
    await _pumpCard(
      tester,
      prices: [(now.subtract(const Duration(hours: 1)), 100), (now, 110)],
    );

    expect(find.textContaining('Source: yahoo'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('freshness-tooltip')));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.textContaining('Source: yahoo'), findsOneWidget);
  });

  testWidgets('the large chart repeats the source and freshness', (
    tester,
  ) async {
    final now = DateTime.now();
    await _pumpCard(
      tester,
      prices: [(now.subtract(const Duration(hours: 1)), 100), (now, 110)],
    );

    tester.view.physicalSize = const Size(800, 600);
    await tester.tap(find.byTooltip('Show larger chart'));
    await tester.pumpAndSettle();

    final text =
        tester
            .widget<Text>(find.byKey(const ValueKey('sparkline-freshness')))
            .data!;
    expect(text, contains('Source: yahoo'));
    expect(text, contains('Updated just now'));
    expect(find.text('Compare'), findsOneWidget);
  });

  testWidgets('large dashboard chart shares the selected sparkline window', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'dash_tickers': jsonEncode({
        'tickers': [
          {'title': 'Tesla', 'ticker1': 'TSLA', 'ticker2': null},
        ],
      }),
    });
    final now = DateTime.now();
    await runDashPanelTest(
      tester,
      client: tickerClient(
        body: jsonEncode(
          tickerResponse(
            prices: [
              (now.subtract(const Duration(days: 3)), 90),
              (now.subtract(const Duration(hours: 12)), 100),
              (now, 110),
            ],
          ),
        ),
      ),
      () async {
        await tester.tap(find.byTooltip('Show larger chart'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Share chart'));
        await tester.pumpAndSettle();
        var image = tester.widget<SharePreviewImage>(
          find.byType(SharePreviewImage),
        );
        expect(Uri.parse(image.url).queryParameters['windowDays'], '1');
        expect(Uri.parse(image.url).queryParameters['ticker1'], 'TSLA');
        expect(find.textContaining('zoom=oneDay'), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Close'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Toggle 24h / 7d'));
        await tester.pump();
        await tester.tap(find.byTooltip('Show larger chart'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Share chart'));
        await tester.pumpAndSettle();
        image = tester.widget<SharePreviewImage>(
          find.byType(SharePreviewImage),
        );
        expect(Uri.parse(image.url).queryParameters['windowDays'], '7');
        expect(find.textContaining('zoom=sevenDays'), findsOneWidget);
      },
    );
  });

  testWidgets('opens comparison from the large chart and returns to it', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final requests = <Uri>[];
    await runDashPanelTest(
      tester,
      size: const Size(800, 900),
      client: tickerClient(requests: requests),
      () async {
        await tester.tap(find.byTooltip('Show larger chart').first);
        await tester.pumpAndSettle();
        expect(find.text('Not enough data for this chart.'), findsOneWidget);
        await tester.tap(find.text('Compare'));
        await tester.pumpAndSettle();
        expect(find.text('Compare prices'), findsOneWidget);
        expect(find.textContaining('Indexed to 100'), findsOneWidget);
        expect(requests.last.queryParameters['range'], 'sevenDays');
        await tester.tap(find.byTooltip('Back to chart'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('sparkline-freshness')),
          findsOneWidget,
        );
        expect(find.text('Compare'), findsOneWidget);
      },
    );
  });

  testWidgets('the error card says why and retries on request', (tester) async {
    SharedPreferences.setMockInitialValues({});
    var failing = true;
    final client = MockClient(
      (_) async =>
          failing
              ? http.Response('nope', 500)
              : http.Response(jsonEncode(tickerResponse()), 200),
    );

    await runDashPanelTest(tester, client: client, () async {
      expect(find.text('Error loading ticker data'), findsNWidgets(4));
      expect(find.text('Server returned 500'), findsNWidgets(4));

      failing = false;
      await tester.tap(find.text('Retry').first);
      await tester.pumpAndSettle();

      expect(find.text('Error loading ticker data'), findsNWidgets(3));
      expect(find.text('Retry'), findsNWidgets(3));
    });
  });

  testWidgets('only shows a subtitle that adds something', (tester) async {
    final now = DateTime.now();
    final prices = <(DateTime, double)>[
      (now.subtract(const Duration(hours: 1)), 100),
      (now, 110),
    ];
    const unnamed = DashTicker(title: null, ticker1: 'TSLA', ticker2: null);

    await _pumpCard(
      tester,
      ticker: unnamed,
      prices: prices,
      shortName: 'Tesla',
      longName: 'Tesla Inc',
    );
    expect(find.text('Tesla'), findsOneWidget);
    expect(find.text('Tesla Inc'), findsOneWidget);

    await _pumpCard(
      tester,
      ticker: unnamed,
      prices: prices,
      shortName: 'Tesla',
      longName: 'Tesla',
    );
    expect(find.text('Tesla'), findsOneWidget);
  });
}
