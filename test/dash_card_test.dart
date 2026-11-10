import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:macrodash/dash.dart';
import 'package:macrodash/theme.dart';
import 'package:macrodash_models/models.dart';

Map<String, dynamic> _tickerJson(
  List<(DateTime, double)> prices, {
  String shortName = 'Tesla',
  String longName = 'Tesla Inc',
}) => {
  'ticker1': 'TSLA',
  'ticker2': null,
  'shortName': shortName,
  'longName': longName,
  'sources': ['yahoo'],
  'priceData': [
    for (final (date, amount) in prices)
      {'date': date.toIso8601String(), 'amount': amount},
  ],
  'dividendData': <Object>[],
  'currency': 'USD',
};

/// Pumps a single dashboard card that is answered with [json].
Future<void> _pumpCard(
  WidgetTester tester, {
  required Map<String, dynamic> json,
  int statusCode = 200,
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
    () => MockClient((_) async => http.Response(jsonEncode(json), statusCode)),
  );
}

void main() {
  testWidgets('shows the 24h change and toggles to the 7d window', (
    tester,
  ) async {
    final now = DateTime.now();
    await _pumpCard(
      tester,
      json: _tickerJson([
        (now.subtract(const Duration(days: 6)), 100),
        (now.subtract(const Duration(hours: 12)), 200),
        (now, 210),
      ]),
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
      json: _tickerJson([
        (now.subtract(const Duration(days: 6)), 300),
        (now.subtract(const Duration(hours: 12)), 200),
        (now, 150),
      ]),
    );

    expect(find.text('-25.00%'), findsOneWidget);
  });

  testWidgets('shows the drag handle next to the loaded data', (tester) async {
    final now = DateTime.now();
    await _pumpCard(
      tester,
      json: _tickerJson([
        (now.subtract(const Duration(hours: 1)), 100),
        (now, 110),
      ]),
    );

    expect(find.byIcon(Icons.drag_indicator), findsOneWidget);
    expect(find.byIcon(Icons.settings), findsOneWidget);
  });

  testWidgets('shows the handle and an error message when loading fails', (
    tester,
  ) async {
    await _pumpCard(tester, json: const {}, statusCode: 500);

    expect(find.text('Error loading ticker data'), findsOneWidget);
    expect(find.byIcon(Icons.drag_indicator), findsOneWidget);
  });

  testWidgets('only shows a subtitle that adds something', (tester) async {
    final now = DateTime.now();
    final prices = <(DateTime, double)>[
      (now.subtract(const Duration(hours: 1)), 100),
      (now, 110),
    ];

    await _pumpCard(
      tester,
      ticker: const DashTicker(title: null, ticker1: 'TSLA', ticker2: null),
      json: _tickerJson(prices, shortName: 'Tesla', longName: 'Tesla Inc'),
    );
    expect(find.text('Tesla'), findsOneWidget);
    expect(find.text('Tesla Inc'), findsOneWidget);

    await _pumpCard(
      tester,
      ticker: const DashTicker(title: null, ticker1: 'TSLA', ticker2: null),
      json: _tickerJson(prices, shortName: 'Tesla', longName: 'Tesla'),
    );
    expect(find.text('Tesla'), findsOneWidget);
  });
}
