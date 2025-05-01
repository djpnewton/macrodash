import 'package:flutter/material.dart';
import 'package:financial_chart/financial_chart.dart';
import 'package:intl/intl.dart';

import 'package:macrodash_models/models.dart';

import 'option_buttons.dart';

class VisFinancialChart extends StatefulWidget {
  final List<AmountEntry> filteredData;
  final AmountSeries? dataSeries;
  final DataRange selectedZoom;

  const VisFinancialChart({
    super.key,
    required this.filteredData,
    required this.dataSeries,
    required this.selectedZoom,
  });

  @override
  State<VisFinancialChart> createState() => _VisState();
}

class _VisState extends State<VisFinancialChart> with TickerProviderStateMixin {
  static const valueKey = 'vk_amount';

  @override
  void initState() {
    super.initState();
  }

  GDataSource<int, GData<int>> _getDataSource() {
    return GDataSource<int, GData<int>>(
      dataList:
          widget.filteredData
              .map(
                (entry) => GData<int>(
                  pointValue: entry.date.millisecondsSinceEpoch,
                  seriesValues: [entry.amount],
                ),
              )
              .toList(),
      seriesProperties: [
        GDataSeriesProperty(key: valueKey, label: 'Amount', precision: 2),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = GThemeLight();
    final dataSource = _getDataSource();
    final startValue = widget.filteredData.first.amount;
    final endValue = widget.filteredData.last.amount;
    final change = endValue - startValue;
    final changePercent = (change / startValue) * 100;
    final changePercentString = changePercent.toStringAsFixed(2);
    var timeFrame = ZoomButtons.labels[widget.selectedZoom];
    if (widget.selectedZoom == DataRange.max) {
      final DateFormat formatter = DateFormat('MMMM yyyy');
      final firstDate = widget.filteredData.first.date;
      final dateStr = formatter.format(firstDate);
      timeFrame = 'Since $dateStr';
    }
    return GChartWidget(
      chart: GChart(
        dataSource: dataSource,
        theme: theme,
        // disable scaling by mouse wheel
        pointerScrollMode: GPointerScrollMode.none,
        // set default point range
        pointViewPort: GPointViewPort(
          initialStartPoint: dataSource.firstPoint - 1,
          initialEndPoint: dataSource.lastPoint + 1,
          autoScaleStrategy: null,
        ),

        panels: [
          GPanel(
            valueViewPorts: [
              GValueViewPort(
                valuePrecision: 2,
                autoScaleStrategy: GValueViewPortAutoScaleStrategyMinMax(
                  dataKeys: [valueKey],
                ),
              ),
            ],
            valueAxes: [
              GValueAxis(
                axisMarkers: [
                  GValueAxisMarker.label(
                    labelValue:
                        dataSource.getSeriesValue(
                          point: dataSource.lastPoint,
                          key: valueKey,
                        )!,
                  ),
                ],
              ),
            ],
            pointAxes: [
              GPointAxis(
                axisMarkers: [
                  GPointAxisMarker.label(point: dataSource.lastPoint),
                ],
              ),
            ],
            graphs: [
              GGraphGrids(),
              GGraphLine(
                valueKey: valueKey,
                overlayMarkers: [
                  GLabelMarker(
                    text:
                        '${widget.dataSeries?.description}\n$timeFrame  $changePercentString%',
                    anchorCoord: GPositionCoord.absolute(x: 2, y: 2),
                    alignment: Alignment.bottomRight,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      tickerProvider: this,
    );
  }
}
