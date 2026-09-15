import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/nutrition.dart';
import '../models/scale_reading.dart';
import '../services/demo_metrics_service.dart';
import '../theme/app_colors.dart';
import 'scale_sync_sheet.dart';
import 'ui_kit.dart';

class NutritionBodyProgressPanel extends StatefulWidget {
  const NutritionBodyProgressPanel({
    super.key,
    required this.progress,
    required this.onLogMeasurement,
    this.saving = false,
  });

  final NutritionProgress? progress;
  final Future<void> Function({
    required double weightKg,
    double? bodyFatPct,
    double? muscleMassKg,
    double? bmi,
    required String measuredOn,
    String? timeOfDay,
    String? measuredTime,
    String? notes,
  }) onLogMeasurement;
  final bool saving;

  @override
  State<NutritionBodyProgressPanel> createState() => _NutritionBodyProgressPanelState();
}

class _NutritionBodyProgressPanelState extends State<NutritionBodyProgressPanel>
    with SingleTickerProviderStateMixin {
  final _weightCtrl = TextEditingController();
  final _bodyFatCtrl = TextEditingController();
  late final AnimationController _pulseCtrl;
  DateTime _selectedDate = DateTime.now();
  String _timeOfDay = 'morning';
  bool _useExactTime = false;
  TimeOfDay _exactTime = TimeOfDay.now();
  bool _seedingDemo = false;

  static const _timeOfDayOptions = [
    ('morning', 'Πρωί'),
    ('noon', 'Μεσημέρι'),
    ('afternoon', 'Απόγευμα'),
    ('evening', 'Βράδυ'),
  ];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _weightCtrl.dispose();
    _bodyFatCtrl.dispose();
    super.dispose();
  }

  String _isoDate(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  String _formatDateLabel(DateTime d) => '${d.day}/${d.month}/${d.year}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(DateTime.now().year - 2),
      lastDate: DateTime.now(),
      helpText: 'Πότε έκανες τη μέτρηση;',
      cancelText: 'Άκυρο',
      confirmText: 'ΟΚ',
    );
    if (picked != null) setState(() => _selectedDate = DateTime(picked.year, picked.month, picked.day));
  }

  Future<void> _pickExactTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _exactTime,
      helpText: 'Ώρα μέτρησης',
      cancelText: 'Άκυρο',
      confirmText: 'ΟΚ',
    );
    if (picked != null) setState(() => _exactTime = picked);
  }

  String? _measuredTimeParam() {
    if (!_useExactTime) return null;
    final h = _exactTime.hour.toString().padLeft(2, '0');
    final m = _exactTime.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  void _applyScaleReading(ScaleReading reading) {
    setState(() {
      _weightCtrl.text = _fmt(reading.weightKg);
      if (reading.bodyFatPct != null) {
        _bodyFatCtrl.text = _fmt(reading.bodyFatPct);
      }
      _selectedDate = DateTime(reading.measuredAt.year, reading.measuredAt.month, reading.measuredAt.day);
      _useExactTime = true;
      _exactTime = TimeOfDay(hour: reading.measuredAt.hour, minute: reading.measuredAt.minute);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Έτοιμο: ${reading.weightKg} kg από ${reading.sourceLabel}')),
    );
  }

  Future<void> _openScaleSync() async {
    await showScaleSyncSheet(
      context,
      onApply: (reading) async {
        _applyScaleReading(reading);
        await _submitFromScale(reading);
      },
    );
  }

  Future<void> _seedDemoProgress() async {
    setState(() => _seedingDemo = true);
    try {
      for (final point in DemoMetricsService.weeklyProgressSeries()) {
        await widget.onLogMeasurement(
          weightKg: point.weightKg,
          bodyFatPct: point.bodyFatPct,
          measuredOn: point.measuredOn,
          notes: 'Demo iPhone simulate',
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Φορτώθηκαν 6 εβδομαδιαίες μετρήσεις demo')),
      );
    } finally {
      if (mounted) setState(() => _seedingDemo = false);
    }
  }

  Future<void> _submitFromScale(ScaleReading reading) async {
    await widget.onLogMeasurement(
      weightKg: reading.weightKg,
      bodyFatPct: reading.bodyFatPct,
      muscleMassKg: reading.muscleMassKg,
      bmi: reading.bmi,
      measuredOn: _isoDate(reading.measuredAt),
      measuredTime: formatMeasuredTime(reading.measuredAt),
      notes: 'Συγχρονισμός: ${reading.sourceLabel}',
    );
    if (!mounted) return;
    _weightCtrl.clear();
    _bodyFatCtrl.clear();
  }

  Future<void> _submit() async {
    final weight = _parse(_weightCtrl.text);
    if (weight == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Βάλε το βάρος σου σε kg')),
      );
      return;
    }
    await widget.onLogMeasurement(
      weightKg: weight,
      bodyFatPct: _parse(_bodyFatCtrl.text),
      measuredOn: _isoDate(_selectedDate),
      timeOfDay: _useExactTime ? null : _timeOfDay,
      measuredTime: _measuredTimeParam(),
    );
    if (!mounted) return;
    _weightCtrl.clear();
    _bodyFatCtrl.clear();
  }

  double? _parse(String raw) {
    final n = raw.trim().replaceAll(',', '.');
    if (n.isEmpty) return null;
    return double.tryParse(n);
  }

  String _fmt(double? v) {
    if (v == null) return '—';
    final t = v.toStringAsFixed(1);
    return t.endsWith('.0') ? t.substring(0, t.length - 2) : t;
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.progress;
    final goals = progress?.goals;
    final latest = progress?.latestMeasurement;
    final weightSeries = progress?.chart['weight'] ?? const <NutritionChartPoint>[];
    final fatSeries = progress?.chart['body_fat_pct'] ?? const <NutritionChartPoint>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            BodySilhouetteIcon(animation: _pulseCtrl),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Σώμα & στόχοι', style: Theme.of(context).textTheme.titleLarge),
                  Text(
                    'Καταγράφε το βάρος σου και παρακολούθησε την πρόοδο.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.monitor_weight_outlined, color: AppColors.lime, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Νέα μέτρηση',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: widget.saving ? null : _openScaleSync,
                    icon: const Icon(Icons.bluetooth_connected, size: 16),
                    label: const Text('Ζυγαριά'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.lime,
                      side: BorderSide(color: AppColors.lime.withValues(alpha: 0.4)),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Health (Zepp Life) ή Bluetooth Xiaomi',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(8),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Ημερομηνία',
                    suffixIcon: Icon(Icons.calendar_today_outlined, size: 20),
                  ),
                  child: Text(_formatDateLabel(_selectedDate)),
                ),
              ),
              const SizedBox(height: 12),
              Text('Στιγμή ημέρας', style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ..._timeOfDayOptions.map((opt) {
                    final selected = !_useExactTime && _timeOfDay == opt.$1;
                    return ChoiceChip(
                      label: Text(opt.$2),
                      selected: selected,
                      onSelected: _useExactTime
                          ? null
                          : (v) {
                              if (v) setState(() => _timeOfDay = opt.$1);
                            },
                      selectedColor: AppColors.lime.withValues(alpha: 0.25),
                    );
                  }),
                  ChoiceChip(
                    label: Text(_useExactTime
                        ? 'Ώρα ${_measuredTimeParam()}'
                        : 'Ακριβής ώρα'),
                    selected: _useExactTime,
                    onSelected: (v) async {
                      if (v) {
                        setState(() => _useExactTime = true);
                        await _pickExactTime();
                      } else {
                        setState(() => _useExactTime = false);
                      }
                    },
                    selectedColor: AppColors.lime.withValues(alpha: 0.25),
                  ),
                ],
              ),
              if (_useExactTime)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextButton.icon(
                    onPressed: _pickExactTime,
                    icon: const Icon(Icons.access_time, size: 18),
                    label: Text('Αλλαγή ώρας (${_measuredTimeParam()})'),
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _weightCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                      decoration: const InputDecoration(labelText: 'Βάρος (kg) *', hintText: 'π.χ. 72.5'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _bodyFatCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                      decoration: const InputDecoration(labelText: 'Λίπος % (προαιρ.)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: widget.saving ? null : _submit,
                icon: widget.saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bg),
                      )
                    : const Icon(Icons.save_outlined, size: 18),
                label: Text(widget.saving ? 'Αποθήκευση...' : 'Αποθήκευση μέτρησης'),
              ),
              if (kDebugMode) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: (_seedingDemo || widget.saving) ? null : _seedDemoProgress,
                  icon: _seedingDemo
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.show_chart_outlined, size: 18),
                  label: Text(_seedingDemo ? 'Φόρτωση demo...' : 'Demo γράφημα (6 εβδομάδες)'),
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.orange),
                ),
              ],
            ],
          ),
        ),
        if (progress != null && (latest != null || goals?.targetWeightKg != null)) ...[
          const SizedBox(height: 16),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (goals?.targetWeightKg != null) ...[
                  Row(
                    children: [
                      Expanded(
                        child: AnimatedGoalRing(
                          label: 'Βάρος',
                          valueLabel: latest?.weightKg != null
                              ? '${_fmt(latest!.weightKg)} kg'
                              : _fmt(goals?.weightKg) != '—'
                                  ? '${_fmt(goals?.weightKg)} kg'
                                  : '—',
                          targetLabel: 'Στόχος ${_fmt(goals?.targetWeightKg)} kg',
                          percent: progress.weightGoalPct ?? 0,
                          color: AppColors.lime,
                        ),
                      ),
                      if (goals?.targetBodyFatPct != null) ...[
                        const SizedBox(width: 16),
                        Expanded(
                          child: AnimatedGoalRing(
                            label: 'Λίπος',
                            valueLabel: latest?.bodyFatPct != null ? '${_fmt(latest!.bodyFatPct)}%' : '—',
                            targetLabel: 'Στόχος ${_fmt(goals?.targetBodyFatPct)}%',
                            percent: progress.bodyFatGoalPct ?? 0,
                            color: AppColors.teal,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
                if (weightSeries.length >= 2) ...[
                  Text('Εξέλιξη βάρους', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 120,
                    child: AnimatedSparklineChart(
                      points: weightSeries,
                      color: AppColors.lime,
                      target: goals?.targetWeightKg,
                      unit: 'kg',
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (fatSeries.length >= 2) ...[
                  Text('Εξέλιξη λίπους %', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 120,
                    child: AnimatedSparklineChart(
                      points: fatSeries,
                      color: AppColors.teal,
                      target: goals?.targetBodyFatPct,
                      unit: '%',
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (progress.visits.isNotEmpty) ...[
                  Text('Ιστορικό μετρήσεων', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  ...progress.visits.take(8).map((v) => _VisitTile(visit: v, fmt: _fmt)),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _VisitTile extends StatelessWidget {
  const _VisitTile({required this.visit, required this.fmt});

  final NutritionVisit visit;
  final String Function(double?) fmt;

  @override
  Widget build(BuildContext context) {
    final isAthlete = visit.recordedBy == 'athlete';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isAthlete ? AppColors.lime : AppColors.purple,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  visit.measuredWhen ?? visit.date,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  isAthlete ? 'Από εσένα' : 'Μετρήσεις διατροφολόγου',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          if (visit.weightKg != null)
            Text('${fmt(visit.weightKg)} kg', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
          if (visit.bodyFatPct != null) ...[
            const SizedBox(width: 8),
            Text('${fmt(visit.bodyFatPct)}%', style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

class BodySilhouetteIcon extends StatelessWidget {
  const BodySilhouetteIcon({super.key, required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final scale = 1.0 + animation.value * 0.04;
        return Transform.scale(scale: scale, child: child);
      },
      child: Container(
        width: 72,
        height: 110,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFF121826),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Image.asset(
          'assets/icons/body_measurements.png',
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class AnimatedGoalRing extends StatelessWidget {
  const AnimatedGoalRing({
    required this.label,
    required this.valueLabel,
    required this.targetLabel,
    required this.percent,
    required this.color,
  });

  final String label;
  final String valueLabel;
  final String targetLabel;
  final int percent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: percent.clamp(0, 100) / 100),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return Column(
          children: [
            SizedBox(
              width: 96,
              height: 96,
              child: CustomPaint(
                painter: _RingPainter(progress: value, color: color),
                child: Center(
                  child: Text(
                    '${(value * 100).round()}%',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: color),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            Text(valueLabel, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            Text(targetLabel, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
          ],
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    final bg = Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;
    final fg = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bg);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      fg,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

class AnimatedSparklineChart extends StatefulWidget {
  const AnimatedSparklineChart({
    required this.points,
    required this.color,
    this.target,
    required this.unit,
  });

  final List<NutritionChartPoint> points;
  final Color color;
  final double? target;
  final String unit;

  @override
  State<AnimatedSparklineChart> createState() => _AnimatedSparklineChartState();
}

class _AnimatedSparklineChartState extends State<AnimatedSparklineChart> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..forward();
  }

  @override
  void didUpdateWidget(covariant AnimatedSparklineChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.points.length != widget.points.length) {
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return CustomPaint(
          painter: _SparklinePainter(
            points: widget.points,
            color: widget.color,
            target: widget.target,
            progress: _ctrl.value,
          ),
          child: Container(),
        );
      },
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.points,
    required this.color,
    required this.target,
    required this.progress,
  });

  final List<NutritionChartPoint> points;
  final Color color;
  final double? target;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final values = points.map((p) => p.value).toList();
    var minV = values.reduce(math.min);
    var maxV = values.reduce(math.max);
    if (target != null) {
      minV = math.min(minV, target!);
      maxV = math.max(maxV, target!);
    }
    final range = (maxV - minV).abs() < 0.01 ? 1.0 : maxV - minV;
    final padX = 8.0;
    final padY = 12.0;
    final w = size.width - padX * 2;
    final h = size.height - padY * 2;

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = padX + (i / (points.length - 1)) * w;
      final y = padY + h - ((values[i] - minV) / range) * h;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        final prevX = padX + ((i - 1) / (points.length - 1)) * w;
        final prevY = padY + h - ((values[i - 1] - minV) / range) * h;
        final cx = (prevX + x) / 2;
        path.cubicTo(cx, prevY, cx, y, x, y);
      }
    }

    final metrics = path.computeMetrics();
    Path drawPath = Path();
    for (final m in metrics) {
      drawPath.addPath(m.extractPath(0, m.length * progress), Offset.zero);
    }

    final grid = Paint()
      ..color = AppColors.border.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    for (var i = 1; i <= 3; i++) {
      final y = padY + (h / 4) * i;
      canvas.drawLine(Offset(padX, y), Offset(size.width - padX, y), grid);
    }

    if (target != null) {
      final ty = padY + h - ((target! - minV) / range) * h;
      final targetPaint = Paint()
        ..color = AppColors.orange.withValues(alpha: 0.7)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(padX, ty), Offset(size.width - padX, ty), targetPaint);
    }

    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(drawPath, line);

    if (progress > 0.05) {
      final fill = Path()..addPath(drawPath, Offset.zero);
      final lastPoint = drawPath.getBounds();
      fill
        ..lineTo(lastPoint.right, size.height - padY)
        ..lineTo(padX, size.height - padY)
        ..close();
      canvas.drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0.02)],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
      );
      canvas.drawPath(drawPath, line);
    }

    final lastIdx = (points.length - 1).clamp(0, points.length - 1);
    final lx = padX + (lastIdx / (points.length - 1)) * w;
    final ly = padY + h - ((values[lastIdx] - minV) / range) * h;
    canvas.drawCircle(Offset(lx, ly), 5, Paint()..color = color);
    canvas.drawCircle(Offset(lx, ly), 5, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.5);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.points != points;
}
