import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrodash/dash.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/dash_harness.dart';

/// Drags the grab handle of the card at [from] onto the card at [to].
Future<void> _dragHandle(WidgetTester tester, int from, int to) async {
  final gesture = await tester.startGesture(
    handleCenter(tester, from),
    kind: PointerDeviceKind.mouse,
  );
  await tester.pump(const Duration(milliseconds: 50));
  await gesture.moveTo(tester.getCenter(find.byType(DashCard).at(to)));
  await tester.pump(const Duration(milliseconds: 100));
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  const defaultOrder = ['TSLA', 'BTC-USD', 'GC=F', 'BTC-USD'];

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('dragging a card by its handle onto another moves it there', (
    tester,
  ) async {
    await runDashPanelTest(tester, () async {
      expect(cardOrder(tester), defaultOrder);

      final statesBefore = {
        for (final card in tester.widgetList<DashCard>(find.byType(DashCard)))
          card.ticker.ticker1: tester.state(find.byWidget(card)),
      };

      await _dragHandle(tester, 0, 2);

      expect(cardOrder(tester), ['BTC-USD', 'GC=F', 'TSLA', 'BTC-USD']);

      // The moved card keeps its state instead of reloading.
      final tsla = find.byWidgetPredicate(
        (widget) => widget is DashCard && widget.ticker.ticker1 == 'TSLA',
      );
      expect(identical(tester.state(tsla), statesBefore['TSLA']), isTrue);

      expect(await savedTickerSymbols(), cardOrder(tester));

      // Dragging the card body must not reorder; only the handle does.
      final body = await tester.startGesture(
        tester.getCenter(find.byType(DashCard).first),
        kind: PointerDeviceKind.mouse,
      );
      await body.moveTo(tester.getCenter(find.byType(DashCard).at(2)));
      await tester.pump(const Duration(milliseconds: 100));
      await body.up();
      await tester.pumpAndSettle();
      expect(cardOrder(tester), ['BTC-USD', 'GC=F', 'TSLA', 'BTC-USD']);
    });
  });

  testWidgets('reordering works with a touch drag', (tester) async {
    await runDashPanelTest(tester, () async {
      expect(cardOrder(tester), defaultOrder);

      final gesture = await tester.startGesture(handleCenter(tester, 0));
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.moveTo(tester.getCenter(find.byType(DashCard).at(1)));
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(cardOrder(tester), ['BTC-USD', 'TSLA', 'GC=F', 'BTC-USD']);
    });
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

    await runDashPanelTest(tester, () async {
      expect(cardOrder(tester), ['SPY', 'SPY', 'GC=F']);

      await _dragHandle(tester, 0, 2);

      expect(cardOrder(tester), ['SPY', 'GC=F', 'SPY']);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('cards without data can still be reordered', (tester) async {
    await runDashPanelTest(
      tester,
      client: tickerClient(statusCode: 500),
      () async {
        expect(find.text('Error loading ticker data'), findsNWidgets(4));
        expect(find.byIcon(Icons.drag_indicator), findsNWidgets(4));

        await _dragHandle(tester, 0, 1);

        expect(cardOrder(tester), ['BTC-USD', 'TSLA', 'GC=F', 'BTC-USD']);
      },
    );
  });
}
