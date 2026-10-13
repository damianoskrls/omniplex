import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/workout_health.dart';
import '../theme/app_colors.dart';
import '../widgets/ui_kit.dart';
import '../l10n/tr.dart';

class HealthChartsSection extends StatelessWidget {
  const HealthChartsSection({super.key, required this.workouts});

  final List<WorkoutHealthSummary> workouts;

  @override
  Widget build(BuildContext context) {
    if (workouts.isEmpty) return const SizedBox.shrink();

    final recent = workouts.take(12).toList().reversed.toList();
    final withCalories = recent.where((w) => w.caloriesKcal != null && w.caloriesKcal! > 0).toList();
    final withHr = recent.where((w) => w.avgHeartRate != null && w.avgHeartRate! > 0).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (withCalories.isNotEmpty) ...[
          Text(tr('Θερμίδες ανά προπόνηση'), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            tr('Τελευταίες ${withCalories.length} προπονήσεις · Apple Health / Health Connect'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          SurfaceCard(
            child: SizedBox(
              height: 160,
              child: BarChart(
                BarChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(color: AppColors.border, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (v, _) => Text(
                          '${v.toInt()}',
                          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i < 0 || i >= withCalories.length) return const SizedBox.shrink();
                          final d = withCalories[i].startedAt;
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '${d.day}/${d.month}',
                              style: const TextStyle(fontSize: 9, color: AppColors.textSecondary),
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  barGroups: [
                    for (int i = 0; i < withCalories.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: withCalories[i].caloriesKcal!.toDouble(),
                            color: AppColors.lime,
                            width: 14,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
        if (withHr.isNotEmpty) ...[
          Text(tr('Καρδιακός ρυθμός'), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            tr('Μέσος όρος bpm ανά προπόνηση'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          SurfaceCard(
            child: SizedBox(
              height: 140,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(color: AppColors.border, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        getTitlesWidget: (v, _) => Text(
                          '${v.toInt()}',
                          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i < 0 || i >= withHr.length) return const SizedBox.shrink();
                          final d = withHr[i].startedAt;
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '${d.day}/${d.month}',
                              style: const TextStyle(fontSize: 9, color: AppColors.textSecondary),
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        for (int i = 0; i < withHr.length; i++)
                          FlSpot(i.toDouble(), withHr[i].avgHeartRate!.toDouble()),
                      ],
                      isCurved: true,
                      color: const Color(0xFFFF6B6B),
                      barWidth: 2.5,
                      dotData: FlDotData(
                        getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                          radius: 4,
                          color: const Color(0xFFFF6B6B),
                          strokeWidth: 0,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: const Color(0xFFFF6B6B).withValues(alpha: 0.12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              tr('Δεδομένα: Apple Health / Google Health Connect'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
            ),
          ),
        ],
      ],
    );
  }
}
