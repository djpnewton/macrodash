import 'dart:convert';

import 'package:macrodash_models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ChartLibrary { flChart, financialChart }

class Settings {
  static const String _chartLibraryKey = 'chartLibrary_b2';

  static Future<SharedPreferences> getPrefs() async {
    return await SharedPreferences.getInstance();
  }

  /// Saves the selected chart library to shared preferences.
  static Future<void> saveChartLibrary(ChartLibrary chartLibrary) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chartLibraryKey, chartLibrary.name);
  }

  /// Loads the selected chart library from shared preferences.
  /// Defaults to `ChartLibrary.flChart` if no value is stored.
  static ChartLibrary loadChartLibrary(SharedPreferences prefs) {
    final value =
        prefs.getString(_chartLibraryKey) ?? ChartLibrary.financialChart.name;
    // If the value is not found, return the default value
    return ChartLibrary.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ChartLibrary.flChart,
    );
  }

  /// Saves a chart setting to shared preferences.
  static Future<void> saveChartSetting(
    String chartName,
    String chartSetting,
    String value,
  ) async {
    final key = '${chartName}_$chartSetting';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  /// Loads a chart setting from shared preferences.
  static String? loadChartSetting(
    SharedPreferences prefs,
    String chartName,
    String chartSetting,
  ) {
    final key = '${chartName}_$chartSetting';
    return prefs.getString(key);
  }

  /// Saves the DashTickers setting to shared preferences.
  static Future<void> saveDashTickers(DashTickers tickers) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('dash_tickers', jsonEncode(tickers.toJson()));
  }

  /// Loads the DashTickers setting from shared preferences.
  /// Returns default tickers if no value is stored.
  static DashTickers loadDashTickers(SharedPreferences prefs) {
    final defaultTickers = const DashTickers(
      tickers: [
        DashTicker(ticker1: 'TSLA', ticker2: null),
        DashTicker(ticker1: 'BTC-USD', ticker2: null),
        DashTicker(ticker1: 'GC=F', ticker2: null),
        DashTicker(ticker1: 'BTC-USD', ticker2: 'GC=F'),
      ],
    );
    final value = prefs.getString('dash_tickers');
    if (value == null) {
      return defaultTickers;
    }
    final savedTickers = DashTickers.fromJson(jsonDecode(value));
    if (savedTickers.tickers.isEmpty) {
      return defaultTickers;
    }
    return savedTickers;
  }
}
