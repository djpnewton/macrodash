import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:macrodash/comparison.dart';
import 'package:macrodash/option_buttons.dart';
import 'package:macrodash_models/models.dart';
import 'package:macrodash_preview/macrodash_preview.dart';

import 'support/dash_harness.dart';

ComparisonSeries series(
  String label,
  List<(DateTime, double)> prices, {
  List<(DateTime, double)> dividends = const [],
}) => ComparisonSeries(
  label: label,
  prices: [
    for (final (date, amount) in prices)
      AmountEntry(date: date, amount: amount),
  ],
  dividends: [
    for (final (date, amount) in dividends)
      AmountEntry(date: date, amount: amount),
  ],
  currency: 'USD',
);

void main() {
  testWidgets('comparison chart spaces shared observations like sparklines', (
    tester,
  ) async {
    final friday = DateTime.utc(2025, 1, 3, 15);
    final minute = friday.add(const Duration(minutes: 1));
    final monday = DateTime.utc(2025, 1, 6, 15);
    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          MaterialApp(
            home: ComparisonView(
              ticker: const DashTicker(
                title: null,
                ticker1: 'AAA',
                ticker2: 'BBB',
              ),
              onClose: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        final chart = tester.widget<LineChart>(find.byType(LineChart)).data;
        expect(chart.maxX, 2);
        expect(chart.gridData.drawVerticalLine, isFalse);
        expect(chart.lineBarsData[0].spots.map((spot) => spot.x), [0, 1, 2]);
        expect(chart.lineBarsData[1].spots.map((spot) => spot.x), [0, 2]);
      },
      () => MockClient((request) async {
        final prices =
            request.url.queryParameters['ticker1'] == 'AAA'
                ? [(friday, 100.0), (minute, 105.0), (monday, 110.0)]
                : [(friday, 100.0), (monday, 110.0)];
        return http.Response(jsonEncode(tickerResponse(prices: prices)), 200);
      }),
    );
  });

  testWidgets('comparison preview compresses the weekend like the chart', (
    tester,
  ) async {
    final friday = DateTime.utc(2025, 1, 3, 15);
    final bytes = await tester.runAsync(
      () => renderComparisonPreviewPng([
        series('AAA', [
          (friday, 100),
          (friday.add(const Duration(minutes: 1)), 110),
          (DateTime.utc(2025, 1, 6, 15), 120),
        ]),
      ], rangeLabel: '7D'),
    );
    final decoded = await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(bytes!);
      final frame = await codec.getNextFrame();
      codec.dispose();
      final image = frame.image;
      final data =
          (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      final result = (image.width, data);
      image.dispose();
      return result;
    });
    final (width, data) = decoded!;
    final offset = (435 * width + 635) * 4;
    expect(
      Color.fromARGB(
        data.getUint8(offset + 3),
        data.getUint8(offset),
        data.getUint8(offset + 1),
        data.getUint8(offset + 2),
      ),
      comparisonColors[0],
    );
  });

  testWidgets('comparison preview draws series and legend in matching colors', (
    tester,
  ) async {
    final points = [(DateTime(2025), 100.0), (DateTime(2025, 1, 2), 120.0)];
    final bytes = await tester.runAsync(
      () => renderComparisonPreviewPng([
        series('AAA', points),
        series('BBB', [(DateTime(2025), 100), (DateTime(2025, 1, 2), 80)]),
      ], rangeLabel: '1Y'),
    );
    final decoded = await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(bytes!);
      final frame = await codec.getNextFrame();
      codec.dispose();
      final image = frame.image;
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final result = (image.width, image.height, data!);
      image.dispose();
      return result;
    });
    final (width, height, data) = decoded!;
    expect(width, 1200);
    expect(height, 630);
    Color pixel(int x, int y) {
      final offset = (y * width + x) * 4;
      return Color.fromARGB(
        data.getUint8(offset + 3),
        data.getUint8(offset),
        data.getUint8(offset + 1),
        data.getUint8(offset + 2),
      );
    }

    expect(pixel(205, 222), comparisonColors[0]);
    expect(pixel(505, 222), comparisonColors[1]);
    expect(pixel(1120, 330), comparisonColors[0]);
    expect(pixel(1120, 540), comparisonColors[1]);
  });

  test('normalizes each series within the shared window', () {
    final d1 = DateTime(2024, 1, 1);
    final d2 = DateTime(2024, 1, 2);
    final d3 = DateTime(2024, 1, 3);
    final d4 = DateTime(2024, 1, 4);
    final result =
        normalizeComparison([
          series(
            'A',
            [(d4, 400), (d1, 100), (d2, 200), (d3, 300)],
            dividends: [(d1, 1), (d2, 2)],
          ),
          series('B', [(d2, 20), (d3, 10)]),
        ])!;
    expect(result[0].prices.map((e) => e.amount), [100, 150]);
    expect(result[1].prices.map((e) => e.amount), [100, 50]);
    expect(result[0].dividends.map((e) => e.amount), [2]);
  });

  test('YTD cutoff excludes the prior year and keeps same-day dividends', () {
    final cutoff = DateTime(2024);
    final result =
        normalizeComparison([
          series(
            'A',
            [
              (DateTime(2023, 12, 31), 10),
              (DateTime(2024, 1, 2, 15), 20),
              (DateTime(2024, 1, 3, 15), 30),
            ],
            dividends: [
              (DateTime(2023, 12, 31), 1),
              (DateTime(2024, 1, 2, 9), 2),
            ],
          ),
        ], cutoff: cutoff)!;
    expect(result.single.prices.map((e) => e.amount), [100, 150]);
    expect(result.single.dividends.single.amount, 2);
  });

  test('rejects zero baselines, non-overlap and too few observations', () {
    final a = DateTime(2024, 1, 1);
    final b = DateTime(2024, 1, 2);
    final c = DateTime(2024, 1, 3);
    final d = DateTime(2024, 1, 4);
    expect(
      normalizeComparison([
        series('A', [(a, 0), (b, 1)]),
      ]),
      isNull,
    );
    expect(
      normalizeComparison([
        series('A', [(a, 1), (b, 2)]),
        series('B', [(c, 1), (d, 2)]),
      ]),
      isNull,
    );
    expect(
      normalizeComparison([
        series('A', [(a, double.nan), (b, 2)]),
      ]),
      isNull,
    );
  });

  testWidgets(
    'ranges, overlays, dividends and removal use the requested API data',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final requests = <Uri>[];
      final year = DateTime.now().year;
      final prices = [
        (DateTime(year - 1, 12, 31), 50.0),
        (DateTime(year, 1, 2), 100.0),
        (DateTime(year, 1, 3), 110.0),
      ];
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            MaterialApp(
              home: ComparisonView(
                ticker: const DashTicker(
                  title: null,
                  ticker1: 'TSLA',
                  ticker2: null,
                ),
                onClose: () {},
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(requests.last.queryParameters['range'], 'sevenDays');
          expect(
            find.textContaining('TSLA · Jan 2, $year · 0.50 USD'),
            findsOneWidget,
          );

          await tester.tap(find.text('YTD'));
          await tester.pumpAndSettle();
          expect(requests.last.queryParameters['range'], 'oneYear');
          expect(find.byType(ComparisonView), findsOneWidget);

          await tester.enterText(find.byType(TextField), 'aapl');
          await tester.tap(find.text('Add'));
          await tester.pumpAndSettle();
          expect(requests.last.queryParameters['ticker1'], 'AAPL');
          expect(requests.last.queryParameters['range'], 'oneYear');
          expect(find.text('AAPL'), findsWidgets);

          await tester.tap(find.byTooltip('Delete').last);
          await tester.pumpAndSettle();
          expect(requests.last.queryParameters['ticker1'], 'TSLA');
          expect(find.text('AAPL'), findsNothing);
        },
        () => MockClient((request) async {
          requests.add(request.url);
          final response = tickerResponse(prices: prices);
          response['dividendData'] = [
            {'date': DateTime(year, 1, 2).toIso8601String(), 'amount': 0.5},
          ];
          return http.Response(jsonEncode(response), 200);
        }),
      );
    },
  );

  testWidgets('reports failures and retries', (tester) async {
    var failed = true;
    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          MaterialApp(
            home: ComparisonView(
              ticker: const DashTicker(
                title: null,
                ticker1: 'TSLA',
                ticker2: null,
              ),
              onClose: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('TSLA: Server returned 500'), findsOneWidget);
        failed = false;
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('comparison-error')), findsNothing);
        expect(find.textContaining('Indexed to 100'), findsOneWidget);
      },
      () => MockClient(
        (_) async =>
            failed
                ? http.Response('error', 500)
                : http.Response(jsonEncode(tickerResponse()), 200),
      ),
    );
  });

  testWidgets('comparison controls and chart fit a phone viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: ComparisonView(
            ticker: const DashTicker(
              title: null,
              ticker1: 'TSLA',
              ticker2: null,
            ),
            onClose: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('YTD'), findsOneWidget);
      expect(find.textContaining('Indexed to 100'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, () => tickerClient());
  });

  testWidgets('ignores a superseded range response', (tester) async {
    final oldRequest = Completer<http.Response>();
    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          MaterialApp(
            home: ComparisonView(
              ticker: const DashTicker(
                title: null,
                ticker1: 'TSLA',
                ticker2: null,
              ),
              onClose: () {},
            ),
          ),
        );
        await tester.pump();
        await tester.tap(find.text('1M'));
        await tester.pumpAndSettle();
        oldRequest.complete(http.Response('error', 500));
        await tester.pump();
        expect(find.byKey(const ValueKey('comparison-error')), findsNothing);
        expect(find.textContaining('Indexed to 100'), findsOneWidget);
      },
      () => MockClient((request) async {
        if (request.url.queryParameters['range'] == 'sevenDays') {
          return oldRequest.future;
        }
        return http.Response(jsonEncode(tickerResponse()), 200);
      }),
    );
  });

  testWidgets('paired cards compare their constituents independently', (
    tester,
  ) async {
    final requests = <Uri>[];
    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          MaterialApp(
            home: ComparisonView(
              ticker: const DashTicker(
                title: null,
                ticker1: 'BTC-USD',
                ticker2: 'GC=F',
              ),
              onClose: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(requests.map((request) => request.queryParameters['ticker1']), [
          'BTC-USD',
          'GC=F',
        ]);
        expect(
          requests.every(
            (request) => request.queryParameters['ticker2']!.isEmpty,
          ),
          isTrue,
        );
        expect(find.text('BTC-USD'), findsOneWidget);
        expect(find.text('GC=F'), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'BTC-USD');
        await tester.tap(find.text('Add'));
        await tester.pumpAndSettle();
        expect(find.text('Ticker already added.'), findsOneWidget);
        expect(requests, hasLength(2));
      },
      () => MockClient((request) async {
        requests.add(request.url);
        return http.Response(jsonEncode(tickerResponse()), 200);
      }),
    );
  });

  testWidgets('ticker chips track the chart colors after removal', (
    tester,
  ) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: ComparisonView(
            ticker: const DashTicker(
              title: null,
              ticker1: 'AAA',
              ticker2: 'BBB',
            ),
            onClose: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'CCC');
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'DDD');
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      Color? chipColor(String symbol) {
        final chip = find.ancestor(
          of: find.text(symbol),
          matching: find.byWidgetPredicate(
            (widget) => widget is Chip || widget is InputChip,
          ),
        );
        return tester
            .widget<Icon>(
              find.descendant(of: chip, matching: find.byIcon(Icons.circle)),
            )
            .color;
      }

      expect(chipColor('AAA'), comparisonColors[0]);
      expect(chipColor('BBB'), comparisonColors[1]);
      expect(chipColor('CCC'), comparisonColors[2]);
      expect(chipColor('DDD'), comparisonColors[3]);
      await tester.tap(find.byTooltip('Delete').first);
      await tester.pumpAndSettle();
      expect(chipColor('DDD'), comparisonColors[2]);
    }, () => tickerClient());
  });

  testWidgets('copied comparison link reopens its symbols and range', (
    tester,
  ) async {
    final requests = <Uri>[];
    String? copiedText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copiedText =
              (call.arguments as Map<dynamic, dynamic>)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: ComparisonView(
            ticker: const DashTicker(
              title: null,
              ticker1: 'BTC-USD',
              ticker2: 'GC=F',
            ),
            onClose: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('1Y'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '^GSPC');
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Share comparison'));
      await tester.pumpAndSettle();
      expect(find.textContaining('/compare?'), findsOneWidget);
      final preview = tester.widget<SharePreviewImage>(
        find.byType(SharePreviewImage),
      );
      final previewUri = Uri.parse(preview.url);
      expect(previewUri.path, '/compare/preview_image');
      expect(previewUri.queryParameters['range'], 'oneYear');
      expect(jsonDecode(previewUri.queryParameters['tickers']!), [
        'BTC-USD',
        'GC=F',
        '^GSPC',
      ]);
      await tester.tap(find.text('Copy Link'));
      await tester.pumpAndSettle();
      expect(copiedText, isNotNull);
      final link = Uri.parse(copiedText!);
      expect(link.path, '/compare');
      final location = Uri.parse(
        comparisonAppUrl(
          appUrl: 'https://macrodash.me',
          params: link.queryParameters,
        ),
      );
      final appLocation = Uri.parse(location.fragment);
      expect(appLocation.path, '/compare');
      expect(jsonDecode(appLocation.queryParameters['tickers']!), [
        'BTC-USD',
        'GC=F',
        '^GSPC',
      ]);
      expect(appLocation.queryParameters['range'], 'oneYear');
      expect(appLocation.queryParameters['baseCount'], '2');

      requests.clear();
      final router = GoRouter(
        initialLocation: appLocation.toString(),
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: Text('Dashboard')),
            routes: [comparisonRoute()],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(requests.map((r) => r.queryParameters['ticker1']), [
        'BTC-USD',
        'GC=F',
        '^GSPC',
      ]);
      expect(
        requests.every((r) => r.queryParameters['range'] == 'oneYear'),
        isTrue,
      );
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '1Y'))
            .selected,
        isTrue,
      );
      expect(find.text('^GSPC'), findsOneWidget);
      expect(find.byTooltip('Delete'), findsOneWidget);
      await tester.tap(find.byTooltip('Back to chart'));
      await tester.pumpAndSettle();
      expect(find.text('Dashboard'), findsOneWidget);
    }, () => tickerClient(requests: requests));
  });

  testWidgets('invalid comparison links show an error without a request', (
    tester,
  ) async {
    final requests = <Uri>[];
    final router = GoRouter(
      initialLocation: '/compare?tickers=invalid&baseCount=1&range=sevenDays',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('Dashboard')),
          routes: [comparisonRoute()],
        ),
      ],
    );
    addTearDown(router.dispose);
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.text('Invalid comparison link.'), findsOneWidget);
      expect(requests, isEmpty);
      await tester.tap(find.text('Go to dashboard'));
      await tester.pumpAndSettle();
      expect(find.text('Dashboard'), findsOneWidget);
    }, () => tickerClient(requests: requests));
  });
}
