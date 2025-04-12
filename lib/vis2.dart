import 'package:flutter/material.dart';
import 'package:financial_chart/financial_chart.dart';

import 'package:macrodash_models/models.dart';

import 'option_buttons.dart';

class VisFinancialChart extends StatefulWidget {
  final List<AmountEntry> filteredData;
  final AmountSeries? dataSeries;
  final ZoomLevel selectedZoom;

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
        GDataSeriesProperty(key: 'amount', label: 'Amount', precision: 2),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final dataSource = _getDataSource();
    return GChartWidget(
      chart: GChart(
        dataSource: dataSource,
        theme: GThemeLight(),
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
                  dataKeys: ['amount'],
                ),
              ),
            ],
            valueAxes: [GValueAxis()],
            pointAxes: [GPointAxis()],
            graphs: [GGraphGrids(), GGraphLine(valueKey: 'amount')],
          ),
        ],
      ),
      tickerProvider: this,
    );
  }
}
