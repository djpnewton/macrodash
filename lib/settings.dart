import 'package:shared_preferences/shared_preferences.dart';

enum ChartLibrary { flChart, financialChart }

class Settings {
  static const String _chartLibraryKey = 'chartLibrary';

  /// Saves the selected chart library to shared preferences.
  static Future<void> saveChartLibrary(ChartLibrary chartLibrary) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chartLibraryKey, chartLibrary.name);
  }

  /// Loads the selected chart library from shared preferences.
  /// Defaults to `ChartLibrary.flChart` if no value is stored.
  static Future<ChartLibrary> loadChartLibrary() async {
    final prefs = await SharedPreferences.getInstance();
    final value =
        prefs.getString(_chartLibraryKey) ?? ChartLibrary.flChart.name;
    // If the value is not found, return the default value
    return ChartLibrary.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ChartLibrary.flChart,
    );
  }
}
