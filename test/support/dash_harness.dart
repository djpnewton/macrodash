import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:macrodash/dash.dart';
import 'package:macrodash/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A custom ticker payload that parses into a loaded card.
Map<String, dynamic> tickerResponse({
  List<(DateTime, double)>? prices,
  String shortName = 'Tesla',
  String longName = 'Tesla Inc',
  String currency = 'USD',
}) {
  final series =
      prices ?? [(DateTime(2024, 1, 1), 100.0), (DateTime(2024, 1, 2), 110.0)];
  return {
    'ticker1': 'TSLA',
    'ticker2': null,
    'shortName': shortName,
    'longName': longName,
    'sources': ['yahoo'],
    'priceData': [
      for (final (date, amount) in series)
        {'date': date.toIso8601String(), 'amount': amount},
    ],
    'dividendData': <Object>[],
    'currency': currency,
  };
}

/// Answers every request with a valid ticker payload, or with [body].
MockClient tickerClient({
  String? body,
  int statusCode = 200,
  List<Uri>? requests,
}) => MockClient((request) async {
  requests?.add(request.url);
  return http.Response(body ?? jsonEncode(tickerResponse()), statusCode);
});

/// Mounts a [DashPanel] against [client] and runs [body] in the same mock
/// network zone, so reloads started later in the test are answered too.
Future<void> runDashPanelTest(
  WidgetTester tester,
  Future<void> Function() body, {
  MockClient? client,
  Size size = const Size(1400, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await http.runWithClient(() async {
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
    await body();
  }, () => client ?? tickerClient());
}

/// The symbols of the cards on screen, in display order.
List<String> cardOrder(WidgetTester tester) =>
    tester
        .widgetList<DashCard>(find.byType(DashCard))
        .map((card) => card.ticker.ticker1)
        .toList();

/// Centre of the grab handle of the card at [index].
Offset handleCenter(WidgetTester tester, int index) => tester.getCenter(
  find.descendant(
    of: find.byType(DashCard).at(index),
    matching: find.byIcon(Icons.drag_indicator),
  ),
);

/// The symbols saved in preferences, or null when nothing is saved yet.
Future<List<String>?> savedTickerSymbols() async {
  final prefs = await SharedPreferences.getInstance();
  final value = prefs.getString('dash_tickers');
  if (value == null) {
    return null;
  }
  final json = jsonDecode(value) as Map;
  return (json['tickers'] as List).map((t) => t['ticker1'] as String).toList();
}
