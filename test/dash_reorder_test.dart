import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:macrodash/dash.dart';
import 'package:macrodash/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A minimal custom ticker payload so the cards render in their loaded state.
const _tickerResponse = {
  'ticker1': 'TSLA',
  'ticker2': null,
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

MockClient _tickerClient() =>
    MockClient((_) async => http.Response(jsonEncode(_tickerResponse), 200));

Future<void> _pumpDash(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: DashPanel(refreshKey: GlobalKey<RefreshIndicatorState>()),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
}

List<String> _order(WidgetTester tester) =>
    tester
        .widgetList<DashCard>(find.byType(DashCard))
        .map((card) => card.ticker.ticker1)
        .toList();

/// Centre of the grab handle of the card at [index].
Offset _handleCenter(WidgetTester tester, int index) => tester.getCenter(
  find.descendant(
    of: find.byType(DashCard).at(index),
    matching: find.byIcon(Icons.drag_indicator),
  ),
);

void main() {
  const defaultOrder = ['TSLA', 'BTC-USD', 'GC=F', 'BTC-USD'];

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('dragging a card by its handle onto another moves it there', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await http.runWithClient(() async {
        await _pumpDash(tester);
        expect(_order(tester), defaultOrder);

        final statesBefore = {
          for (final card in tester.widgetList<DashCard>(find.byType(DashCard)))
            card.ticker.ticker1: tester.state(find.byWidget(card)),
        };

        final from = _handleCenter(tester, 0);
        final to = tester.getCenter(find.byType(DashCard).at(2));
        final gesture = await tester.startGesture(
          from,
          kind: PointerDeviceKind.mouse,
        );
        await tester.pump(const Duration(milliseconds: 50));
        await gesture.moveTo(to);
        await tester.pump(const Duration(milliseconds: 100));
        await gesture.up();
        await tester.pumpAndSettle();

        expect(_order(tester), ['BTC-USD', 'GC=F', 'TSLA', 'BTC-USD']);

        // The moved card keeps its state instead of reloading.
        final tslaFinder = find.byWidgetPredicate(
          (widget) => widget is DashCard && widget.ticker.ticker1 == 'TSLA',
        );
        expect(
          identical(tester.state(tslaFinder), statesBefore['TSLA']),
          isTrue,
        );

        final prefs = await SharedPreferences.getInstance();
        final saved = jsonDecode(prefs.getString('dash_tickers')!) as Map;
        expect((saved['tickers'] as List).map((t) => t['ticker1']).toList(), [
          'BTC-USD',
          'GC=F',
          'TSLA',
          'BTC-USD',
        ]);

        // Dragging the card body must not reorder; only the handle does.
        final body = await tester.startGesture(
          tester.getCenter(find.byType(DashCard).first),
          kind: PointerDeviceKind.mouse,
        );
        await body.moveTo(tester.getCenter(find.byType(DashCard).at(2)));
        await tester.pump(const Duration(milliseconds: 100));
        await body.up();
        await tester.pumpAndSettle();
        expect(_order(tester), ['BTC-USD', 'GC=F', 'TSLA', 'BTC-USD']);

        // Card controls still respond to taps.
        await tester.tap(find.byIcon(Icons.settings).first);
        await tester.pumpAndSettle();
        expect(find.text('Configure Ticker'), findsOneWidget);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.remove_circle).last);
        await tester.pumpAndSettle();
        expect(find.text('Remove Ticker'), findsOneWidget);
        await tester.tap(find.text('Remove'));
        await tester.pumpAndSettle();
        expect(_order(tester), ['BTC-USD', 'GC=F', 'TSLA']);
      }, _tickerClient);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('dragging the handle reorders on touch devices', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await http.runWithClient(() async {
        await _pumpDash(tester);
        expect(_order(tester), defaultOrder);

        final from = _handleCenter(tester, 0);
        final to = tester.getCenter(find.byType(DashCard).at(1));
        final gesture = await tester.startGesture(from);
        await tester.pump(const Duration(milliseconds: 50));
        await gesture.moveTo(to);
        await tester.pump(const Duration(milliseconds: 100));
        await gesture.up();
        await tester.pumpAndSettle();

        expect(_order(tester), ['BTC-USD', 'TSLA', 'GC=F', 'BTC-USD']);
      }, _tickerClient);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('reordering works when two tickers are configured the same', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'dash_tickers': jsonEncode({
        'tickers': [
          {'title': 'Dup', 'ticker1': 'SPY', 'ticker2': null},
          {'title': 'Dup', 'ticker1': 'SPY', 'ticker2': null},
          {'title': 'Gold', 'ticker1': 'GC=F', 'ticker2': null},
        ],
      }),
    });
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await http.runWithClient(() async {
        await _pumpDash(tester);
        expect(_order(tester), ['SPY', 'SPY', 'GC=F']);

        final from = _handleCenter(tester, 0);
        final to = tester.getCenter(find.byType(DashCard).at(2));
        final gesture = await tester.startGesture(
          from,
          kind: PointerDeviceKind.mouse,
        );
        await tester.pump(const Duration(milliseconds: 50));
        await gesture.moveTo(to);
        await tester.pump(const Duration(milliseconds: 100));
        await gesture.up();
        await tester.pumpAndSettle();

        expect(_order(tester), ['SPY', 'GC=F', 'SPY']);
        expect(tester.takeException(), isNull);
      }, _tickerClient);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('cards without data can still be reordered', (tester) async {
    await http.runWithClient(() async {
      await _pumpDash(tester);
      expect(find.text('Error loading ticker data'), findsNWidgets(4));
      expect(find.byIcon(Icons.drag_indicator), findsNWidgets(4));

      final from = _handleCenter(tester, 0);
      final to = tester.getCenter(find.byType(DashCard).at(1));
      final gesture = await tester.startGesture(from);
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.moveTo(to);
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(_order(tester), ['BTC-USD', 'TSLA', 'GC=F', 'BTC-USD']);
    }, () => MockClient((_) async => http.Response('nope', 500)));
  });
}
