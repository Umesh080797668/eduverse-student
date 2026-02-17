import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/quiz.dart';

class ProgressChart extends StatelessWidget {
  final List<QuizResult> results;

  const ProgressChart({super.key, required this.results});

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return const Center(child: Text('No quiz data available'));
    }

    // Take last 5 quizzes
    final recentResults = results.length > 5 ? results.sublist(results.length - 5) : results;

    return AspectRatio(
      aspectRatio: 1.7,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: const Color(0xff2c4260),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Recent Quiz Performance',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: 100,
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => Colors.blueGrey,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          return BarTooltipItem(
                            '${recentResults[groupIndex].quizTitle}\n',
                            const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            children: [
                              TextSpan(
                                text: '${rod.toY.round()}%',
                                style: const TextStyle(color: Colors.yellow, fontSize: 14),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (double value, TitleMeta meta) {
                            if (value.toInt() >= 0 && value.toInt() < recentResults.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  'Q${value.toInt() + 1}',
                                  style: const TextStyle(color: Colors.white, fontSize: 10),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: true, reservedSize: 30, getTitlesWidget: (value, meta){
                           return Text(value.toInt().toString(), style: const TextStyle(color: Colors.white70, fontSize: 10));
                        }),
                      ),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: FlGridData(
                      show: true,
                      checkToShowHorizontalLine: (value) => value % 20 == 0,
                      getDrawingHorizontalLine: (value) => FlLine(color: Colors.white12, strokeWidth: 1),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: recentResults.asMap().entries.map((e) {
                      final result = e.value;
                      final percentage = result.percentage ?? (result.score / result.totalMarks * 100);
                      return BarChartGroupData(
                        x: e.key,
                        barRods: [
                          BarChartRodData(
                            toY: percentage,
                            color: percentage >= 75 ? Colors.greenAccent : (percentage >= 50 ? Colors.amber : Colors.redAccent),
                            width: 16,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
