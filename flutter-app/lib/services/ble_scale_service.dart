import 'dart:async';
import 'dart:io';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/scale_reading.dart';

/// BLE sync for Xiaomi / Mi Body Composition scales and generic weight scales.
class BleScaleService {
  BleScaleService._();
  static final BleScaleService instance = BleScaleService._();

  static const _xiaomiCompanyId = 0x0157;
  static const _weightService = '0000181d-0000-1000-8000-00805f9b34fb';
  static const _weightChar = '00002a9d-0000-1000-8000-00805f9b34fb';
  static const _miBodyService = '0000181b-0000-1000-8000-00805f9b34fb';
  static const _miBodyChar = '00002a9e-0000-1000-8000-00805f9b34fb';

  StreamSubscription<List<ScanResult>>? _scanSub;
  final _devices = <String, BleScaleDeviceInfo>{};
  final _deviceCtrl = StreamController<List<BleScaleDeviceInfo>>.broadcast();
  final _readingCtrl = StreamController<ScaleReading>.broadcast();

  Stream<List<BleScaleDeviceInfo>> get devices => _deviceCtrl.stream;
  Stream<ScaleReading> get readings => _readingCtrl.stream;

  bool get isSupported => Platform.isIOS || Platform.isAndroid;

  Future<bool> ensurePermissions() async {
    if (!isSupported) return false;

    if (Platform.isAndroid) {
      final scan = await Permission.bluetoothScan.request();
      final connect = await Permission.bluetoothConnect.request();
      final loc = await Permission.locationWhenInUse.request();
      return scan.isGranted && connect.isGranted && loc.isGranted;
    }

    // iOS: Bluetooth permission prompt appears on first scan.
    return true;
  }

  Future<void> startScan({Duration timeout = const Duration(seconds: 25)}) async {
    if (!isSupported) return;
    final ok = await ensurePermissions();
    if (!ok) throw StateError('Δεν δόθηκαν δικαιώματα Bluetooth');

    await stopScan();
    _devices.clear();
    _emitDevices();

    if (await FlutterBluePlus.isSupported == false) {
      throw StateError('Το Bluetooth δεν υποστηρίζεται σε αυτή τη συσκευή');
    }

    await FlutterBluePlus.startScan(timeout: timeout);

    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        final name = _deviceName(r);
        if (!_looksLikeScale(name) && !_hasXiaomiData(r)) continue;

        final reading = _readingFromAdvertisement(r);
        final id = r.device.remoteId.str;
        final existing = _devices[id];
        _devices[id] = BleScaleDeviceInfo(
          id: id,
          name: name,
          rssi: r.rssi,
          lastReading: reading ?? existing?.lastReading,
        );
        if (reading != null) {
          _readingCtrl.add(reading);
        }
      }
      _emitDevices();
    });
  }

  Future<void> stopScan() async {
    await _scanSub?.cancel();
    _scanSub = null;
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
  }

  /// Connect to scale and wait for a stabilized reading (step on scale).
  Future<ScaleReading> readFromDevice(
    String deviceId, {
    Duration timeout = const Duration(seconds: 45),
  }) async {
    final device = BluetoothDevice.fromId(deviceId);
    final name = _devices[deviceId]?.name ?? device.platformName;

    await device.connect(
      license: License.nonprofit,
      timeout: const Duration(seconds: 15),
      autoConnect: false,
    );

    try {
      await device.discoverServices();
      final completer = Completer<ScaleReading>();
      final subs = <StreamSubscription>[];

      void tryComplete(ScaleReading? reading) {
        if (reading == null || completer.isCompleted) return;
        completer.complete(reading);
      }

      for (final service in device.servicesList) {
        final sid = service.uuid.str128.toLowerCase();
        for (final char in service.characteristics) {
          final cid = char.uuid.str128.toLowerCase();

          if (sid == _weightService && cid == _weightChar) {
            if (char.properties.notify) {
              await char.setNotifyValue(true);
              subs.add(char.onValueReceived.listen((data) {
                tryComplete(_parseWeightMeasurement(data, name));
              }));
            }
            if (char.properties.read) {
              final data = await char.read();
              tryComplete(_parseWeightMeasurement(data, name));
            }
          }

          if (sid == _miBodyService && cid == _miBodyChar) {
            if (char.properties.notify) {
              await char.setNotifyValue(true);
              subs.add(char.onValueReceived.listen((data) {
                tryComplete(_parseMiBodyComposition(data, name));
              }));
            }
          }
        }
      }

      // Poll while waiting — some Xiaomi scales only broadcast via advertisements.
      final poll = Timer.periodic(const Duration(seconds: 2), (_) async {
        final adv = _devices[deviceId]?.lastReading;
        if (adv != null) tryComplete(adv);
      });

      final reading = await completer.future.timeout(
        timeout,
        onTimeout: () {
          final cached = _devices[deviceId]?.lastReading;
          if (cached != null) return cached;
          throw TimeoutException('Δεν λήφθηκε μέτρηση. Βγες ξυπόλυτος στη ζυγαριά.');
        },
      );

      poll.cancel();
      for (final s in subs) {
        await s.cancel();
      }
      return reading;
    } finally {
      await device.disconnect();
    }
  }

  void dispose() {
    stopScan();
    _deviceCtrl.close();
    _readingCtrl.close();
  }

  void _emitDevices() {
    if (_deviceCtrl.isClosed) return;
    final list = _devices.values.toList()
      ..sort((a, b) => (b.rssi ?? -100).compareTo(a.rssi ?? -100));
    _deviceCtrl.add(list);
  }

  String _deviceName(ScanResult r) {
    final adv = r.advertisementData.advName.trim();
    if (adv.isNotEmpty) return adv;
    final platform = r.device.platformName.trim();
    if (platform.isNotEmpty) return platform;
    return 'Ζυγαριά ${r.device.remoteId.str.substring(0, 8)}';
  }

  bool _looksLikeScale(String name) {
    final n = name.toLowerCase();
    return n.contains('mi') ||
        n.contains('xiaomi') ||
        n.contains('scale') ||
        n.contains('body') ||
        n.contains('mibcs') ||
        n.contains('mibfs') ||
        n.contains('xmtzc') ||
        n.contains('yunmai') ||
        n.contains('ζυγ');
  }

  bool _hasXiaomiData(ScanResult r) => r.advertisementData.manufacturerData.containsKey(_xiaomiCompanyId);

  ScaleReading? _readingFromAdvertisement(ScanResult r) {
    final msd = r.advertisementData.manufacturerData[_xiaomiCompanyId];
    if (msd != null) {
      final parsed = _parseXiaomiManufacturer(msd, _deviceName(r));
      if (parsed != null) return parsed;
    }
    return null;
  }

  /// Xiaomi Mi / Body Composition scale broadcast (company ID 0x0157).
  ScaleReading? _parseXiaomiManufacturer(List<int> data, String deviceName) {
    if (data.length < 13) return null;

    // OpenScale-style stabilized weight packet.
    final ctrl = data[0] & 0xff;
    final isWeight = ctrl == 0x1e || (data.length > 3 && (data[3] & 0xff) == 0x01);
    if (!isWeight) return null;

    final stabilized = data.length > 5 && ((data[5] & 0xff) == 0x20 || (data[3] & 0xff) == 0x01);
    if (!stabilized) return null;

    final raw = (data[11] & 0xff) | ((data[12] & 0xff) << 8);
    final kg = raw / 100.0;
    if (kg < 20 || kg > 300) return null;

    double? bodyFat;
    if (data.length > 10) {
      final bf = data[9] & 0xff;
      if (bf > 0 && bf < 80) bodyFat = bf.toDouble();
    }

    return ScaleReading(
      weightKg: double.parse(kg.toStringAsFixed(1)),
      bodyFatPct: bodyFat,
      measuredAt: DateTime.now(),
      source: 'ble',
      deviceName: deviceName,
    );
  }

  ScaleReading? _parseWeightMeasurement(List<int> data, String deviceName) {
    if (data.length < 3) return null;
    final flags = data[0];
    final isKg = (flags & 0x01) == 0;
    final raw = (data[1] & 0xff) | ((data[2] & 0xff) << 8);
    final kg = raw * (isKg ? 0.005 : 0.45359237 / 100);
    if (kg < 20 || kg > 300) return null;
    return ScaleReading(
      weightKg: double.parse(kg.toStringAsFixed(1)),
      measuredAt: DateTime.now(),
      source: 'ble',
      deviceName: deviceName,
    );
  }

  ScaleReading? _parseMiBodyComposition(List<int> data, String deviceName) {
    if (data.length < 4) return null;
    // Simplified Mi body composition notify — weight often at bytes 2-3 (0.1 kg).
    final raw = (data[2] & 0xff) | ((data[3] & 0xff) << 8);
    final kg = raw / 10.0;
    if (kg < 20 || kg > 300) return null;

    double? bodyFat;
    if (data.length > 5) {
      final bf = data[5] & 0xff;
      if (bf > 0 && bf < 80) bodyFat = bf.toDouble();
    }

    return ScaleReading(
      weightKg: double.parse(kg.toStringAsFixed(1)),
      bodyFatPct: bodyFat,
      measuredAt: DateTime.now(),
      source: 'ble',
      deviceName: deviceName,
    );
  }
}
