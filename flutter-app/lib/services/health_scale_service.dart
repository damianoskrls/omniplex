import 'dart:io';

import 'package:health/health.dart';

import '../models/scale_reading.dart';
import 'demo_metrics_service.dart';

class HealthScaleService {
  HealthScaleService._();
  static final HealthScaleService instance = HealthScaleService._();

  static const _types = [
    HealthDataType.WEIGHT,
    HealthDataType.BODY_FAT_PERCENTAGE,
  ];

  Health? _health;

  bool get isSupported => Platform.isIOS || Platform.isAndroid;

  Future<Health> _client() async {
    _health ??= Health();
    await _health!.configure();
    return _health!;
  }

  Future<bool> requestPermissions({bool write = false}) async {
    if (!isSupported) return false;
    final health = await _client();
    final access = write ? HealthDataAccess.READ_WRITE : HealthDataAccess.READ;
    return health.requestAuthorization(
      _types,
      permissions: _types.map((_) => access).toList(),
    );
  }

  Future<bool> requestReadPermissions() => requestPermissions();

  /// Debug / demo: write a sample reading to Apple Health, then read it back.
  Future<ScaleReading?> writeDemoReadingToHealth() async {
    if (!isSupported) return null;

    final health = await _client();
    final granted = await requestPermissions(write: true);
    if (!granted) return null;

    final now = DateTime.now();
    final demo = DemoMetricsService.simulatedHealthReading(at: now);

    await health.writeHealthData(
      value: demo.weightKg,
      type: HealthDataType.WEIGHT,
      startTime: now,
      endTime: now,
      unit: HealthDataUnit.KILOGRAM,
      recordingMethod: RecordingMethod.manual,
    );

    if (demo.bodyFatPct != null) {
      await health.writeHealthData(
        value: demo.bodyFatPct!,
        type: HealthDataType.BODY_FAT_PERCENTAGE,
        startTime: now,
        endTime: now,
        recordingMethod: RecordingMethod.manual,
      );
    }

    await Future<void>.delayed(const Duration(milliseconds: 400));
    return fetchLatestReading(days: 1);
  }

  Future<bool> hasPermissions() async {
    if (!isSupported) return false;
    final health = await _client();
    final result = await health.hasPermissions(
      _types,
      permissions: _types.map((_) => HealthDataAccess.READ).toList(),
    );
    return result ?? false;
  }

  /// Latest weight (+ optional body fat) from the last [days] days.
  Future<ScaleReading?> fetchLatestReading({int days = 30}) async {
    if (!isSupported) return null;

    final health = await _client();
    final granted = await requestPermissions();
    if (!granted) return null;

    final end = DateTime.now();
    final start = end.subtract(Duration(days: days));

    final points = await health.getHealthDataFromTypes(
      types: _types,
      startTime: start,
      endTime: end,
    );

    if (points.isEmpty) return null;

    points.sort((a, b) => b.dateTo.compareTo(a.dateTo));

    HealthDataPoint? weightPoint;
    HealthDataPoint? fatPoint;

    for (final p in points) {
      if (p.type == HealthDataType.WEIGHT && weightPoint == null) {
        weightPoint = p;
      } else if (p.type == HealthDataType.BODY_FAT_PERCENTAGE && fatPoint == null) {
        fatPoint = p;
      }
      if (weightPoint != null && fatPoint != null) break;
    }

    if (weightPoint == null) return null;

    final weightKg = _toKg(weightPoint);
    if (weightKg == null || weightKg < 20 || weightKg > 300) return null;

    double? bodyFat;
    if (fatPoint != null) {
      final v = (fatPoint.value as NumericHealthValue).numericValue.toDouble();
      bodyFat = double.parse(v.toStringAsFixed(1));
    }

    return ScaleReading(
      weightKg: double.parse(weightKg.toStringAsFixed(1)),
      bodyFatPct: bodyFat,
      measuredAt: weightPoint.dateTo,
      source: 'health',
      deviceName: Platform.isIOS ? 'Apple Health' : 'Health Connect',
    );
  }

  double? _toKg(HealthDataPoint point) {
    final v = (point.value as NumericHealthValue).numericValue.toDouble();
    if (point.unit == HealthDataUnit.KILOGRAM) return v;
    if (point.unit == HealthDataUnit.POUND) return v * 0.45359237;
    return v;
  }
}
