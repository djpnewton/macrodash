import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrodash/config.dart';
import 'package:macrodash/settings.dart';
import 'package:macrodash_models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('dash tickers', () {
    test('falls back to the sample tickers when nothing is saved', () {
      final tickers = Settings.loadDashTickers(prefs);
      expect(tickers.tickers.map((ticker) => ticker.ticker1), [
        'TSLA',
        'BTC-USD',
        'GC=F',
        'BTC-USD',
      ]);
    });

    test('round-trips the saved tickers in order', () async {
      const saved = DashTickers(
        tickers: [
          DashTicker(title: 'Gold', ticker1: 'GC=F', ticker2: null),
          DashTicker(title: 'BTC vs GLD', ticker1: 'BTC-USD', ticker2: 'GC=F'),
        ],
      );
      await Settings.saveDashTickers(saved);
      expect(Settings.loadDashTickers(await Settings.getPrefs()), saved);
    });

    test(
      'falls back to the sample tickers when the saved list is empty',
      () async {
        await Settings.saveDashTickers(const DashTickers(tickers: []));
        final tickers = Settings.loadDashTickers(await Settings.getPrefs());
        expect(tickers.tickers, hasLength(4));
      },
    );
  });

  group('chart library', () {
    test('defaults to the financial chart', () {
      expect(Settings.loadChartLibrary(prefs), ChartLibrary.financialChart);
    });

    test('round-trips the selected library', () async {
      await Settings.saveChartLibrary(ChartLibrary.flChart);
      expect(
        Settings.loadChartLibrary(await Settings.getPrefs()),
        ChartLibrary.flChart,
      );
    });

    test('falls back to fl_chart for an unknown stored value', () async {
      // Stored under the same key Settings writes.
      SharedPreferences.setMockInitialValues({'chartLibrary_b2': 'nonsense'});
      expect(
        Settings.loadChartLibrary(await SharedPreferences.getInstance()),
        ChartLibrary.flChart,
      );
    });
  });

  group('theme mode', () {
    test('defaults to the configured default', () {
      expect(Settings.loadThemeMode(prefs), defaultThemeMode);
    });

    test('round-trips the selected mode', () async {
      await Settings.saveThemeMode(ThemeMode.dark);
      expect(Settings.loadThemeMode(await Settings.getPrefs()), ThemeMode.dark);
    });
  });

  group('auto refresh', () {
    test('defaults to the configured interval', () {
      expect(
        Settings.loadAutoRefreshMinutes(prefs),
        Settings.defaultAutoRefreshMinutes,
      );
    });

    test('round-trips the interval, including disabled', () async {
      await Settings.saveAutoRefreshMinutes(0);
      expect(Settings.loadAutoRefreshMinutes(await Settings.getPrefs()), 0);

      await Settings.saveAutoRefreshMinutes(30);
      expect(Settings.loadAutoRefreshMinutes(await Settings.getPrefs()), 30);
    });
  });

  group('chart settings', () {
    test('round-trips a per-chart setting', () async {
      await Settings.saveChartSetting('ticker', 'chartType', 'line');
      expect(
        Settings.loadChartSetting(
          await Settings.getPrefs(),
          'ticker',
          'chartType',
        ),
        'line',
      );
    });

    test('returns null for a setting that was never saved', () {
      expect(Settings.loadChartSetting(prefs, 'ticker', 'chartType'), isNull);
    });
  });
}
