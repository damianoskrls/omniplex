class FitnessGoalOption {
  const FitnessGoalOption({required this.id, required this.label});

  final String id;
  final String label;

  factory FitnessGoalOption.fromJson(Map<String, dynamic> json) => FitnessGoalOption(
        id: json['id'] as String,
        label: json['label'] as String,
      );
}

class FitnessProfile {
  const FitnessProfile({
    this.weightKg,
    this.targetWeightKg,
    this.fitnessGoal,
    this.fitnessGoalLabel,
  });

  final double? weightKg;
  final double? targetWeightKg;
  final String? fitnessGoal;
  final String? fitnessGoalLabel;

  double? get weightToLose {
    if (weightKg == null || targetWeightKg == null) return null;
    return weightKg! - targetWeightKg!;
  }

  double? get progressPct {
    if (weightKg == null || targetWeightKg == null || fitnessGoal != 'weight_loss') return null;
    final startGap = weightToLose;
    if (startGap == null || startGap <= 0) return 100;
    return ((1 - (weightKg! - targetWeightKg!) / startGap) * 100).clamp(0, 100);
  }

  factory FitnessProfile.fromUserJson(Map<String, dynamic> json) => FitnessProfile(
        weightKg: _asDouble(json['weight_kg']),
        targetWeightKg: _asDouble(json['target_weight_kg']),
        fitnessGoal: json['fitness_goal'] as String?,
        fitnessGoalLabel: json['fitness_goal_label'] as String?,
      );

  static double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
