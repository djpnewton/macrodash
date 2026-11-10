import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:macrodash/dash.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/dash_harness.dart';

/// Text currently in the dialog's fields, in order: title, ticker1, ticker2.
List<String?> _dialogFields(WidgetTester tester) =>
    tester
        .widgetList<TextField>(find.byType(TextField))
        .map((field) => field.controller?.text)
        .toList();

/// Opacity of the "stale" wash over the card at [index].
double _staleOpacity(WidgetTester tester, int index) {
  final wash = find.descendant(
    of: find.byType(DashCard).at(index),
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is ColoredBox &&
          widget.color == Colors.grey.withValues(alpha: 0.25),
    ),
  );
  return tester
      .widget<AnimatedOpacity>(
        find.ancestor(of: wash, matching: find.byType(AnimatedOpacity)),
      )
      .opacity;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('removing a ticker asks first and persists the result', (
    tester,
  ) async {
    await runDashPanelTest(tester, () async {
      expect(cardOrder(tester), hasLength(4));

      await tester.tap(find.byIcon(Icons.remove_circle).first);
      await tester.pumpAndSettle();
      expect(find.text('Remove Ticker'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(cardOrder(tester), hasLength(4));
      expect(await savedTickerSymbols(), isNull);

      await tester.tap(find.byIcon(Icons.remove_circle).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      expect(cardOrder(tester), ['BTC-USD', 'GC=F', 'BTC-USD']);
      expect(await savedTickerSymbols(), ['BTC-USD', 'GC=F', 'BTC-USD']);
    });
  });

  testWidgets('the config dialog starts from the current ticker', (
    tester,
  ) async {
    await runDashPanelTest(tester, () async {
      await tester.tap(find.byIcon(Icons.settings).first);
      await tester.pumpAndSettle();

      expect(find.text('Configure Ticker'), findsOneWidget);
      expect(_dialogFields(tester), ['Tesla', 'TSLA', '']);
    });
  });

  testWidgets('saving the config dialog persists the new title', (
    tester,
  ) async {
    await runDashPanelTest(tester, () async {
      await tester.tap(find.byIcon(Icons.settings).first);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'TSLA Corp');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Configure Ticker'), findsNothing);
      expect(cardOrder(tester), ['TSLA', 'BTC-USD', 'GC=F', 'BTC-USD']);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('dash_tickers'), contains('TSLA Corp'));
    });
  });

  testWidgets('adding a ticker needs a symbol', (tester) async {
    await runDashPanelTest(tester, () async {
      await tester.tap(find.widgetWithText(TextButton, 'Add Ticker'));
      await tester.pumpAndSettle();

      expect(_dialogFields(tester), ['', '', '']);

      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a ticker'), findsOneWidget);
      expect(cardOrder(tester), hasLength(4));

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(cardOrder(tester), hasLength(4));
      expect(await savedTickerSymbols(), isNull);
    });
  });

  testWidgets('searches for a symbol and adds the chosen ticker', (
    tester,
  ) async {
    final client = MockClient((request) async {
      if (request.url.path == '/market/search') {
        return http.Response(
          jsonEncode({
            'data': [
              {'ticker': 'TSLA', 'name': 'Tesla', 'exchange': 'NASDAQ'},
            ],
          }),
          200,
        );
      }
      return http.Response(jsonEncode(tickerResponse()), 200);
    });

    await runDashPanelTest(tester, client: client, () async {
      await tester.tap(find.widgetWithText(TextButton, 'Add Ticker'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.search).first);
      await tester.pumpAndSettle();

      // The lookup is debounced, so wait past it before the results land.
      await tester.enterText(find.byType(TextField).last, 'tes');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      await tester.tap(find.text('TSLA').last);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();

      expect(cardOrder(tester), ['TSLA', 'BTC-USD', 'GC=F', 'BTC-USD', 'TSLA']);
      expect(await savedTickerSymbols(), cardOrder(tester));
    });
  });

  testWidgets('pulling down reloads every card', (tester) async {
    final requests = <Uri>[];
    await runDashPanelTest(
      tester,
      client: tickerClient(requests: requests),
      () async {
        expect(requests, hasLength(4));

        await tester.fling(find.byType(GridView), const Offset(0, 400), 1000);
        await tester.pumpAndSettle();

        expect(requests, hasLength(8));
        expect(cardOrder(tester), hasLength(4));
      },
    );
  });

  testWidgets('an unreachable server does not leave cards loading', (
    tester,
  ) async {
    await runDashPanelTest(
      tester,
      client: tickerClient(statusCode: 500),
      () async {
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.text('Error loading ticker data'), findsNWidgets(4));
      },
    );
  });

  testWidgets('a failed reload keeps the data and marks the card stale', (
    tester,
  ) async {
    var failing = false;
    final client = MockClient(
      (_) async =>
          failing
              ? http.Response('nope', 500)
              : http.Response(jsonEncode(tickerResponse()), 200),
    );

    await runDashPanelTest(tester, client: client, () async {
      expect(_staleOpacity(tester, 0), 0);

      failing = true;
      await tester.fling(find.byType(GridView), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();

      expect(_staleOpacity(tester, 0), 1);
      expect(find.text('Error loading ticker data'), findsNothing);
      expect(cardOrder(tester), hasLength(4));
    });
  });
}
