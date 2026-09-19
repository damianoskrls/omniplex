import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../models/user_stats.dart';
import '../services/language_service.dart';
import '../models/workout_metrics.dart';
import '../services/auth_service.dart';
import '../services/demo_workout_metrics_service.dart';
import '../services/health_workout_service.dart';
import '../theme/app_colors.dart';
import '../widgets/ui_kit.dart';

class WorkoutMetricsScreen extends StatefulWidget {
  const WorkoutMetricsScreen({super.key});

  @override
  State<WorkoutMetricsScreen> createState() => _WorkoutMetricsScreenState();
}

class _WorkoutMetricsScreenState extends State<WorkoutMetricsScreen> with TickerProviderStateMixin {
  WorkoutMetricsData? _data;
  UserStats? _stats;
  bool _loading = true;
  bool _syncingHealth = false;
  String? _expandedWorkoutId;

  late final AnimationController _chartAnim;
  late final Animation<double> _chartTween;

  static const _chartColors = [
    AppColors.lime,
    AppColors.purple,
    AppColors.orange,
    AppColors.teal,
    AppColors.pink,
  ];

  @override
  void initState() {
    super.initState();
    _chartAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _chartTween = CurvedAnimation(parent: _chartAnim, curve: Curves.easeOutCubic);
    _load();
  }

  @override
  void dispose() {
    _chartAnim.dispose();
    super.dispose();
  }

  Future<void> _load({bool forceDemo = false}) async {
    setState(() => _loading = true);
    final api = context.read<AuthService>().api;

    UserStats? stats;
    WorkoutMetricsData? data;

    if (forceDemo) {
      data = DemoWorkoutMetricsService.build();
    } else {
      try {
        stats = await api.fetchMyStats();
      } catch (_) {}

      try {
        data = await api.fetchWorkoutMetrics();
      } catch (_) {}

      if (data != null && data.workouts.isEmpty && HealthWorkoutService.instance.isSupported) {
        final healthWorkouts = await HealthWorkoutService.instance.loadRecentWorkouts();
        if (healthWorkouts.isNotEmpty) {
          data = WorkoutMetricsData.fromHealthSummaries(healthWorkouts);
        }
      }

      if (data == null || data.workouts.isEmpty) {
        data = DemoWorkoutMetricsService.build();
      }
    }

    if (!mounted) return;
    setState(() {
      _stats = stats;
      _data = data;
      _loading = false;
    });
    _chartAnim.forward(from: 0);
  }

  Future<void> _syncFromHealth() async {
    setState(() => _syncingHealth = true);
    final workouts = await HealthWorkoutService.instance.loadRecentWorkouts();
    if (!mounted) return;

    if (workouts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context).metricsNoHealthData)),
      );
      setState(() => _syncingHealth = false);
      return;
    }

    setState(() {
      _data = WorkoutMetricsData.fromHealthSummaries(workouts);
      _syncingHealth = false;
    });
    _chartAnim.forward(from: 0);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.of(context).metricsLoadedFromWatch(workouts.length))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: Text(AppStrings.of(context).metricsTitle),
        actions: [
          if (kDebugMode)
            IconButton(
              tooltip: AppStrings.of(context).metricsDemoTooltip,
              onPressed: () => _load(forceDemo: true),
              icon: const Icon(Icons.science_outlined),
            ),
          IconButton(
            tooltip: AppStrings.of(context).metricsRefresh,
            onPressed: _loading ? null : () => _load(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? Center(child: const CircularProgressIndicator(color: AppColors.lime))
          : RefreshIndicator(
              color: AppColors.lime,
              onRefresh: () => _load(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                children: [
                  if (_data?.isDemo == true) _demoBanner(),
                  if (HealthWorkoutService.instance.isSupported) ...[
                    _healthSyncRow(),
                    const SizedBox(height: 16),
                  ],
                  if (_stats != null) ...[
                    _goalCard(_stats!),
                    const SizedBox(height: 16),
                  ],
                  _summaryGrid(_data!.summary),
                  const SizedBox(height: 16),
                  _sectionTitle(AppStrings.of(context).metricsActivityDist),
                  const SizedBox(height: 8),
                  _activityPieCard(_data!.byActivity),
                  const SizedBox(height: 16),
                  _sectionTitle(AppStrings.of(context).metricsWeeklyCalories),
                  const SizedBox(height: 8),
                  _weeklyBarCard(_data!.byWeek),
                  const SizedBox(height: 20),
                  _sectionTitle(AppStrings.of(context).metricsPerWorkout),
                  const SizedBox(height: 8),
                  ..._data!.workouts.map(_workoutTile),
                ],
              ),
            ),
    );
  }

  Widget _demoBanner() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.orange.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.orange.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: AppColors.orange, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                AppStrings.of(context).metricsDemoData,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13, height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _healthSyncRow() {
    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.teal.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.watch, color: AppColors.teal),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Apple Watch / Health', style: TextStyle(fontWeight: FontWeight.w700)),
                Text(
                  _data?.dataSource == 'health' ? AppStrings.of(context).metricsSyncFromWatch : AppStrings.of(context).metricsLoadRecent,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: _syncingHealth ? null : _syncFromHealth,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.teal,
              foregroundColor: AppColors.bg,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            child: _syncingHealth
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(AppStrings.of(context).metricsSync),
          ),
        ],
      ),
    );
  }

  Widget _goalCard(UserStats stats) {
    final target = stats.goal.targetSessions;
    final done = stats.sessionsThisMonth;
    final pct = stats.goalProgressPct.clamp(0, 100);
    final caloriesTarget = target * 350;

    return SurfaceCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            height: 88,
            child: AnimatedBuilder(
              animation: _chartTween,
              builder: (context, _) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 88,
                      height: 88,
                      child: CircularProgressIndicator(
                        value: (pct / 100) * _chartTween.value,
                        strokeWidth: 8,
                        backgroundColor: AppColors.border,
                        color: stats.goalMet ? AppColors.lime : AppColors.purple,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${(pct * _chartTween.value).round()}%',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                        ),
                        const Text('στόχος', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppStrings.of(context).metricsGoalTarget, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 6),
                Text(AppStrings.of(context).metricsDoneOfTarget(done, target), style: const TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 10),
                Text(
                  AppStrings.of(context).metricsCaloriesTarget(caloriesTarget),
                  style: TextStyle(color: AppColors.lime.withValues(alpha: 0.9), fontSize: 13),
                ),
                if (stats.goalMet)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: PillChip(label: AppStrings.of(context).completedAchieved, color: AppColors.lime, textColor: AppColors.bg),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryGrid(WorkoutMetricsSummary summary) {
    final s = AppStrings.of(context);
    final tiles = [
      _StatTileData(s.metricsWorkouts, summary.totalSessions.toString(), Icons.fitness_center, AppColors.purple),
      _StatTileData(s.metricsMinutes, summary.totalDurationMins.toString(), Icons.timer_outlined, AppColors.teal),
      _StatTileData(s.metricsCalories, summary.totalCalories.toString(), Icons.local_fire_department_outlined, AppColors.orange),
      _StatTileData(
        s.metricsAvgHeartRate,
        summary.avgHeartRate?.toString() ?? '—',
        Icons.favorite_outline,
        AppColors.pink,
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.45,
      children: tiles.map((t) => _animatedStatTile(t)).toList(),
    );
  }

  Widget _animatedStatTile(_StatTileData tile) {
    return AnimatedBuilder(
      animation: _chartTween,
      builder: (context, _) {
        final numeric = int.tryParse(tile.value);
        final display = numeric != null ? (numeric * _chartTween.value).round().toString() : tile.value;
        return SurfaceCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(tile.icon, color: tile.color, size: 22),
              const Spacer(),
              Text(display, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              Text(tile.label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700));
  }

  Widget _activityPieCard(List<ActivityBreakdown> items) {
    if (items.isEmpty) {
      return SurfaceCard(
        padding: const EdgeInsets.all(24),
        child: Center(child: Text(AppStrings.of(context).metricsNoData)),
      );
    }

    final sorted = [...items]..sort((a, b) => b.calories.compareTo(a.calories));
    final totalCal = sorted.fold<int>(0, (s, e) => s + e.calories).clamp(1, 1 << 30);

    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 16),
      child: Column(
        children: [
          SizedBox(
            height: 220,
            child: AnimatedBuilder(
              animation: _chartTween,
              builder: (context, _) {
                return PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 52,
                    startDegreeOffset: -90,
                    sections: List.generate(sorted.length, (i) {
                      final item = sorted[i];
                      final value = item.calories.toDouble() * _chartTween.value;
                      final color = _chartColors[i % _chartColors.length];
                      return PieChartSectionData(
                        value: value > 0 ? value : 0.01,
                        color: color,
                        radius: 58,
                        title: value >= totalCal * 0.08 ? '${((item.calories / totalCal) * 100).round()}%' : '',
                        titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                      );
                    }),
                  ),
                  duration: Duration.zero,
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: List.generate(sorted.length, (i) {
              final item = sorted[i];
              return PillChip(
                label: '${item.label} · ${item.sessions}',
                color: _chartColors[i % _chartColors.length].withValues(alpha: 0.2),
                textColor: _chartColors[i % _chartColors.length],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _weeklyBarCard(List<WeekMetric> weeks) {
    if (weeks.isEmpty) return const SizedBox.shrink();

    final maxCal = weeks.map((w) => w.calories).fold<int>(0, (a, b) => a > b ? a : b).clamp(1, 1 << 30);
    final dateFmt = DateFormat('d/M');

    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(8, 20, 12, 12),
      child: SizedBox(
        height: 220,
        child: AnimatedBuilder(
          animation: _chartTween,
          builder: (context, _) {
            return BarChart(
              BarChartData(
                maxY: maxCal.toDouble() * 1.15,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(color: AppColors.border.withValues(alpha: 0.6), strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (v, _) => Text(
                        v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k' : v.toInt().toString(),
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (i, _) {
                        final idx = i.toInt();
                        if (idx < 0 || idx >= weeks.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            dateFmt.format(weeks[idx].weekStart),
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: List.generate(weeks.length, (i) {
                  final w = weeks[i];
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: w.calories.toDouble() * _chartTween.value,
                        width: 16,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        gradient: const LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [AppColors.purple, AppColors.lime],
                        ),
                      ),
                    ],
                  );
                }),
              ),
              duration: Duration.zero,
            );
          },
        ),
      ),
    );
  }

  Widget _workoutTile(WorkoutMetricEntry w) {
    final id = w.id ?? w.startedAt.toIso8601String();
    final expanded = _expandedWorkoutId == id;
    final s = AppStrings.of(context);
    final locale = LanguageService.instance.isGreek ? 'el_GR' : 'en_US';
    final dateFmt = DateFormat('EEE d MMM · HH:mm', locale);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SurfaceCard(
        padding: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _expandedWorkoutId = expanded ? null : id),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.purple.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.directions_run, color: AppColors.purple, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(w.displayTitle, style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text(dateFmt.format(w.startedAt), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                    Icon(expanded ? Icons.expand_less : Icons.expand_more, color: AppColors.textSecondary),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (w.caloriesKcal != null)
                      PillChip(label: '${w.caloriesKcal} kcal', color: AppColors.orange.withValues(alpha: 0.15), textColor: AppColors.orange),
                    PillChip(label: s.minutesSuffix(w.durationMins), color: AppColors.teal.withValues(alpha: 0.15), textColor: AppColors.teal),
                    if (w.avgHeartRate != null)
                      PillChip(label: '♥ ${w.avgHeartRate}', color: AppColors.pink.withValues(alpha: 0.15), textColor: AppColors.pink),
                  ],
                ),
                if (expanded) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  _detailRow(s.metricsActivity, w.activityLabel ?? w.activityType ?? '—'),
                  _detailRow(s.metricsDuration, s.minutesSuffix(w.durationMins)),
                  if (w.caloriesKcal != null) _detailRow(s.metricsCaloriesKcal, '${w.caloriesKcal} kcal'),
                  if (w.avgHeartRate != null) _detailRow(s.metricsHeartRate, '${w.avgHeartRate} bpm'),
                  if (w.distanceM != null) _detailRow(s.metricsDistance, '${(w.distanceM! / 1000).toStringAsFixed(2)} km'),
                  if (w.source != null) _detailRow(s.metricsSource, _sourceLabel(s, w.source!)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
        ],
      ),
    );
  }

  String _sourceLabel(AppStrings s, String source) {
    final labels = {
      'apple_health': 'Apple Health',
      'health_connect': 'Health Connect',
      'demo': s.metricsSourceDemo,
    };
    return labels[source] ?? source;
  }
}

class _StatTileData {
  const _StatTileData(this.label, this.value, this.icon, this.color);

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}
