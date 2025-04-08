import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

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
                      topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
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

                            // Show labels only for years divisible by 10 (decades)
                            if (date.year % 10 == 0 && date.month == 1) {
                              return Text(
                                '${date.year}',
                                style: const TextStyle(fontSize: 10),
                              );
                            }
                            return const SizedBox.shrink(); // Hide labels for other years
                          },
                          interval:
                              1, // Keep interval as 1 to evaluate all data points
                        ),
                      ),
                      leftTitles: AxisTitles(
                        axisNameWidget: const Text(
                          'Billions of Dollars',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        axisNameSize: 30,
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 50,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              value.toString(),
                              style: const TextStyle(fontSize: 10),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: true),
                    gridData: FlGridData(
                      show: true,
                      checkToShowVerticalLine: (value) {
                        // Show vertical lines only for years divisible by 10 (decades)
                        final index = value.toInt();
                        if (index < 0 || index >= _m2Data.length) {
                          return false;
                        }
                        final date = _m2Data[index].date;
                        return date.year % 10 == 0 && date.month == 1;
                      },
                      verticalInterval:
                          1, // Keep interval as 1 to evaluate all data points
                    ),
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
                        barWidth: 2,
                        belowBarData: BarAreaData(show: false),
                      ),
                    ],
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (touchedSpot) => Colors.blueAccent,
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((spot) {
                            final index = spot.x.toInt();
                            final date = _m2Data[index].date;
                            final amount = _m2Data[index].amount;

                            // Format the month as an abbreviated word
                            final formattedMonth = DateFormat.MMM().format(
                              date,
                            );

                            return LineTooltipItem(
                              '$formattedMonth ${date.year}\n${amount.toStringAsFixed(2)}',
                              const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          }).toList();
                        },
                      ),
                      handleBuiltInTouches: true,
                    ),
                  ),
                ),
              ),
    );
  }
}
