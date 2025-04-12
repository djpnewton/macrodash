import 'package:flutter/material.dart';

import 'settings.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  ChartLibrary _selectedChartLibrary = ChartLibrary.flChart;

  @override
  void initState() {
    super.initState();
    _loadChartLibrary();
  }

  Future<void> _loadChartLibrary() async {
    final chartLibrary = await Settings.loadChartLibrary();
    setState(() {
      _selectedChartLibrary = chartLibrary;
    });
  }

  Future<void> _saveChartLibrary(ChartLibrary chartLibrary) async {
    await Settings.saveChartLibrary(chartLibrary);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Chart Library:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            RadioListTile<ChartLibrary>(
              title: const Text('FL Chart'),
              value: ChartLibrary.flChart,
              groupValue: _selectedChartLibrary,
              onChanged: (value) {
                setState(() {
                  _selectedChartLibrary = value!;
                  _saveChartLibrary(value);
                });
              },
            ),
            RadioListTile<ChartLibrary>(
              title: const Text('Financial Chart'),
              value: ChartLibrary.financialChart,
              groupValue: _selectedChartLibrary,
              onChanged: (value) {
                setState(() {
                  _selectedChartLibrary = value!;
                  _saveChartLibrary(value);
                });
              },
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
