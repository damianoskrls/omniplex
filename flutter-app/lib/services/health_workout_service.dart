import 'dart:io';

import 'package:health/health.dart';

import '../models/booking.dart';
import '../models/workout_health.dart';

class HealthWorkoutService {
  HealthWorkoutService._();
  static final HealthWorkoutService instance = HealthWorkoutService._();

  static const _types = [
    HealthDataType.WORKOUT,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.HEART_RATE,
  ];

  Health? _health;

  bool get isSupported => Platform.isIOS || Platform.isAndroid;

  Future<Health> _client() async {
    _health ??= Health();
    await _health!.configure();
    return _health!;
  }

  Future<bool> requestPermissions() async {
    if (!isSupported) return false;
    final health = await _client();
    return health.requestAuthorization(
      _types,
      permissions: _types.map((_) => HealthDataAccess.READ).toList(),
    );
  }

  Future<List<WorkoutHealthSummary>> loadRecentWorkouts({int days = 30}) async {
    if (!isSupported) return [];

    final granted = await requestPermissions();
    if (!granted) return [];

    final start = DateTime.now().subtract(Duration(days: days));
    final health = await _client();
    final points = await health.getHealthDataFromTypes(
      types: [HealthDataType.WORKOUT],
      startTime: start,
      endTime: DateTime.now(),
    );

    final workouts = <WorkoutHealthSummary>[];
    for (final p in points) {
      if (p.type != HealthDataType.WORKOUT) continue;
      final summary = await _summaryFromWorkoutPoint(health, p);
      if (summary != null) workouts.add(summary);
    }

    workouts.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return workouts;
  }

  Future<WorkoutHealthLoadResult> loadForBooking(Booking booking) async {
    if (!isSupported) {
      return const WorkoutHealthLoadResult(candidates: [], unsupported: true);
    }

    final granted = await requestPermissions();
    if (!granted) {
      return const WorkoutHealthLoadResult(candidates: [], permissionDenied: true);
    }

    final windowStart = booking.startsAt.subtract(const Duration(minutes: 30));
    final windowEnd = booking.endsAt.add(const Duration(minutes: 45));
    final dayStart = DateTime(booking.startsAt.year, booking.startsAt.month, booking.startsAt.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    final health = await _client();
    final points = await health.getHealthDataFromTypes(
      types: _types,
      startTime: dayStart.isBefore(windowStart) ? dayStart : windowStart,
      endTime: windowEnd.isAfter(dayEnd) ? windowEnd : dayEnd,
    );

    final workouts = <WorkoutHealthSummary>[];
    for (final p in points) {
      if (p.type != HealthDataType.WORKOUT) continue;
      final summary = await _summaryFromWorkoutPoint(health, p);
      if (summary != null) workouts.add(summary);
    }

    workouts.sort((a, b) => b.startedAt.compareTo(a.startedAt));

    WorkoutHealthSummary? best;
    double bestScore = 0;
    for (final w in workouts) {
      final score = _overlapScore(booking, w);
      if (score > bestScore) {
        bestScore = score;
        best = w.copyWith(matchScore: score, isAutoMatch: score >= 0.35);
      }
    }

    if (best != null && bestScore >= 0.35) {
      best = best.copyWith(isAutoMatch: true, matchScore: bestScore);
    } else {
      best = null;
    }

    return WorkoutHealthLoadResult(candidates: workouts, bestMatch: best);
  }

  double _overlapScore(Booking booking, WorkoutHealthSummary workout) {
    final bStart = booking.startsAt.millisecondsSinceEpoch;
    final bEnd = booking.endsAt.millisecondsSinceEpoch;
    final wStart = workout.startedAt.millisecondsSinceEpoch;
    final wEnd = workout.endedAt.millisecondsSinceEpoch;
    final overlapStart = wStart > bStart ? wStart : bStart;
    final overlapEnd = wEnd < bEnd ? wEnd : bEnd;
    if (overlapEnd <= overlapStart) {
      // Allow near-miss: workout starts within 20 min after booking start
      final gap = (wStart - bStart).abs();
      if (gap > 20 * 60 * 1000) return 0;
      return 0.25;
    }
    final overlap = overlapEnd - overlapStart;
    final bookingLen = (bEnd - bStart).clamp(1, 1 << 31);
    return overlap / bookingLen;
  }

  Future<WorkoutHealthSummary?> _summaryFromWorkoutPoint(Health health, HealthDataPoint point) async {
    final value = point.value;
    if (value is! WorkoutHealthValue) return null;

    var calories = value.totalEnergyBurned ?? point.workoutSummary?.totalEnergyBurned.round();
    final durationMins = point.dateTo.difference(point.dateFrom).inMinutes.clamp(1, 600);

    if (calories == null || calories == 0) {
      calories = await _activeEnergyBetween(health, point.dateFrom, point.dateTo);
    }

    final avgHr = await _avgHeartRateBetween(health, point.dateFrom, point.dateTo);

    double? distanceM;
    if (value.totalDistance != null) {
      distanceM = value.totalDistance!.toDouble();
      if (value.totalDistanceUnit == HealthDataUnit.MILE) {
        distanceM = distanceM * 1609.34;
      }
    }

    final typeName = value.workoutActivityType.name;
    return WorkoutHealthSummary(
      externalId: point.uuid,
      activityType: typeName,
      activityLabel: _activityLabel(typeName),
      startedAt: point.dateFrom,
      endedAt: point.dateTo,
      durationMins: durationMins,
      caloriesKcal: calories,
      avgHeartRate: avgHr,
      distanceM: distanceM,
      source: Platform.isIOS ? 'apple_health' : 'health_connect',
    );
  }

  Future<int?> _activeEnergyBetween(Health health, DateTime from, DateTime to) async {
    final points = await health.getHealthDataFromTypes(
      types: [HealthDataType.ACTIVE_ENERGY_BURNED],
      startTime: from,
      endTime: to,
    );
    if (points.isEmpty) return null;
    var sum = 0.0;
    for (final p in points) {
      final v = p.value;
      if (v is NumericHealthValue) sum += v.numericValue.toDouble();
    }
    return sum > 0 ? sum.round() : null;
  }

  Future<int?> _avgHeartRateBetween(Health health, DateTime from, DateTime to) async {
    final points = await health.getHealthDataFromTypes(
      types: [HealthDataType.HEART_RATE],
      startTime: from,
      endTime: to,
    );
    if (points.isEmpty) return null;
    var sum = 0.0;
    var count = 0;
    for (final p in points) {
      final v = p.value;
      if (v is NumericHealthValue) {
        sum += v.numericValue.toDouble();
        count += 1;
      }
    }
    if (count == 0) return null;
    return (sum / count).round();
  }

  String _activityLabel(String typeName) {
    const labels = {
      'TRADITIONAL_STRENGTH_TRAINING': 'Άσκηση με βάρη',
      'FUNCTIONAL_STRENGTH_TRAINING': 'Functional training',
      'HIGH_INTENSITY_INTERVAL_TRAINING': 'HIIT',
      'CORE_TRAINING': 'Core training',
      'YOGA': 'Yoga',
      'PILATES': 'Pilates',
      'CROSS_TRAINING': 'Cross training',
      'RUNNING': 'Τρέξιμο',
      'WALKING': 'Περπάτημα',
      'CYCLING': 'Ποδήλατο',
      'SWIMMING': 'Κολύμβηση',
      'ELLIPTICAL': 'Ελλειπτικό',
      'STAIR_CLIMBING': 'Σκάλες',
      'MIND_AND_BODY': 'Mind & body',
      'OTHER': 'Προπόνηση',
    };
    return labels[typeName] ?? typeName.replaceAll('_', ' ').toLowerCase();
  }
}

extension _WorkoutHealthCopy on WorkoutHealthSummary {
  WorkoutHealthSummary copyWith({
    double? matchScore,
    bool? isAutoMatch,
  }) =>
      WorkoutHealthSummary(
        externalId: externalId,
        activityType: activityType,
        activityLabel: activityLabel,
        startedAt: startedAt,
        endedAt: endedAt,
        durationMins: durationMins,
        caloriesKcal: caloriesKcal,
        avgHeartRate: avgHeartRate,
        distanceM: distanceM,
        source: source,
        matchScore: matchScore ?? this.matchScore,
        isAutoMatch: isAutoMatch ?? this.isAutoMatch,
      );
}
