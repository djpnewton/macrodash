import 'package:flutter/material.dart';

import 'config.dart';
import 'settings.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  ChartLibrary _selectedChartLibrary = ChartLibrary.flChart;
  ThemeMode _selectedThemeMode = defaultThemeMode;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await Settings.getPrefs();
    setState(() {
      _selectedChartLibrary = Settings.loadChartLibrary(prefs);
      _selectedThemeMode = Settings.loadThemeMode(prefs);
    });
  }

  Future<void> _saveChartLibrary(ChartLibrary chartLibrary) async {
    await Settings.saveChartLibrary(chartLibrary);
  }

  Future<void> _saveThemeMode(ThemeMode themeMode) async {
    themeModeNotifier.value = themeMode;
    await Settings.saveThemeMode(themeMode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Theme:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            RadioGroup<ThemeMode>(
              groupValue: _selectedThemeMode,
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _selectedThemeMode = value;
                  _saveThemeMode(value);
                });
              },
              child: const Column(
                children: [
                  RadioListTile<ThemeMode>(
                    title: Text('System'),
                    value: ThemeMode.system,
                  ),
                  RadioListTile<ThemeMode>(
                    title: Text('Light'),
                    value: ThemeMode.light,
                  ),
                  RadioListTile<ThemeMode>(
                    title: Text('Dark'),
                    value: ThemeMode.dark,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Select Chart Library:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            RadioGroup<ChartLibrary>(
              groupValue: _selectedChartLibrary,
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _selectedChartLibrary = value;
                  _saveChartLibrary(value);
                });
              },
              child: const Column(
                children: [
                  RadioListTile<ChartLibrary>(
                    title: Text('FL Chart'),
                    value: ChartLibrary.flChart,
                  ),
                  RadioListTile<ChartLibrary>(
                    title: Text('Financial Chart'),
                    value: ChartLibrary.financialChart,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Selected Chart Library: ${_selectedChartLibrary.name}',
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
