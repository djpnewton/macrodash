import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import 'package:macrodash_models/models.dart';

import 'option_buttons.dart';

class Vis extends StatelessWidget {
  final List<AmountEntry> filteredData;
  final AmountSeries? dataSeries;
  final ZoomLevel selectedZoom;

  const Vis({
    super.key,
    required this.filteredData,
    required this.dataSeries,
    required this.selectedZoom,
  });

  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        titlesData: FlTitlesData(
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= filteredData.length) {
                  return const SizedBox.shrink();
                }
                final date = filteredData[index].date;

                switch (selectedZoom) {
                  case ZoomLevel.oneYear:
                    if (date.day == 1) {
                      return Text(
                        '${date.month}/${date.year}',
                        style: const TextStyle(fontSize: 10),
                      );
                    }
                    break;
                  case ZoomLevel.fiveYears:
                  case ZoomLevel.tenYears:
                    if (date.month == 1) {
                      return Text(
                        '${date.year}',
                        style: const TextStyle(fontSize: 10),
                      );
                    }
                    break;
                  case ZoomLevel.max:
                    if (date.year % 10 == 0 && date.month == 1) {
                      return Text(
                        '${date.year}',
                        style: const TextStyle(fontSize: 10),
                      );
                    }
                    break;
                }
                return const SizedBox.shrink();
              },
              interval: 1,
            ),
          ),
          leftTitles: AxisTitles(
            axisNameWidget: Text(
              dataSeries?.description ?? '',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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
            if (index < 0 || index >= filteredData.length) {
              return false;
            }
            final date = filteredData[index].date;
            switch (selectedZoom) {
              case ZoomLevel.oneYear:
                return date.day == 1;
              case ZoomLevel.fiveYears:
              case ZoomLevel.tenYears:
                return date.month == 1;
              case ZoomLevel.max:
                return date.year % 10 == 0 && date.month == 1;
            }
          },
          verticalInterval: 1,
        ),
        lineBarsData: [
          LineChartBarData(
            spots:
                // TODO: change to use real dates based on the timestamp or something
                // or use a different library
                filteredData
                    .asMap()
                    .entries
                    .map(
                      (entry) =>
                          FlSpot(entry.key.toDouble(), entry.value.amount),
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
                final date = filteredData[index].date;
                final amount = filteredData[index].amount;

                final formattedMonth = DateFormat.MMM().format(date);

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
    );
  }
}
