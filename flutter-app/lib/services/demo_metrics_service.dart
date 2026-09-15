import '../models/scale_reading.dart';

class DemoMeasurementPoint {
  const DemoMeasurementPoint({
    required this.measuredOn,
    required this.weightKg,
    required this.bodyFatPct,
  });

  final String measuredOn;
  final double weightKg;
  final double bodyFatPct;
}

/// Sample body metrics for previewing charts & goals on a real iPhone build.
class DemoMetricsService {
  DemoMetricsService._();

  static ScaleReading simulatedHealthReading({DateTime? at}) {
    final when = at ?? DateTime.now();
    return ScaleReading(
      weightKg: 78.4,
      bodyFatPct: 22.5,
      muscleMassKg: 58.2,
      bmi: 24.1,
      measuredAt: when,
      source: 'demo',
      deviceName: 'iPhone (simulate)',
    );
  }

  /// Six weekly points — weight trending down for chart preview.
  static List<DemoMeasurementPoint> weeklyProgressSeries() {
    final today = DateTime.now();
    final weights = [82.0, 81.2, 80.5, 79.8, 79.1, 78.4];
    final fats = [24.0, 23.8, 23.5, 23.2, 22.9, 22.5];

    return List.generate(weights.length, (i) {
      final d = today.subtract(Duration(days: (weights.length - 1 - i) * 7));
      final iso = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      return DemoMeasurementPoint(
        measuredOn: iso,
        weightKg: weights[i],
        bodyFatPct: fats[i],
      );
    });
  }
}
