import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:macrodash_models/models.dart';

import 'data.dart';

class M2Page extends StatefulWidget {
  const M2Page({super.key});

  @override
  State<M2Page> createState() => _M2PageState();
}

class _M2PageState extends State<M2Page> {
  final DataDownloader _dataDownloader = DataDownloader();
  List<M2Entry> _m2Data = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchM2Data();
  }

  Future<void> _fetchM2Data() async {
    final data = await _dataDownloader.m2Data();
    setState(() {
      _m2Data = data ?? [];
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('M2 Data Visualization')),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _m2Data.isEmpty
              ? const Center(child: Text('No data available.'))
              : Padding(
                padding: const EdgeInsets.all(16.0),
                child: LineChart(
                  LineChartData(
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: true),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index < 0 || index >= _m2Data.length) {
                              return const SizedBox.shrink();
                            }
                            final date = _m2Data[index].date;
                            return Text(
                              '${date.month}/${date.year}',
                              style: const TextStyle(fontSize: 10),
                            );
                          },
                          interval: (_m2Data.length / 6).ceilToDouble(),
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: true),
                    gridData: FlGridData(show: true),
                    lineBarsData: [
                      LineChartBarData(
                        spots:
                            _m2Data
                                .asMap()
                                .entries
                                .map(
                                  (entry) => FlSpot(
                                    entry.key.toDouble(),
                                    entry.value.amount,
                                  ),
                                )
                                .toList(),
                        isCurved: true,
                        //colors: [Colors.blue],
                        barWidth: 2,
                        belowBarData: BarAreaData(show: false),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }
}
