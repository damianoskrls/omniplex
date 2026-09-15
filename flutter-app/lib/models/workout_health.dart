class WorkoutHealthSummary {
  const WorkoutHealthSummary({
    required this.externalId,
    required this.activityType,
    required this.activityLabel,
    required this.startedAt,
    required this.endedAt,
    required this.durationMins,
    this.caloriesKcal,
    this.avgHeartRate,
    this.distanceM,
    this.source = 'health',
    this.matchScore = 0,
    this.isAutoMatch = false,
  });

  final String externalId;
  final String activityType;
  final String activityLabel;
  final DateTime startedAt;
  final DateTime endedAt;
  final int durationMins;
  final int? caloriesKcal;
  final int? avgHeartRate;
  final double? distanceM;
  final String source;
  final double matchScore;
  final bool isAutoMatch;

  Map<String, dynamic> toApiPayload() => {
        'external_id': externalId,
        'activity_type': activityType,
        'activity_label': activityLabel,
        'started_at': startedAt.toUtc().toIso8601String(),
        'ended_at': endedAt.toUtc().toIso8601String(),
        'duration_mins': durationMins,
        if (caloriesKcal != null) 'calories_kcal': caloriesKcal,
        if (avgHeartRate != null) 'avg_heart_rate': avgHeartRate,
        if (distanceM != null) 'distance_m': distanceM,
        'source': source,
      };

  String get summaryLine {
    final parts = <String>[];
    if (caloriesKcal != null) parts.add('$caloriesKcal kcal');
    parts.add('$durationMins λεπτά');
    if (avgHeartRate != null) parts.add('♥ $avgHeartRate bpm');
    return parts.join(' · ');
  }
}

class WorkoutHealthLoadResult {
  const WorkoutHealthLoadResult({
    required this.candidates,
    this.bestMatch,
    this.permissionDenied = false,
    this.unsupported = false,
  });

  final List<WorkoutHealthSummary> candidates;
  final WorkoutHealthSummary? bestMatch;
  final bool permissionDenied;
  final bool unsupported;
}
