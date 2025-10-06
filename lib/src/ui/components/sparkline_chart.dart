import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class SparklineChart extends StatelessWidget {
  final List<double> data;
  const SparklineChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (data.isEmpty) {
      return Center(
          child: Text('No data', style: TextStyle(color: cs.outline)));
    }
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            isCurved: true,
            barWidth: 2,
            color: cs.primary,
            dotData: const FlDotData(show: false),
            spots: [
              for (var i = 0; i < data.length; i++)
                FlSpot(i.toDouble(), data[i])
            ],
          ),
        ],
      ),
    );
  }
}

