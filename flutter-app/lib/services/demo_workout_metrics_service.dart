import '../models/workout_metrics.dart';

/// Rich sample workout metrics for previewing charts when no sync exists.
class DemoWorkoutMetricsService {
  DemoWorkoutMetricsService._();

  static WorkoutMetricsData build({int days = 30}) {
    final now = DateTime.now();
    final templates = [
      _DemoWorkout(
        daysAgo: 2,
        hour: 18,
        serviceName: 'Personal Training',
        activityLabel: 'Άσκηση με βάρη',
        activityType: 'TRADITIONAL_STRENGTH_TRAINING',
        durationMins: 58,
        calories: 412,
        avgHr: 128,
      ),
      _DemoWorkout(
        daysAgo: 4,
        hour: 7,
        serviceName: 'HIIT Group',
        activityLabel: 'HIIT',
        activityType: 'HIGH_INTENSITY_INTERVAL_TRAINING',
        durationMins: 42,
        calories: 486,
        avgHr: 152,
      ),
      _DemoWorkout(
        daysAgo: 6,
        hour: 19,
        serviceName: 'Yoga Flow',
        activityLabel: 'Yoga',
        activityType: 'YOGA',
        durationMins: 55,
        calories: 198,
        avgHr: 98,
      ),
      _DemoWorkout(
        daysAgo: 9,
        hour: 17,
        serviceName: 'Personal Training',
        activityLabel: 'Functional training',
        activityType: 'FUNCTIONAL_STRENGTH_TRAINING',
        durationMins: 50,
        calories: 378,
        avgHr: 121,
      ),
      _DemoWorkout(
        daysAgo: 12,
        hour: 8,
        serviceName: 'Τρέξιμο',
        activityLabel: 'Τρέξιμο',
        activityType: 'RUNNING',
        durationMins: 35,
        calories: 320,
        avgHr: 145,
        distanceM: 5200,
      ),
      _DemoWorkout(
        daysAgo: 15,
        hour: 18,
        serviceName: 'Pilates',
        activityLabel: 'Pilates',
        activityType: 'PILATES',
        durationMins: 48,
        calories: 210,
        avgHr: 102,
      ),
      _DemoWorkout(
        daysAgo: 18,
        hour: 19,
        serviceName: 'HIIT Group',
        activityLabel: 'HIIT',
        activityType: 'HIGH_INTENSITY_INTERVAL_TRAINING',
        durationMins: 40,
        calories: 455,
        avgHr: 149,
      ),
      _DemoWorkout(
        daysAgo: 22,
        hour: 17,
        serviceName: 'Personal Training',
        activityLabel: 'Άσκηση με βάρη',
        activityType: 'TRADITIONAL_STRENGTH_TRAINING',
        durationMins: 62,
        calories: 430,
        avgHr: 131,
      ),
      _DemoWorkout(
        daysAgo: 26,
        hour: 7,
        serviceName: 'Core & Mobility',
        activityLabel: 'Core training',
        activityType: 'CORE_TRAINING',
        durationMins: 38,
        calories: 245,
        avgHr: 115,
      ),
      _DemoWorkout(
        daysAgo: 28,
        hour: 18,
        serviceName: 'Cycling',
        activityLabel: 'Ποδήλατο',
        activityType: 'CYCLING',
        durationMins: 45,
        calories: 390,
        avgHr: 138,
        distanceM: 14500,
      ),
    ];

    final workouts = templates.map((t) {
      final day = now.subtract(Duration(days: t.daysAgo));
      final start = DateTime(day.year, day.month, day.day, t.hour, 15);
      return WorkoutMetricEntry(
        id: 'demo-${t.daysAgo}',
        serviceName: t.serviceName,
        startedAt: start,
        endedAt: start.add(Duration(minutes: t.durationMins)),
        durationMins: t.durationMins,
        caloriesKcal: t.calories,
        avgHeartRate: t.avgHr,
        distanceM: t.distanceM,
        activityType: t.activityType,
        activityLabel: t.activityLabel,
        source: 'demo',
      );
    }).toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));

    final byActivityMap = <String, ActivityBreakdown>{};
    for (final w in workouts) {
      final key = w.activityLabel ?? 'Άλλο';
      final prev = byActivityMap[key];
      byActivityMap[key] = ActivityBreakdown(
        label: key,
        sessions: (prev?.sessions ?? 0) + 1,
        calories: (prev?.calories ?? 0) + (w.caloriesKcal ?? 0),
        durationMins: (prev?.durationMins ?? 0) + w.durationMins,
      );
    }

    final weekBuckets = <WeekMetric>[];
    for (var i = 6; i >= 0; i--) {
      final weekEnd = now.subtract(Duration(days: i * 7));
      final weekStart = DateTime(weekEnd.year, weekEnd.month, weekEnd.day).subtract(const Duration(days: 6));
      final inWeek = workouts.where((w) {
        final d = DateTime(w.startedAt.year, w.startedAt.month, w.startedAt.day);
        return !d.isBefore(weekStart) && !d.isAfter(DateTime(weekEnd.year, weekEnd.month, weekEnd.day));
      });
      weekBuckets.add(WeekMetric(
        weekStart: weekStart,
        sessions: inWeek.length,
        calories: inWeek.fold<int>(0, (s, w) => s + (w.caloriesKcal ?? 0)),
        durationMins: inWeek.fold<int>(0, (s, w) => s + w.durationMins),
      ));
    }

    return WorkoutMetricsData(
      days: days,
      isDemo: true,
      dataSource: 'demo',
      workouts: workouts,
      summary: WorkoutMetricsSummary.fromWorkouts(workouts),
      byActivity: byActivityMap.values.toList()
        ..sort((a, b) => b.calories.compareTo(a.calories)),
      byWeek: weekBuckets,
    );
  }
}

class _DemoWorkout {
  const _DemoWorkout({
    required this.daysAgo,
    required this.hour,
    required this.serviceName,
    required this.activityLabel,
    required this.activityType,
    required this.durationMins,
    required this.calories,
    required this.avgHr,
    this.distanceM,
  });

  final int daysAgo;
  final int hour;
  final String serviceName;
  final String activityLabel;
  final String activityType;
  final int durationMins;
  final int calories;
  final int avgHr;
  final double? distanceM;
}
