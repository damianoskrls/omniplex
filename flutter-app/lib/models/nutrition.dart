class NutritionPortion {
  const NutritionPortion({
    required this.ingredient,
    this.amount,
    required this.unit,
  });

  final String ingredient;
  final double? amount;
  final String unit;

  factory NutritionPortion.fromJson(Map<String, dynamic> json) {
    return NutritionPortion(
      ingredient: json['ingredient'] as String? ?? '',
      amount: json['amount'] == null ? null : (json['amount'] as num).toDouble(),
      unit: json['unit'] as String? ?? 'g',
    );
  }
}

class MealPlanOption {
  const MealPlanOption({
    this.id,
    required this.title,
    this.description,
    this.notes,
    required this.portions,
    this.imageUrl,
    this.recipeText,
  });

  final String? id;
  final String title;
  final String? description;
  final String? notes;
  final List<NutritionPortion> portions;
  final String? imageUrl;
  final String? recipeText;

  factory MealPlanOption.fromJson(Map<String, dynamic> json) {
    return MealPlanOption(
      id: json['id'] as String?,
      title: json['title'] as String? ?? json['description'] as String? ?? '',
      description: json['description'] as String?,
      notes: json['notes'] as String?,
      portions: (json['portions'] as List? ?? [])
          .map((e) => NutritionPortion.fromJson(e as Map<String, dynamic>))
          .toList(),
      imageUrl: json['image_url'] as String?,
      recipeText: json['recipe_text'] as String?,
    );
  }
}

class MealPlanSlot {
  const MealPlanSlot({
    required this.dayOfWeek,
    required this.mealType,
    required this.mealTypeLabel,
    required this.options,
  });

  final int dayOfWeek;
  final String mealType;
  final String mealTypeLabel;
  final List<MealPlanOption> options;

  factory MealPlanSlot.fromJson(Map<String, dynamic> json) {
    return MealPlanSlot(
      dayOfWeek: json['day_of_week'] as int,
      mealType: json['meal_type'] as String,
      mealTypeLabel: json['meal_type_label'] as String? ?? json['meal_type'] as String,
      options: (json['options'] as List? ?? [])
          .map((e) => MealPlanOption.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ShoppingListItem {
  const ShoppingListItem({
    required this.ingredient,
    this.amount,
    required this.unit,
    this.sources = 1,
    this.neededAmount,
    this.neededUnit,
    this.buyAmount,
    this.buyUnit,
    this.suggestion,
  });

  final String ingredient;
  final double? amount;
  final String unit;
  final int sources;
  final double? neededAmount;
  final String? neededUnit;
  final double? buyAmount;
  final String? buyUnit;
  final String? suggestion;

  factory ShoppingListItem.fromJson(Map<String, dynamic> json) {
    double? numVal(dynamic v) => v == null ? null : (v as num).toDouble();
    return ShoppingListItem(
      ingredient: json['ingredient'] as String? ?? '',
      amount: numVal(json['amount']) ?? numVal(json['buy_amount']),
      unit: json['unit'] as String? ?? json['buy_unit'] as String? ?? 'g',
      sources: json['sources'] as int? ?? 1,
      neededAmount: numVal(json['needed_amount']),
      neededUnit: json['needed_unit'] as String?,
      buyAmount: numVal(json['buy_amount']),
      buyUnit: json['buy_unit'] as String?,
      suggestion: json['suggestion'] as String?,
    );
  }
}

class NutritionGoals {
  const NutritionGoals({
    this.weightKg,
    this.targetWeightKg,
    this.heightCm,
    this.bodyFatPct,
    this.targetBodyFatPct,
  });

  final double? weightKg;
  final double? targetWeightKg;
  final double? heightCm;
  final double? bodyFatPct;
  final double? targetBodyFatPct;

  factory NutritionGoals.fromJson(Map<String, dynamic> json) {
    double? numVal(dynamic v) => v == null ? null : (v as num).toDouble();
    return NutritionGoals(
      weightKg: numVal(json['weight_kg']),
      targetWeightKg: numVal(json['target_weight_kg']),
      heightCm: numVal(json['height_cm']),
      bodyFatPct: numVal(json['body_fat_pct']),
      targetBodyFatPct: numVal(json['target_body_fat_pct']),
    );
  }
}

class NutritionMeasurement {
  const NutritionMeasurement({
    required this.id,
    required this.measuredOn,
    this.measuredWhen,
    this.timeOfDay,
    this.timeOfDayLabel,
    this.measuredTime,
    this.recordedBy = 'nutritionist',
    this.weightKg,
    this.heightCm,
    this.bodyFatPct,
    this.muscleMassKg,
    this.fatMassKg,
    this.boneMassKg,
    this.bmi,
    this.visceralFatLevel,
    this.bmrKcal,
    this.metabolicAge,
    this.notes,
  });

  final String id;
  final String measuredOn;
  final String? measuredWhen;
  final String? timeOfDay;
  final String? timeOfDayLabel;
  final String? measuredTime;
  final String recordedBy;
  final double? weightKg;
  final double? heightCm;
  final double? bodyFatPct;
  final double? muscleMassKg;
  final double? fatMassKg;
  final double? boneMassKg;
  final double? bmi;
  final int? visceralFatLevel;
  final int? bmrKcal;
  final int? metabolicAge;
  final String? notes;

  factory NutritionMeasurement.fromJson(Map<String, dynamic> json) {
    double? numVal(dynamic v) => v == null ? null : (v as num).toDouble();
    int? intVal(dynamic v) => v == null ? null : (v as num).round();
    return NutritionMeasurement(
      id: json['id'] as String,
      measuredOn: json['measured_on'] as String,
      measuredWhen: json['measured_when'] as String?,
      timeOfDay: json['time_of_day'] as String?,
      timeOfDayLabel: json['time_of_day_label'] as String?,
      measuredTime: json['measured_time'] as String?,
      recordedBy: json['recorded_by'] as String? ?? 'nutritionist',
      weightKg: numVal(json['weight_kg']),
      heightCm: numVal(json['height_cm']),
      bodyFatPct: numVal(json['body_fat_pct']),
      muscleMassKg: numVal(json['muscle_mass_kg']),
      fatMassKg: numVal(json['fat_mass_kg']),
      boneMassKg: numVal(json['bone_mass_kg']),
      bmi: numVal(json['bmi']),
      visceralFatLevel: intVal(json['visceral_fat_level']),
      bmrKcal: intVal(json['bmr_kcal']),
      metabolicAge: intVal(json['metabolic_age']),
      notes: json['notes'] as String?,
    );
  }
}

class NutritionChartPoint {
  const NutritionChartPoint({
    required this.date,
    required this.value,
    this.recordedBy = 'nutritionist',
  });

  final String date;
  final double value;
  final String recordedBy;

  factory NutritionChartPoint.fromJson(Map<String, dynamic> json) {
    return NutritionChartPoint(
      date: json['date'] as String,
      value: (json['value'] as num).toDouble(),
      recordedBy: json['recorded_by'] as String? ?? 'nutritionist',
    );
  }
}

class NutritionVisit {
  const NutritionVisit({
    required this.id,
    required this.date,
    this.measuredWhen,
    this.timeOfDayLabel,
    this.measuredTime,
    required this.recordedBy,
    this.weightKg,
    this.bodyFatPct,
    this.muscleMassKg,
    this.bmi,
    this.notes,
  });

  final String id;
  final String date;
  final String? measuredWhen;
  final String? timeOfDayLabel;
  final String? measuredTime;
  final String recordedBy;
  final double? weightKg;
  final double? bodyFatPct;
  final double? muscleMassKg;
  final double? bmi;
  final String? notes;

  factory NutritionVisit.fromJson(Map<String, dynamic> json) {
    double? numVal(dynamic v) => v == null ? null : (v as num).toDouble();
    return NutritionVisit(
      id: json['id'] as String,
      date: json['date'] as String,
      measuredWhen: json['measured_when'] as String?,
      timeOfDayLabel: json['time_of_day_label'] as String?,
      measuredTime: json['measured_time'] as String?,
      recordedBy: json['recorded_by'] as String? ?? 'nutritionist',
      weightKg: numVal(json['weight_kg']),
      bodyFatPct: numVal(json['body_fat_pct']),
      muscleMassKg: numVal(json['muscle_mass_kg']),
      bmi: numVal(json['bmi']),
      notes: json['notes'] as String?,
    );
  }
}

class NutritionProgress {
  const NutritionProgress({
    required this.goals,
    this.latestMeasurement,
    this.firstMeasurement,
    required this.measurements,
    required this.progress,
    required this.chart,
    required this.visits,
  });

  final NutritionGoals goals;
  final NutritionMeasurement? latestMeasurement;
  final NutritionMeasurement? firstMeasurement;
  final List<NutritionMeasurement> measurements;
  final Map<String, dynamic> progress;
  final Map<String, List<NutritionChartPoint>> chart;
  final List<NutritionVisit> visits;

  int? get weightGoalPct {
    final v = progress['weight_goal_pct'];
    return v == null ? null : (v as num).round();
  }

  int? get bodyFatGoalPct {
    final v = progress['body_fat_goal_pct'];
    return v == null ? null : (v as num).round();
  }

  factory NutritionProgress.fromJson(Map<String, dynamic> json) {
    final chartJson = json['chart'] as Map<String, dynamic>? ?? {};
    List<NutritionChartPoint> parseSeries(dynamic raw) => (raw as List? ?? [])
        .map((e) => NutritionChartPoint.fromJson(e as Map<String, dynamic>))
        .toList();
    return NutritionProgress(
      goals: NutritionGoals.fromJson(json['goals'] as Map<String, dynamic>),
      latestMeasurement: json['latest_measurement'] != null
          ? NutritionMeasurement.fromJson(json['latest_measurement'] as Map<String, dynamic>)
          : null,
      firstMeasurement: json['first_measurement'] != null
          ? NutritionMeasurement.fromJson(json['first_measurement'] as Map<String, dynamic>)
          : null,
      measurements: (json['measurements'] as List? ?? [])
          .map((e) => NutritionMeasurement.fromJson(e as Map<String, dynamic>))
          .toList(),
      progress: (json['progress'] as Map<String, dynamic>?) ?? {},
      chart: {
        'weight': parseSeries(chartJson['weight']),
        'body_fat_pct': parseSeries(chartJson['body_fat_pct']),
        'muscle_mass_kg': parseSeries(chartJson['muscle_mass_kg']),
      },
      visits: (json['visits'] as List? ?? [])
          .map((e) => NutritionVisit.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class MealPlanItem {
  const MealPlanItem({
    required this.dayOfWeek,
    required this.mealType,
    required this.mealTypeLabel,
    required this.description,
    this.title,
    this.notes,
    this.portions = const [],
    this.imageUrl,
    this.recipeText,
    this.id,
  });

  final String? id;
  final int dayOfWeek;
  final String mealType;
  final String mealTypeLabel;
  final String description;
  final String? title;
  final String? notes;
  final List<NutritionPortion> portions;
  final String? imageUrl;
  final String? recipeText;

  factory MealPlanItem.fromJson(Map<String, dynamic> json) {
    return MealPlanItem(
      id: json['id'] as String?,
      dayOfWeek: json['day_of_week'] as int,
      mealType: json['meal_type'] as String,
      mealTypeLabel: json['meal_type_label'] as String? ?? json['meal_type'] as String,
      title: json['title'] as String?,
      description: json['description'] as String? ?? json['title'] as String? ?? '',
      notes: json['notes'] as String?,
      portions: (json['portions'] as List? ?? [])
          .map((e) => NutritionPortion.fromJson(e as Map<String, dynamic>))
          .toList(),
      imageUrl: json['image_url'] as String?,
      recipeText: json['recipe_text'] as String?,
    );
  }
}

class FoodLogEntry {
  const FoodLogEntry({
    required this.id,
    required this.mealType,
    required this.mealTypeLabel,
    required this.description,
    this.photoUrl,
    this.planOptionId,
    this.loggedAt,
  });

  final String id;
  final String mealType;
  final String mealTypeLabel;
  final String description;
  final String? photoUrl;
  final String? planOptionId;
  final String? loggedAt;

  factory FoodLogEntry.fromJson(Map<String, dynamic> json) {
    return FoodLogEntry(
      id: json['id'] as String,
      mealType: json['meal_type'] as String,
      mealTypeLabel: json['meal_type_label'] as String? ?? json['meal_type'] as String,
      description: json['description'] as String? ?? '',
      photoUrl: json['photo_url'] as String?,
      planOptionId: json['plan_option_id'] as String?,
      loggedAt: json['logged_at']?.toString(),
    );
  }
}

class NutritionToday {
  const NutritionToday({
    required this.date,
    required this.dayOfWeek,
    required this.weekStart,
    required this.goals,
    required this.plannedSlots,
    required this.plannedMeals,
    required this.foodLogs,
    required this.shoppingList,
  });

  final String date;
  final int dayOfWeek;
  final String weekStart;
  final NutritionGoals goals;
  final List<MealPlanSlot> plannedSlots;
  final List<MealPlanItem> plannedMeals;
  final List<FoodLogEntry> foodLogs;
  final List<ShoppingListItem> shoppingList;

  factory NutritionToday.fromJson(Map<String, dynamic> json) {
    return NutritionToday(
      date: json['date'] as String,
      dayOfWeek: json['day_of_week'] as int,
      weekStart: json['week_start'] as String,
      goals: NutritionGoals.fromJson(json['goals'] as Map<String, dynamic>),
      plannedSlots: (json['planned_slots'] as List? ?? [])
          .map((e) => MealPlanSlot.fromJson(e as Map<String, dynamic>))
          .toList(),
      plannedMeals: (json['planned_meals'] as List? ?? [])
          .map((e) => MealPlanItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      foodLogs: (json['food_logs'] as List? ?? [])
          .map((e) => FoodLogEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      shoppingList: (json['shopping_list'] as List? ?? [])
          .map((e) => ShoppingListItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class MealPlanWeek {
  const MealPlanWeek({
    this.effectiveFrom,
    this.weekStart,
    required this.slots,
    required this.meals,
    required this.shoppingList,
    this.plannedSlots,
    this.notes,
  });

  final String? effectiveFrom;
  final String? weekStart;
  final String? notes;
  final List<MealPlanSlot> slots;
  final List<MealPlanSlot>? plannedSlots;
  final List<MealPlanItem> meals;
  final List<ShoppingListItem> shoppingList;

  factory MealPlanWeek.fromJson(Map<String, dynamic> json) {
    return MealPlanWeek(
      effectiveFrom: json['effective_from'] as String?,
      weekStart: json['week_start'] as String?,
      notes: json['notes'] as String?,
      slots: (json['slots'] as List? ?? [])
          .map((e) => MealPlanSlot.fromJson(e as Map<String, dynamic>))
          .toList(),
      plannedSlots: (json['planned_slots'] as List? ?? [])
          .map((e) => MealPlanSlot.fromJson(e as Map<String, dynamic>))
          .toList(),
      meals: (json['meals'] as List? ?? [])
          .map((e) => MealPlanItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      shoppingList: (json['shopping_list'] as List? ?? [])
          .map((e) => ShoppingListItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class MealTypeOption {
  const MealTypeOption({required this.id, required this.label});

  final String id;
  final String label;

  factory MealTypeOption.fromJson(Map<String, dynamic> json) {
    return MealTypeOption(
      id: json['id'] as String,
      label: json['label'] as String,
    );
  }
}
