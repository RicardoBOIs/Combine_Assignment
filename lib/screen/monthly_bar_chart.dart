import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class MonthlyBarChart extends StatelessWidget {
  final List<String> labels;
  final List<double> values;

  const MonthlyBarChart({Key? key, required this.labels, required this.values})
    : assert(labels.length == values.length),
      super(key: key);

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(child: Text('No data for this period')),
      );
    }
    final maxY = values.reduce((a, b) => a > b ? a : b) * 1.2;
    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceBetween,
          gridData: FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  return Text(labels[idx], style: TextStyle(fontSize: 10));
                },
                interval: 1,
                reservedSize: 30,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: false,
                interval: maxY / 5, // or whatever interval you prefer
                reservedSize: 30, // space to reserve on the left
              ),
            ),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          barGroups:
              values
                  .asMap()
                  .entries
                  .map(
                    (e) => BarChartGroupData(
                      x: e.key,
                      barRods: [
                        BarChartRodData(
                          toY: e.value,
                          width: 16,
                          color: Colors.green.shade900, // ← your bar colour
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                  )
                  .toList(),
          maxY: maxY,
          minY: 0,
        ),
      ),
    );
  }
}
