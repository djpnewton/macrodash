import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';

import 'package:macrodash_models/models.dart';

import 'api.dart';
import 'option_buttons.dart';

final Logger log = Logger('m2_page');

class M2Page extends StatefulWidget {
  const M2Page({super.key});

  @override
  State<M2Page> createState() => _M2PageState();
}

class _M2PageState extends State<M2Page> {
  final ServerApi _api = ServerApi();
  AmountSeries? _m2Series;
  List<AmountEntry> _filteredData = [];
  bool _isLoading = true;
  M2Region _selectedRegion = M2Region.usa;
  ZoomLevel _selectedZoom = ZoomLevel.max; // Default to 'Max'

  @override
  void initState() {
    super.initState();
    _fetchM2Data();
  }

  Future<void> _fetchM2Data() async {
    setState(() {
      _isLoading = true;
    });
    final data = await _api.m2Data(_selectedRegion);
    setState(() {
      _isLoading = false;
      _m2Series = data;
      if (_m2Series == null) {
        return;
      }
      _filterData(_selectedZoom);
    });
  }

  void _regionSelect(M2Region region) {
    setState(() {
      _selectedRegion = region;
      _fetchM2Data();
    });
  }

  void _filterData(ZoomLevel zoomLevel) {
    setState(() {
      _selectedZoom = zoomLevel;

      if (_m2Series == null) {
        log.severe('No M2 data available to filter.');
        return;
      }

      if (zoomLevel == ZoomLevel.max) {
        // Show all data (Max)
        _filteredData = _m2Series!.data;
      } else {
        final years =
            {
              ZoomLevel.oneYear: 1,
              ZoomLevel.fiveYears: 5,
              ZoomLevel.tenYears: 10,
            }[zoomLevel]!;

        final cutoffDate = DateTime.now().subtract(Duration(days: years * 365));
        _filteredData =
            _m2Series!.data
                .where((entry) => entry.date.isAfter(cutoffDate))
                .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('M2 Data Visualization')),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Region Buttons
              RegionButtons(
                selectedRegion: _selectedRegion,
                onRegionSelected: _regionSelect,
              ),
              // Zoom Buttons
              ZoomButtons(
                selectedZoom: _selectedZoom,
                onZoomSelected: (zoomLevel) => _filterData(zoomLevel),
              ),
            ],
          ),
          _isLoading
              ? Expanded(
                child: const Center(child: CircularProgressIndicator()),
              )
              : _m2Series == null
              ? Expanded(child: const Center(child: Text('No data available.')))
              :
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
                              if (index < 0 || index >= _filteredData.length) {
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
                                  if (date.year % 10 == 0 && date.month == 1) {
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
                          axisNameWidget: Text(
                            _m2Series?.description ?? '',
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
                                value.toStringAsFixed(1),
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
                          getTooltipColor: (touchedSpot) => Colors.blueAccent,
                          getTooltipItems: (touchedSpots) {
                            return touchedSpots.map((spot) {
                              final index = spot.x.toInt();
                              final date = _filteredData[index].date;
                              final amount = _filteredData[index].amount;

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
              ),
        ],
      ),
    );
  }
}
