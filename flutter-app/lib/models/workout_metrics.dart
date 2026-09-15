import 'workout_health.dart';

class WorkoutMetricEntry {
  const WorkoutMetricEntry({
    this.id,
    this.serviceName,
    required this.startedAt,
    required this.endedAt,
    required this.durationMins,
    this.caloriesKcal,
    this.avgHeartRate,
    this.distanceM,
    this.activityType,
    this.activityLabel,
    this.source,
  });

  final String? id;
  final String? serviceName;
  final DateTime startedAt;
  final DateTime endedAt;
  final int durationMins;
  final int? caloriesKcal;
  final int? avgHeartRate;
  final double? distanceM;
  final String? activityType;
  final String? activityLabel;
  final String? source;

  String get displayTitle => serviceName ?? activityLabel ?? activityType ?? 'Προπόνηση';

  factory WorkoutMetricEntry.fromJson(Map<String, dynamic> json) {
    final startedRaw = json['started_at'] ?? json['starts_at'];
    final endedRaw = json['ended_at'] ?? json['ends_at'];
    return WorkoutMetricEntry(
      id: json['id'] as String?,
      serviceName: json['service_name'] as String?,
      startedAt: DateTime.parse(startedRaw as String).toLocal(),
      endedAt: DateTime.parse(endedRaw as String).toLocal(),
      durationMins: json['duration_mins'] as int? ?? 0,
      caloriesKcal: json['calories_kcal'] as int?,
      avgHeartRate: json['avg_heart_rate'] as int?,
      distanceM: json['distance_m'] != null ? (json['distance_m'] as num).toDouble() : null,
      activityType: json['activity_type'] as String?,
      activityLabel: json['activity_label'] as String?,
      source: json['source'] as String?,
    );
  }
}

class ActivityBreakdown {
  const ActivityBreakdown({
    required this.label,
    required this.sessions,
    required this.calories,
    required this.durationMins,
  });

  final String label;
  final int sessions;
  final int calories;
  final int durationMins;

  factory ActivityBreakdown.fromJson(Map<String, dynamic> json) => ActivityBreakdown(
        label: json['label'] as String? ?? 'Άλλο',
        sessions: json['sessions'] as int? ?? 0,
        calories: json['calories'] as int? ?? 0,
        durationMins: json['duration_mins'] as int? ?? 0,
      );
}

class WeekMetric {
  const WeekMetric({
    required this.weekStart,
    required this.sessions,
    required this.calories,
    required this.durationMins,
  });

  final DateTime weekStart;
  final int sessions;
  final int calories;
  final int durationMins;

  factory WeekMetric.fromJson(Map<String, dynamic> json) => WeekMetric(
        weekStart: DateTime.parse(json['week_start'] as String),
        sessions: json['sessions'] as int? ?? 0,
        calories: json['calories'] as int? ?? 0,
        durationMins: json['duration_mins'] as int? ?? 0,
      );
}

class WorkoutMetricsSummary {
  const WorkoutMetricsSummary({
    required this.totalSessions,
    required this.totalDurationMins,
    required this.totalCalories,
    required this.avgDurationMins,
    this.avgHeartRate,
  });

  final int totalSessions;
  final int totalDurationMins;
  final int totalCalories;
  final int avgDurationMins;
  final int? avgHeartRate;

  factory WorkoutMetricsSummary.fromJson(Map<String, dynamic> json) => WorkoutMetricsSummary(
        totalSessions: json['total_sessions'] as int? ?? 0,
        totalDurationMins: json['total_duration_mins'] as int? ?? 0,
        totalCalories: json['total_calories'] as int? ?? 0,
        avgDurationMins: json['avg_duration_mins'] as int? ?? 0,
        avgHeartRate: json['avg_heart_rate'] as int?,
      );

  static WorkoutMetricsSummary fromWorkouts(List<WorkoutMetricEntry> workouts) {
    if (workouts.isEmpty) {
      return const WorkoutMetricsSummary(
        totalSessions: 0,
        totalDurationMins: 0,
        totalCalories: 0,
        avgDurationMins: 0,
      );
    }
    final totalDuration = workouts.fold<int>(0, (s, w) => s + w.durationMins);
    final totalCalories = workouts.fold<int>(0, (s, w) => s + (w.caloriesKcal ?? 0));
    final hr = workouts.map((w) => w.avgHeartRate).whereType<int>().toList();
    return WorkoutMetricsSummary(
      totalSessions: workouts.length,
      totalDurationMins: totalDuration,
      totalCalories: totalCalories,
      avgDurationMins: (totalDuration / workouts.length).round(),
      avgHeartRate: hr.isEmpty ? null : (hr.reduce((a, b) => a + b) / hr.length).round(),
    );
  }
}

class WorkoutMetricsData {
  const WorkoutMetricsData({
    required this.days,
    required this.isDemo,
    required this.dataSource,
    required this.workouts,
    required this.summary,
    required this.byActivity,
    required this.byWeek,
  });

  final int days;
  final bool isDemo;
  final String dataSource;
  final List<WorkoutMetricEntry> workouts;
  final WorkoutMetricsSummary summary;
  final List<ActivityBreakdown> byActivity;
  final List<WeekMetric> byWeek;

  factory WorkoutMetricsData.fromJson(Map<String, dynamic> json) => WorkoutMetricsData(
        days: json['days'] as int? ?? 30,
        isDemo: json['is_demo'] as bool? ?? false,
        dataSource: 'api',
        workouts: (json['workouts'] as List? ?? [])
            .map((e) => WorkoutMetricEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        summary: WorkoutMetricsSummary.fromJson(json['summary'] as Map<String, dynamic>? ?? {}),
        byActivity: (json['by_activity'] as List? ?? [])
            .map((e) => ActivityBreakdown.fromJson(e as Map<String, dynamic>))
            .toList(),
        byWeek: (json['by_week'] as List? ?? [])
            .map((e) => WeekMetric.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  static WorkoutMetricsData fromHealthSummaries(
    List<WorkoutHealthSummary> summaries, {
    int days = 30,
  }) {
    final workouts = summaries
        .map(
          (w) => WorkoutMetricEntry(
            id: w.externalId,
            startedAt: w.startedAt,
            endedAt: w.endedAt,
            durationMins: w.durationMins,
            caloriesKcal: w.caloriesKcal,
            avgHeartRate: w.avgHeartRate,
            distanceM: w.distanceM,
            activityType: w.activityType,
            activityLabel: w.activityLabel,
            source: w.source,
          ),
        )
        .toList();

    final byActivityMap = <String, ActivityBreakdown>{};
    for (final w in workouts) {
      final key = w.activityLabel ?? w.activityType ?? 'Άλλο';
      final prev = byActivityMap[key];
      byActivityMap[key] = ActivityBreakdown(
        label: key,
        sessions: (prev?.sessions ?? 0) + 1,
        calories: (prev?.calories ?? 0) + (w.caloriesKcal ?? 0),
        durationMins: (prev?.durationMins ?? 0) + w.durationMins,
      );
    }

    final byWeek = _buildWeekBuckets(workouts);

    return WorkoutMetricsData(
      days: days,
      isDemo: false,
      dataSource: 'health',
      workouts: workouts,
      summary: WorkoutMetricsSummary.fromWorkouts(workouts),
      byActivity: byActivityMap.values.toList(),
      byWeek: byWeek,
    );
  }

  static List<WeekMetric> _buildWeekBuckets(List<WorkoutMetricEntry> workouts) {
    final now = DateTime.now();
    return List.generate(7, (i) {
      final weekEnd = now.subtract(Duration(days: (6 - i) * 7));
      final weekStart = DateTime(weekEnd.year, weekEnd.month, weekEnd.day).subtract(const Duration(days: 6));
      final inWeek = workouts.where((w) {
        final d = DateTime(w.startedAt.year, w.startedAt.month, w.startedAt.day);
        return !d.isBefore(weekStart) && !d.isAfter(DateTime(weekEnd.year, weekEnd.month, weekEnd.day));
      });
      return WeekMetric(
        weekStart: weekStart,
        sessions: inWeek.length,
        calories: inWeek.fold<int>(0, (s, w) => s + (w.caloriesKcal ?? 0)),
        durationMins: inWeek.fold<int>(0, (s, w) => s + w.durationMins),
      );
    });
  }
}
