import 'package:flutter/material.dart';
import 'package:financial_chart/financial_chart.dart';
import 'package:intl/intl.dart';

import 'package:macrodash_models/models.dart';

import 'theme.dart';

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

  Widget _buildInfoCard(BuildContext context) {
    if (widget.filteredData.isEmpty) {
      return const SizedBox.shrink();
    }
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
    return Positioned(
      top: 2,
      left: 2,
      child: Card(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.92),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.dataSeries?.description}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text('Time Frame: $timeFrame'),
              Row(
                children: [
                  Text('Change: '),
                  Text(
                    '${change.toStringAsFixed(2)} ($changePercentString%)',
                    style: TextStyle(
                      color:
                          change >= 0
                              ? context.appColors.gain
                              : context.appColors.loss,
                    ),
                  ),
                ],
              ),
              ...?widget.dataSeries?.sources.map(
                (source) => Text(
                  source,
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context).brightness == Brightness.dark
            ? GThemeDark()
            : GThemeLight();
    final dataSource = _getDataSource();
    return Stack(
      children: [
        GChartWidget(
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
                            ) ??
                            0,
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
                graphs: [GGraphGrids(), GGraphLine(valueKey: valueKey)],
              ),
            ],
          ),
          tickerProvider: this,
        ),
        _buildInfoCard(context),
      ],
    );
  }
}
