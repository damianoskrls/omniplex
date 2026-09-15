import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/scale_reading.dart';
import '../services/ble_scale_service.dart';
import '../services/demo_metrics_service.dart';
import '../services/health_scale_service.dart';
import '../theme/app_colors.dart';

typedef ScaleReadingApplied = Future<void> Function(ScaleReading reading);

Future<void> showScaleSyncSheet(
  BuildContext context, {
  required ScaleReadingApplied onApply,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _ScaleSyncSheet(onApply: onApply),
  );
}

class _ScaleSyncSheet extends StatefulWidget {
  const _ScaleSyncSheet({required this.onApply});

  final ScaleReadingApplied onApply;

  @override
  State<_ScaleSyncSheet> createState() => _ScaleSyncSheetState();
}

class _ScaleSyncSheetState extends State<_ScaleSyncSheet> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _health = HealthScaleService.instance;
  final _ble = BleScaleService.instance;

  bool _healthLoading = false;
  String? _healthError;
  ScaleReading? _healthPreview;
  bool _demoLoading = false;

  bool _bleScanning = false;
  String? _bleError;
  List<BleScaleDeviceInfo> _bleDevices = [];
  String? _connectingId;
  ScaleReading? _blePreview;

  StreamSubscription<List<BleScaleDeviceInfo>>? _deviceSub;
  StreamSubscription<ScaleReading>? _readingSub;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _deviceSub = _ble.devices.listen((d) {
      if (mounted) setState(() => _bleDevices = d);
    });
    _readingSub = _ble.readings.listen((r) {
      if (mounted) setState(() => _blePreview = r);
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _deviceSub?.cancel();
    _readingSub?.cancel();
    _ble.stopScan();
    super.dispose();
  }

  Future<void> _syncHealth() async {
    setState(() {
      _healthLoading = true;
      _healthError = null;
      _healthPreview = null;
    });
    try {
      if (!_health.isSupported) {
        throw StateError('Διαθέσιμο μόνο σε iPhone/Android');
      }
      final reading = await _health.fetchLatestReading();
      if (!mounted) return;
      if (reading == null) {
        setState(() {
          _healthError = Platform.isIOS
              ? 'Δεν βρέθηκε βάρος στο Apple Health. Σύνδεσε πρώτα την Xiaomi ζυγαριά στο Zepp Life / Apple Health.'
              : 'Δεν βρέθηκε βάρος στο Health Connect. Εγκατάστησε Health Connect και σύνδεσε την Zepp Life.';
        });
      } else {
        setState(() => _healthPreview = reading);
      }
    } catch (e) {
      if (mounted) setState(() => _healthError = e.toString());
    } finally {
      if (mounted) setState(() => _healthLoading = false);
    }
  }

  Future<void> _simulateHealthReading() async {
    setState(() {
      _healthError = null;
      _healthPreview = DemoMetricsService.simulatedHealthReading();
    });
  }

  Future<void> _writeDemoToHealth() async {
    setState(() {
      _demoLoading = true;
      _healthError = null;
      _healthPreview = null;
    });
    try {
      final reading = await _health.writeDemoReadingToHealth();
      if (!mounted) return;
      if (reading == null) {
        setState(() {
          _healthError = 'Δεν ήταν δυνατή η εγγραφή/ανάγνωση από Apple Health. Έλεγξε τα δικαιώματα Health.';
        });
      } else {
        setState(() => _healthPreview = reading);
      }
    } catch (e) {
      if (mounted) setState(() => _healthError = e.toString());
    } finally {
      if (mounted) setState(() => _demoLoading = false);
    }
  }

  Future<void> _startBleScan() async {
    setState(() {
      _bleScanning = true;
      _bleError = null;
      _blePreview = null;
      _bleDevices = [];
    });
    try {
      await _ble.startScan();
    } catch (e) {
      if (mounted) setState(() => _bleError = e.toString());
    } finally {
      if (mounted) setState(() => _bleScanning = false);
    }
  }

  Future<void> _connectBle(String deviceId) async {
    setState(() {
      _connectingId = deviceId;
      _bleError = null;
    });
    try {
      final reading = await _ble.readFromDevice(deviceId);
      if (mounted) setState(() => _blePreview = reading);
    } catch (e) {
      if (mounted) setState(() => _bleError = e.toString());
    } finally {
      if (mounted) setState(() => _connectingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Συγχρονισμός ζυγαριάς', style: Theme.of(context).textTheme.titleLarge),
          Text(
            'Apple Health / Health Connect ή άμεση σύνδεση Bluetooth (Xiaomi κ.λπ.)',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          TabBar(
            controller: _tabs,
            labelColor: AppColors.lime,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.lime,
            tabs: const [
              Tab(text: 'Health'),
              Tab(text: 'Bluetooth'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 320,
            child: TabBarView(
              controller: _tabs,
              children: [
                _healthTab(),
                _bleTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _healthTab() {
    return ListView(
      children: [
        Text(
          Platform.isIOS
              ? 'Διάβασε το τελευταίο βάρος από Apple Health (π.χ. μέσω Zepp Life / Mi Fit).'
              : 'Διάβασε το τελευταίο βάρος από Health Connect (π.χ. μέσω Zepp Life).',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _healthLoading ? null : _syncHealth,
          icon: _healthLoading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.favorite_outline, size: 18),
          label: Text(_healthLoading ? 'Αναζήτηση...' : 'Συγχρονισμός Health'),
        ),
        if (_healthError != null) ...[
          const SizedBox(height: 12),
          Text(_healthError!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13)),
        ],
        if (_healthPreview != null) ...[
          const SizedBox(height: 16),
          _readingCard(_healthPreview!),
        ],
        if (kDebugMode) ...[
          const SizedBox(height: 20),
          Text(
            'Προσομοίωση (dev)',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppColors.orange),
          ),
          const SizedBox(height: 8),
          Text(
            'Δοκίμασε το flow χωρίς ζυγαριά — γράφει δείγμα στο Apple Health ή εμφανίζει fake reading.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _simulateHealthReading,
            icon: const Icon(Icons.phone_iphone, size: 18),
            label: const Text('Προσομοίωση μέτρησης'),
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: _demoLoading ? null : _writeDemoToHealth,
            icon: _demoLoading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.favorite, size: 18),
            label: Text(_demoLoading ? 'Εγγραφή στο Health...' : 'Γράψε στο Apple Health & sync'),
          ),
        ],
      ],
    );
  }

  Widget _bleTab() {
    return ListView(
      children: [
        Text(
          'Άνοιξε Bluetooth, βγες ξυπόλυτος στη ζυγαριά και πάτα «Σάρωση». Υποστηρίζονται Xiaomi Mi / Body Composition.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _bleScanning ? null : _startBleScan,
                icon: _bleScanning
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.bluetooth_searching, size: 18),
                label: Text(_bleScanning ? 'Σάρωση...' : 'Σάρωση ζυγαριών'),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () => _ble.stopScan(),
              child: const Text('Stop'),
            ),
          ],
        ),
        if (_bleError != null) ...[
          const SizedBox(height: 12),
          Text(_bleError!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13)),
        ],
        if (_blePreview != null) ...[
          const SizedBox(height: 12),
          _readingCard(_blePreview!),
        ],
        if (_bleDevices.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Συσκευές', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          ..._bleDevices.map((d) {
            final busy = _connectingId == d.id;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.bluetooth, color: AppColors.lime),
                title: Text(d.name),
                subtitle: Text(
                  d.lastReading != null
                      ? 'Τελευταίο: ${d.lastReading!.weightKg} kg'
                      : 'Πάτα για σύνδεση — σκέψου τη ζυγαριά',
                ),
                trailing: busy
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.chevron_right),
                onTap: busy ? null : () => _connectBle(d.id),
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _readingCard(ScaleReading r) {
    return Card(
      color: AppColors.lime.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${r.weightKg} kg', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            if (r.bodyFatPct != null) Text('Λίπος: ${r.bodyFatPct}%'),
            Text(
              'Πηγή: ${r.sourceLabel}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: () async {
                await widget.onApply(r);
                if (!mounted) return;
                Navigator.of(context).pop();
              },
              child: const Text('Αποθήκευση μέτρησης'),
            ),
          ],
        ),
      ),
    );
  }
}

String timeOfDayFromDateTime(DateTime dt) {
  final h = dt.hour;
  if (h < 11) return 'morning';
  if (h < 14) return 'noon';
  if (h < 18) return 'afternoon';
  return 'evening';
}

String formatMeasuredTime(DateTime dt) {
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '$h:$m';
}
