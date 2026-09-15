class ScaleReading {
  const ScaleReading({
    required this.weightKg,
    required this.measuredAt,
    required this.source,
    this.bodyFatPct,
    this.bmi,
    this.muscleMassKg,
    this.deviceName,
  });

  final double weightKg;
  final DateTime measuredAt;
  /// `health` | `ble`
  final String source;
  final double? bodyFatPct;
  final double? bmi;
  final double? muscleMassKg;
  final String? deviceName;

  String get sourceLabel => switch (source) {
        'health' => 'Apple Health / Health Connect',
        'ble' => deviceName ?? 'Ζυγαριά Bluetooth',
        'demo' => 'Προσομοίωση iPhone',
        _ => source,
      };
}

class BleScaleDeviceInfo {
  const BleScaleDeviceInfo({
    required this.id,
    required this.name,
    this.rssi,
    this.lastReading,
  });

  final String id;
  final String name;
  final int? rssi;
  final ScaleReading? lastReading;
}
