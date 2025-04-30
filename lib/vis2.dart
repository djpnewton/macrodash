import 'dart:math';
import 'package:flutter/material.dart';
import 'package:financial_chart/financial_chart.dart';

import 'package:macrodash_models/models.dart';

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
    final theme = GThemeLight();
    final dataSource = _getDataSource();
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
                  dataKeys: ['amount'],
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
                          key: 'amount',
                        )!,
                  ),
                ],
                overlayMarkers: [
                  GLabelMarker(
                    text: widget.dataSeries?.description ?? '',
                    anchorCoord: GPositionCoord.rational(x: 0.75, y: 0.5),
                    alignment: Alignment.center,
                    theme: theme.overlayMarkerTheme.copyWith(
                      markerStyle: PaintStyle(),
                      labelStyle: LabelStyle(
                        textStyle: const TextStyle(
                          color: Colors.black,
                          fontSize: 14.0,
                        ),
                        backgroundStyle: PaintStyle(),
                        backgroundPadding: const EdgeInsets.all(5),
                        backgroundCornerRadius: 0,
                        rotation: pi / 2,
                      ),
                    ),
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
            graphs: [GGraphGrids(), GGraphLine(valueKey: 'amount')],
          ),
        ],
      ),
      tickerProvider: this,
    );
  }
}
