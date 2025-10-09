import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class PriceLine extends StatelessWidget {
  final List<double> points; // ultimele N close-uri
  const PriceLine({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[
      for (int i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i]),
    ];
    final minY = points.reduce((a, b) => a < b ? a : b);
    final maxY = points.reduce((a, b) => a > b ? a : b);
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(show: false),
        minY: minY,
        maxY: maxY,
        lineTouchData: const LineTouchData(enabled: true),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            dotData: const FlDotData(show: false),
            barWidth: 2,
            color: Colors.white70,
            belowBarData: BarAreaData(
              show: true,
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white24, Colors.transparent],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


