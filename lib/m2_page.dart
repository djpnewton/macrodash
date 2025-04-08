import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import 'package:macrodash_models/models.dart';

import 'data.dart';

enum ZoomLevel { oneYear, fiveYears, tenYears, max }

class M2Page extends StatefulWidget {
  const M2Page({super.key});

  @override
  State<M2Page> createState() => _M2PageState();
}

class _M2PageState extends State<M2Page> {
  final DataDownloader _dataDownloader = DataDownloader();
  List<M2Entry> _m2Data = [];
  List<M2Entry> _filteredData = [];
  bool _isLoading = true;
  ZoomLevel _selectedZoom = ZoomLevel.max; // Default to 'Max'

  @override
  void initState() {
    super.initState();
    _fetchM2Data();
  }

  Future<void> _fetchM2Data() async {
    final data = await _dataDownloader.m2Data();
    setState(() {
      _m2Data = data ?? [];
      _filteredData = _m2Data; // Initially show all data
      _isLoading = false;
    });
  }

  void _filterData(ZoomLevel zoomLevel) {
    setState(() {
      _selectedZoom = zoomLevel;

      if (zoomLevel == ZoomLevel.max) {
        // Show all data (Max)
        _filteredData = _m2Data;
      } else {
        final years =
            {
              ZoomLevel.oneYear: 1,
              ZoomLevel.fiveYears: 5,
              ZoomLevel.tenYears: 10,
            }[zoomLevel]!;

        final cutoffDate = DateTime.now().subtract(Duration(days: years * 365));
        _filteredData =
            _m2Data.where((entry) => entry.date.isAfter(cutoffDate)).toList();
      }
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
              : Column(
                children: [
                  // Zoom Buttons
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.end, // Align buttons to the right
                      children: [
                        ElevatedButton(
                          onPressed: () => _filterData(ZoomLevel.oneYear),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                _selectedZoom == ZoomLevel.oneYear
                                    ? Colors.blue
                                    : Colors.grey, // Highlight selected button
                          ),
                          child: const Text(
                            '1Y',
                            style: TextStyle(
                              color: Colors.white,
                            ), // Set text color to white
                          ),
                        ),
                        const SizedBox(width: 8), // Add spacing between buttons
                        ElevatedButton(
                          onPressed: () => _filterData(ZoomLevel.fiveYears),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                _selectedZoom == ZoomLevel.fiveYears
                                    ? Colors.blue
                                    : Colors.grey, // Highlight selected button
                          ),
                          child: const Text(
                            '5Y',
                            style: TextStyle(
                              color: Colors.white,
                            ), // Set text color to white
                          ),
                        ),
                        const SizedBox(width: 8), // Add spacing between buttons
                        ElevatedButton(
                          onPressed: () => _filterData(ZoomLevel.tenYears),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                _selectedZoom == ZoomLevel.tenYears
                                    ? Colors.blue
                                    : Colors.grey, // Highlight selected button
                          ),
                          child: const Text(
                            '10Y',
                            style: TextStyle(
                              color: Colors.white,
                            ), // Set text color to white
                          ),
                        ),
                        const SizedBox(width: 8), // Add spacing between buttons
                        ElevatedButton(
                          onPressed: () => _filterData(ZoomLevel.max),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                _selectedZoom == ZoomLevel.max
                                    ? Colors.blue
                                    : Colors.grey, // Highlight selected button
                          ),
                          child: const Text(
                            'Max',
                            style: TextStyle(
                              color: Colors.white,
                            ), // Set text color to white
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Line Chart
                  Expanded(
                    child: Padding(
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
                                  if (index < 0 ||
                                      index >= _filteredData.length) {
                                    return const SizedBox.shrink();
                                  }
                                  final date = _filteredData[index].date;

                                  switch (_selectedZoom) {
                                    case ZoomLevel.oneYear:
                                      // Show labels for each month
                                      if (date.day == 1) {
                                        return Text(
                                          '${date.month}/${date.year}',
                                          style: const TextStyle(fontSize: 10),
                                        );
                                      }
                                      break;
                                    case ZoomLevel.fiveYears:
                                    case ZoomLevel.tenYears:
                                      // Show labels for each year
                                      if (date.month == 1) {
                                        return Text(
                                          '${date.year}',
                                          style: const TextStyle(fontSize: 10),
                                        );
                                      }
                                      break;
                                    case ZoomLevel.max:
                                      // Show labels only for years divisible by 10 (decades)
                                      if (date.year % 10 == 0 &&
                                          date.month == 1) {
                                        return Text(
                                          '${date.year}',
                                          style: const TextStyle(fontSize: 10),
                                        );
                                      }
                                      break;
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
                              final index = value.toInt();
                              if (index < 0 || index >= _filteredData.length) {
                                return false;
                              }
                              final date = _filteredData[index].date;
                              switch (_selectedZoom) {
                                case ZoomLevel.oneYear:
                                  // Show vertical lines for each month
                                  return date.day == 1;
                                case ZoomLevel.fiveYears:
                                case ZoomLevel.tenYears:
                                  // Show vertical lines for each year
                                  return date.month == 1;
                                case ZoomLevel.max:
                                  // Show vertical lines only for years divisible by 10 (decades)
                                  return date.year % 10 == 0 && date.month == 1;
                              }
                            },
                            verticalInterval:
                                1, // Keep interval as 1 to evaluate all data points
                          ),
                          lineBarsData: [
                            LineChartBarData(
                              spots:
                                  _filteredData
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
                              getTooltipColor:
                                  (touchedSpot) => Colors.blueAccent,
                              getTooltipItems: (touchedSpots) {
                                return touchedSpots.map((spot) {
                                  final index = spot.x.toInt();
                                  final date = _filteredData[index].date;
                                  final amount = _filteredData[index].amount;

                                  // Format the month as an abbreviated word
                                  final formattedMonth = DateFormat.MMM()
                                      .format(date);

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
                  ),
                ],
              ),
    );
  }
}
