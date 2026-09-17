import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../config/tenant_config.dart';
import '../models/nutrition.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/nutrition_body_progress.dart';
import '../widgets/ui_kit.dart';

const _dayNames = ['', 'Δευτέρα', 'Τρίτη', 'Τετάρτη', 'Πέμπτη', 'Παρασκευή', 'Σάββατο', 'Κυριακή'];
const _mealOrder = ['breakfast', 'lunch', 'dinner', 'snack'];

String _mealTypeForHour(int hour) {
  if (hour >= 5 && hour < 11) return 'breakfast';
  if (hour >= 11 && hour < 12) return 'snack';
  if (hour >= 12 && hour < 16) return 'lunch';
  if (hour >= 16 && hour < 18) return 'snack';
  if (hour >= 18 && hour < 23) return 'dinner';
  return 'snack';
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String _isoDate(DateTime d) {
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$day';
}

String _dayTitle(DateTime d) => '${_dayNames[d.weekday]} ${d.day}/${d.month}/${d.year}';

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class NutritionScreen extends StatefulWidget {
  const NutritionScreen({super.key});

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> {
  bool _loading = true;
  bool _savingGoals = false;
  bool _savingMeasurement = false;
  DateTime _selectedDate = _dateOnly(DateTime.now());
  NutritionGoals? _goals;
  NutritionProgress? _progress;
  MealPlanWeek? _weekPlan;
  List<FoodLogEntry> _foodLogs = [];
  List<MealTypeOption> _mealTypes = [];

  final _weightCtrl = TextEditingController();
  final _targetWeightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _bodyFatCtrl = TextEditingController();

  String? _loggingOptionId;
  final _scrollController = ScrollController();
  final _slotKeys = <String, GlobalKey>{};
  bool _didAutoScroll = false;

  String get _apiBase => context.read<TenantConfig>().apiBaseUrl.replaceAll(RegExp(r'/$'), '');
  bool get _isViewingToday => _isSameDay(_selectedDate, DateTime.now());

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _weightCtrl.dispose();
    _targetWeightCtrl.dispose();
    _heightCtrl.dispose();
    _bodyFatCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final api = context.read<AuthService>().api;
    final dateStr = _isoDate(_selectedDate);
    try {
      final results = await Future.wait([
        api.fetchNutritionMealPlan(date: dateStr),
        api.fetchNutritionFoodLogs(date: dateStr),
        api.fetchMealTypes(),
        _goals == null ? api.fetchNutritionGoals() : Future.value(_goals!),
        api.fetchNutritionProgress(),
      ]);
      final week = results[0] as MealPlanWeek;
      final logs = results[1] as List<FoodLogEntry>;
      final types = results[2] as List<MealTypeOption>;
      final goals = results[3] as NutritionGoals;
      final progress = results[4] as NutritionProgress;
      if (!mounted) return;
      setState(() {
        _weekPlan = week;
        _foodLogs = logs;
        _mealTypes = types;
        _goals = goals;
        _progress = progress;
        _didAutoScroll = false;
        _weightCtrl.text = _fmt(goals.weightKg);
        _targetWeightCtrl.text = _fmt(goals.targetWeightKg);
        _heightCtrl.text = _fmt(goals.heightCm);
        _bodyFatCtrl.text = _fmt(goals.bodyFatPct);
        _loading = false;
      });
      if (_isViewingToday) _scheduleScrollToCurrentSlot();
    } on ApiException catch (e) {
      if (mounted) _showSnack(e.message, success: false);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _goToDate(DateTime date) async {
    setState(() => _selectedDate = _dateOnly(date));
    await _load();
  }

  Future<void> _shiftDay(int delta) async {
    await _goToDate(_selectedDate.add(Duration(days: delta)));
  }

  Future<void> _pickDateFromCalendar() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1, 12, 31),
      helpText: 'Επίλεξε ημέρα',
      cancelText: 'Άκυρο',
      confirmText: 'ΟΚ',
    );
    if (picked != null) await _goToDate(picked);
  }

  String _fmt(double? v) {
    if (v == null) return '';
    final t = v.toStringAsFixed(1);
    return t.endsWith('.0') ? t.substring(0, t.length - 2) : t;
  }

  double? _parse(String raw) {
    final n = raw.trim().replaceAll(',', '.');
    if (n.isEmpty) return null;
    return double.tryParse(n);
  }

  void _showSnack(String message, {bool success = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: success ? AppColors.lime : AppColors.surface),
    );
  }

  Future<void> _logMeasurement({
    required double weightKg,
    double? bodyFatPct,
    double? muscleMassKg,
    double? bmi,
    required String measuredOn,
    String? timeOfDay,
    String? measuredTime,
    String? notes,
  }) async {
    setState(() => _savingMeasurement = true);
    try {
      final progress = await context.read<AuthService>().api.logNutritionMeasurement(
            weightKg: weightKg,
            bodyFatPct: bodyFatPct,
            muscleMassKg: muscleMassKg,
            bmi: bmi,
            measuredOn: measuredOn,
            timeOfDay: timeOfDay,
            measuredTime: measuredTime,
            notes: notes,
          );
      if (!mounted) return;
      setState(() {
        _progress = progress;
        _goals = progress.goals;
        _weightCtrl.text = _fmt(progress.goals.weightKg);
        _bodyFatCtrl.text = _fmt(progress.goals.bodyFatPct);
      });
      _showSnack('Η μέτρηση αποθηκεύτηκε');
    } on ApiException catch (e) {
      if (mounted) _showSnack(e.message, success: false);
    }
    if (mounted) setState(() => _savingMeasurement = false);
  }

  Future<void> _saveGoals() async {
    setState(() => _savingGoals = true);
    try {
      final goals = await context.read<AuthService>().api.updateNutritionGoals(
            weightKg: _parse(_weightCtrl.text),
            targetWeightKg: _parse(_targetWeightCtrl.text),
            heightCm: _parse(_heightCtrl.text),
            bodyFatPct: _parse(_bodyFatCtrl.text),
          );
      if (!mounted) return;
      setState(() => _goals = goals);
      _showSnack('Οι στόχοι αποθηκεύτηκαν');
    } on ApiException catch (e) {
      if (mounted) _showSnack(e.message, success: false);
    }
    if (mounted) setState(() => _savingGoals = false);
  }

  Future<void> _logAtePlanOption(MealPlanOption opt, String mealType, {File? photo}) async {
    if (opt.id == null) return;
    setState(() => _loggingOptionId = opt.id);
    try {
      await context.read<AuthService>().api.logFood(
            mealType: mealType,
            description: 'Έφαγα: ${opt.title}',
            planOptionId: opt.id,
            date: _isoDate(_selectedDate),
            photoPath: photo?.path,
          );
      if (!mounted) return;
      _showSnack('Καταγράφηκε — ο διατροφολόγος θα το δει');
      await _load();
    } on ApiException catch (e) {
      if (mounted) _showSnack(e.message, success: false);
    }
    if (mounted) setState(() => _loggingOptionId = null);
  }

  Future<void> _logCustomMeal(String mealType, String desc, {File? photo}) async {
    if (desc.trim().isEmpty) {
      _showSnack('Γράψε τι έφαγες', success: false);
      return;
    }
    try {
      await context.read<AuthService>().api.logFood(
            mealType: mealType,
            description: desc.trim(),
            date: _isoDate(_selectedDate),
            photoPath: photo?.path,
          );
      if (!mounted) return;
      _showSnack('Καταγράφηκε — ο διατροφολόγος θα το δει');
      await _load();
    } on ApiException catch (e) {
      if (mounted) _showSnack(e.message, success: false);
    }
  }

  bool get _hasMealPlan {
    if (_weekPlan == null) return false;
    final planned = _weekPlan!.plannedSlots;
    if (planned != null && planned.isNotEmpty) return true;
    return _weekPlan!.slots.isNotEmpty;
  }

  List<MealPlanSlot> _slotsForSelectedDay() {
    if (!_hasMealPlan) return [];
    final planned = _weekPlan!.plannedSlots;
    if (planned != null && planned.isNotEmpty) {
      final slots = List<MealPlanSlot>.from(planned);
      slots.sort((a, b) => _mealOrder.indexOf(a.mealType).compareTo(_mealOrder.indexOf(b.mealType)));
      return slots;
    }
    final dow = _selectedDate.weekday;
    final slots = _weekPlan!.slots.where((s) => s.dayOfWeek == dow).toList();
    slots.sort((a, b) => _mealOrder.indexOf(a.mealType).compareTo(_mealOrder.indexOf(b.mealType)));
    return slots;
  }

  List<FoodLogEntry> _logsForMeal(String mealType) =>
      _foodLogs.where((l) => l.mealType == mealType).toList();

  bool _isOptionLogged(String? optionId) {
    if (optionId == null) return false;
    return _foodLogs.any((l) => l.planOptionId == optionId);
  }

  GlobalKey _keyForSlot(String mealType) =>
      _slotKeys.putIfAbsent(mealType, GlobalKey.new);

  String? _mealTypeToScroll(List<MealPlanSlot> slots) {
    if (slots.isEmpty) return null;
    final nowMeal = _mealTypeForHour(DateTime.now().hour);
    if (slots.any((s) => s.mealType == nowMeal)) return nowMeal;
    final order = slots.map((s) => s.mealType).toList()
      ..sort((a, b) => _mealOrder.indexOf(a).compareTo(_mealOrder.indexOf(b)));
    final nowIdx = _mealOrder.indexOf(nowMeal);
    for (final meal in order) {
      if (_mealOrder.indexOf(meal) >= nowIdx) return meal;
    }
    return order.last;
  }

  void _scheduleScrollToCurrentSlot({int attempt = 0}) {
    if (!_hasMealPlan || !_isViewingToday || _didAutoScroll || _loading) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _didAutoScroll) return;
      final mealType = _mealTypeToScroll(_slotsForSelectedDay());
      if (mealType == null) return;

      final ctx = _keyForSlot(mealType).currentContext;
      if (ctx != null) {
        await Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeInOut,
          alignment: 0.08,
        );
        if (mounted) _didAutoScroll = true;
        return;
      }
      if (attempt < 10) {
        _scheduleScrollToCurrentSlot(attempt: attempt + 1);
      }
    });
  }

  String _formatShoppingList(List<ShoppingListItem> items) {
    if (items.isEmpty) return '';
    final lines = items.map((item) {
      final buy = item.buyAmount != null
          ? '${item.buyAmount} ${item.buyUnit ?? item.unit}'
          : (item.amount != null ? '${item.amount} ${item.unit}' : item.unit);
      final need = item.neededAmount != null ? ' (χρειάζεσαι ${item.neededAmount} ${item.neededUnit})' : '';
      return '• ${item.ingredient} — αγόρασε $buy$need';
    });
    return 'Λίστα αγορών Handstand\n\n${lines.join('\n')}';
  }

  void _openShoppingList() {
    final hasPlan = _hasMealPlan;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => FutureBuilder<List<ShoppingListItem>>(
        future: hasPlan
            ? context.read<AuthService>().api.fetchNutritionShoppingList(date: _isoDate(_selectedDate), smart: true)
            : Future.value(const []),
        builder: (context, snapshot) {
          final items = snapshot.data ?? [];
          final loading = snapshot.connectionState != ConnectionState.done;
          return _ShoppingListSheet(
            items: items,
            hasPlan: hasPlan,
            loading: loading,
            formatList: _formatShoppingList,
            onCopied: () {
              Navigator.pop(ctx);
              _showSnack('Η λίστα αντιγράφηκε στο clipboard');
            },
          );
        },
      ),
    );
  }

  Widget _dateNavigator() {
    final title = _dayTitle(_selectedDate);
    return SurfaceCard(
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: _loading ? null : () => _shiftDay(-1),
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Προηγούμενη ημέρα',
              ),
              Expanded(
                child: InkWell(
                  onTap: _loading ? null : _pickDateFromCalendar,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      children: [
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: _isViewingToday ? AppColors.lime : null,
                              ),
                        ),
                        if (_isViewingToday)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Σήμερα',
                              style: TextStyle(color: AppColors.lime, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: _loading ? null : () => _shiftDay(1),
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Επόμενη ημέρα',
              ),
              IconButton(
                onPressed: _loading ? null : _pickDateFromCalendar,
                icon: const Icon(Icons.calendar_month_outlined),
                tooltip: 'Ημερολόγιο',
              ),
            ],
          ),
          if (!_isViewingToday)
            TextButton(
              onPressed: _loading ? null : () => _goToDate(DateTime.now()),
              child: const Text('Πήγαινε στο σήμερα'),
            ),
        ],
      ),
    );
  }

  Widget _programHeader() {
    final hasList = _hasMealPlan;
    final currentMeal = _isViewingToday ? _mealTypeForHour(DateTime.now().hour) : null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Πρόγραμμα διατροφής', style: Theme.of(context).textTheme.titleLarge),
              if (_hasMealPlan && currentMeal != null) ...[
                const SizedBox(height: 4),
                Text(
                  _nowMealHint(currentMeal),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.lime,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
              if (_weekPlan?.effectiveFrom != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Πρόγραμμα από ${_weekPlan!.effectiveFrom}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
        FilledButton.tonalIcon(
          onPressed: _openShoppingList,
          icon: const Icon(Icons.shopping_cart_outlined, size: 18),
          label: Text(hasList ? 'Λίστα αγορών' : 'Λίστα'),
          style: FilledButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }

  String _nowMealHint(String mealType) {
    switch (mealType) {
      case 'breakfast':
        return 'Πρωινό τώρα';
      case 'lunch':
        return 'Μεσημεριανό τώρα';
      case 'dinner':
        return 'Βραδινό τώρα';
      case 'snack':
        return 'Σνακ τώρα';
      default:
        return 'Τώρα';
    }
  }

  Widget _pendingPlanCard() {
    return SurfaceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.restaurant_menu, color: AppColors.lime.withValues(alpha: 0.9), size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Το πρόγραμμα διατροφής έρχεται σύντομα',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  'Ο διατροφολόγος σου θα σου στείλει το εβδομαδιαίο πρόγραμμα. Μέχρι τότε μπορείς να καταγράφεις τα γεύματά σου.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayMeals() {
    if (!_hasMealPlan) {
      return Column(
        children: [
          _pendingPlanCard(),
          if (_mealTypes.isNotEmpty) ...[
            const SizedBox(height: 12),
            ..._mealTypes.map(
              (t) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _MealSlotCard(
                  slot: MealPlanSlot(
                    dayOfWeek: _selectedDate.weekday,
                    mealType: t.id,
                    mealTypeLabel: t.label,
                    options: const [],
                  ),
                  logs: _logsForMeal(t.id),
                  apiBase: _apiBase,
                  isNow: false,
                  loggingOptionId: _loggingOptionId,
                  isOptionLogged: _isOptionLogged,
                  onAteOption: (opt, {photo}) => _logAtePlanOption(opt, t.id, photo: photo),
                  onCustomLog: (desc, {photo}) => _logCustomMeal(t.id, desc, photo: photo),
                ),
              ),
            ),
          ],
        ],
      );
    }

    final slots = _slotsForSelectedDay();
    final currentMeal = _isViewingToday ? _mealTypeForHour(DateTime.now().hour) : null;

    if (slots.isEmpty) {
      return Column(
        children: [
          SurfaceCard(
            child: Text(
              'Δεν έχει οριστεί πρόγραμμα για αυτή την ημέρα. Μπορείς να καταγράψεις τι έφαγες.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 12),
          ..._mealTypes.map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _MealSlotCard(
                slot: MealPlanSlot(
                  dayOfWeek: _selectedDate.weekday,
                  mealType: t.id,
                  mealTypeLabel: t.label,
                  options: const [],
                ),
                logs: _logsForMeal(t.id),
                apiBase: _apiBase,
                isNow: false,
                loggingOptionId: _loggingOptionId,
                isOptionLogged: _isOptionLogged,
                onAteOption: (opt, {photo}) => _logAtePlanOption(opt, t.id, photo: photo),
                onCustomLog: (desc, {photo}) => _logCustomMeal(t.id, desc, photo: photo),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        for (final slot in slots)
          Padding(
            key: _keyForSlot(slot.mealType),
            padding: const EdgeInsets.only(bottom: 12),
            child: _MealSlotCard(
              slot: slot,
              logs: _logsForMeal(slot.mealType),
              apiBase: _apiBase,
              isNow: currentMeal == slot.mealType,
              loggingOptionId: _loggingOptionId,
              isOptionLogged: _isOptionLogged,
              onAteOption: (opt, {photo}) => _logAtePlanOption(opt, slot.mealType, photo: photo),
              onCustomLog: (desc, {photo}) => _logCustomMeal(slot.mealType, desc, photo: photo),
            ),
          ),
        if (_weekPlan?.notes != null && _weekPlan!.notes!.trim().isNotEmpty)
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Σημειώσεις διατροφολόγου', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(_weekPlan!.notes!, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildOrphanMealLogs() {
    final slotTypes = _slotsForSelectedDay().map((s) => s.mealType).toSet();
    final orphan = _foodLogs.where((l) => !slotTypes.contains(l.mealType)).toList();
    if (orphan.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Text('Άλλες καταγραφές', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SurfaceCard(
          child: Column(
            children: orphan.map((log) => _LoggedMealRow(log: log, apiBase: _apiBase)).toList(),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _goals == null) {
      return Center(child: const CircularProgressIndicator(color: AppColors.lime));
    }

    return RefreshIndicator(
      color: AppColors.lime,
      onRefresh: _load,
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        children: [
          _programHeader(),
          const SizedBox(height: 12),
          _dateNavigator(),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: const CircularProgressIndicator(color: AppColors.lime)),
            )
          else ...[
            _buildDayMeals(),
            _buildOrphanMealLogs(),
          ],
          const SizedBox(height: 20),
          NutritionBodyProgressPanel(
            progress: _progress,
            saving: _savingMeasurement,
            onLogMeasurement: _logMeasurement,
          ),
          const SizedBox(height: 20),
          Text('Στόχοι', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          SurfaceCard(
            child: Column(
              children: [
                Row(children: [
                  Expanded(child: _field('Βάρος (kg)', _weightCtrl)),
                  const SizedBox(width: 12),
                  Expanded(child: _field('Στόχος (kg)', _targetWeightCtrl)),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _field('Ύψος (cm)', _heightCtrl)),
                  const SizedBox(width: 12),
                  Expanded(child: _field('Λίπος (%)', _bodyFatCtrl)),
                ]),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _savingGoals ? null : _saveGoals,
                  child: Text(_savingGoals ? 'Αποθήκευση...' : 'Αποθήκευση στόχων'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl) {
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      decoration: InputDecoration(labelText: label),
    );
  }
}

class _MealSlotCard extends StatefulWidget {
  const _MealSlotCard({
    required this.slot,
    required this.logs,
    required this.apiBase,
    required this.isNow,
    required this.loggingOptionId,
    required this.isOptionLogged,
    required this.onAteOption,
    required this.onCustomLog,
  });

  final MealPlanSlot slot;
  final List<FoodLogEntry> logs;
  final String apiBase;
  final bool isNow;
  final String? loggingOptionId;
  final bool Function(String? optionId) isOptionLogged;
  final Future<void> Function(MealPlanOption opt, {File? photo}) onAteOption;
  final Future<void> Function(String desc, {File? photo}) onCustomLog;

  @override
  State<_MealSlotCard> createState() => _MealSlotCardState();
}

class _MealSlotCardState extends State<_MealSlotCard> {
  bool _showCustom = false;
  bool _savingCustom = false;
  File? _photo;
  final _customCtrl = TextEditingController();
  final _picker = ImagePicker();

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 85);
    if (picked != null) setState(() => _photo = File(picked.path));
  }

  @override
  Widget build(BuildContext context) {
    final hasLogs = widget.logs.isNotEmpty;

    return Container(
      decoration: widget.isNow
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.lime.withValues(alpha: 0.55), width: 2),
            )
          : null,
      padding: widget.isNow ? const EdgeInsets.all(6) : EdgeInsets.zero,
      child: SurfaceCard(
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(widget.slot.mealTypeLabel, style: Theme.of(context).textTheme.titleMedium),
                  ),
                  if (widget.isNow)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.lime,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Τώρα',
                        style: TextStyle(color: AppColors.bg, fontSize: 11, fontWeight: FontWeight.w800),
                      ),
                    ),
                  if (hasLogs) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.check_circle, color: AppColors.lime, size: 20),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              if (widget.slot.options.isEmpty)
                Text(
                  'Δεν έχει οριστεί πρόγραμμα για αυτό το γεύμα.',
                  style: Theme.of(context).textTheme.bodyMedium,
                )
              else
                ...widget.slot.options.map(
                  (opt) => _PlanOptionTile(
                    opt: opt,
                    apiBase: widget.apiBase,
                    logged: widget.isOptionLogged(opt.id),
                    logging: widget.loggingOptionId == opt.id,
                    onAte: () => widget.onAteOption(opt),
                    onAteWithPhoto: () async {
                      final picked = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
                      if (picked == null) return;
                      await widget.onAteOption(opt, photo: File(picked.path));
                    },
                  ),
                ),
              if (hasLogs) ...[
                const SizedBox(height: 8),
                const Divider(color: AppColors.border),
                const SizedBox(height: 4),
                Text('Καταγράφηκε', style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 6),
                ...widget.logs.map((log) => _LoggedMealRow(log: log, apiBase: widget.apiBase)),
              ],
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => setState(() => _showCustom = !_showCustom),
                icon: Icon(_showCustom ? Icons.expand_less : Icons.edit_note_outlined),
                label: Text(_showCustom ? 'Κλείσιμο' : 'Έφαγα κάτι άλλο'),
              ),
              if (_showCustom) ...[
                TextField(
                  controller: _customCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Τι έφαγες;',
                    hintText: 'π.χ. Σαλάτα αντί για κοτόπουλο',
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _pickPhoto(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: const Text('Gallery'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => _pickPhoto(ImageSource.camera),
                      icon: const Icon(Icons.photo_camera_outlined, size: 18),
                      label: const Text('Κάμερα'),
                    ),
                    if (_photo != null) ...[
                      const SizedBox(width: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.file(_photo!, height: 40, width: 40, fit: BoxFit.cover),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _savingCustom
                      ? null
                      : () async {
                          setState(() => _savingCustom = true);
                          await widget.onCustomLog(_customCtrl.text, photo: _photo);
                          if (mounted) {
                            _customCtrl.clear();
                            _photo = null;
                            _showCustom = false;
                            setState(() => _savingCustom = false);
                          }
                        },
                  child: Text(_savingCustom ? 'Αποθήκευση...' : 'Καταγραφή'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanOptionTile extends StatelessWidget {
  const _PlanOptionTile({
    required this.opt,
    required this.apiBase,
    required this.logged,
    required this.logging,
    required this.onAte,
    required this.onAteWithPhoto,
  });

  final MealPlanOption opt;
  final String apiBase;
  final bool logged;
  final bool logging;
  final VoidCallback onAte;
  final VoidCallback onAteWithPhoto;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: logged ? AppColors.lime.withValues(alpha: 0.06) : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: logged ? AppColors.lime.withValues(alpha: 0.35) : AppColors.border,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (opt.imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network('$apiBase${opt.imageUrl}', height: 120, width: double.infinity, fit: BoxFit.cover),
            ),
          if (opt.imageUrl != null) const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(opt.title, style: Theme.of(context).textTheme.titleSmall)),
              if (logged)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: const Icon(Icons.check_circle, color: AppColors.lime, size: 20),
                ),
            ],
          ),
          if (opt.notes != null && opt.notes!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(opt.notes!, style: Theme.of(context).textTheme.bodySmall),
            ),
          if (opt.portions.isNotEmpty) ...[
            const SizedBox(height: 6),
            ...opt.portions.map(
              (p) => Text(
                '• ${p.ingredient}${p.amount != null ? ': ${p.amount} ${p.unit}' : ''}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
          if (!logged) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: logging ? null : onAte,
                    child: logging
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bg),
                          )
                        : const Text('Το έφαγα'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: logging ? null : onAteWithPhoto,
                  child: const Icon(Icons.photo_camera_outlined, size: 20),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _LoggedMealRow extends StatelessWidget {
  const _LoggedMealRow({required this.log, required this.apiBase});

  final FoodLogEntry log;
  final String apiBase;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check, color: AppColors.lime, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(log.description, style: Theme.of(context).textTheme.bodyMedium),
                if (log.photoUrl != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network('$apiBase${log.photoUrl}', height: 80, fit: BoxFit.cover),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShoppingListSheet extends StatelessWidget {
  const _ShoppingListSheet({
    required this.items,
    required this.hasPlan,
    this.loading = false,
    required this.formatList,
    required this.onCopied,
  });

  final List<ShoppingListItem> items;
  final bool hasPlan;
  final bool loading;
  final String Function(List<ShoppingListItem>) formatList;
  final VoidCallback onCopied;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final maxListHeight = MediaQuery.sizeOf(context).height * 0.45;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.shopping_cart_outlined, color: AppColors.lime),
              const SizedBox(width: 10),
              Expanded(child: Text('Έξυπνη λίστα αγορών', style: Theme.of(context).textTheme.titleLarge)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Προτάσεις σε πρακτικές συσκευασίες (π.χ. 450 ml → 1 λίτρο).',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: const CircularProgressIndicator(color: AppColors.lime)),
            )
          else if (!hasPlan)
            Text(
              'Η λίστα θα εμφανιστεί μόλις ο διατροφολόγος σου στείλει το πρόγραμμα.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else if (items.isEmpty)
            Text(
              'Ο διατροφολόγος δεν έχει ορίσει υλικά ακόμα.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else ...[
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxListHeight),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.border),
                itemBuilder: (_, i) {
                  final item = items[i];
                  final buy = item.buyAmount != null
                      ? '${item.buyAmount} ${item.buyUnit ?? item.unit}'
                      : (item.amount != null ? '${item.amount} ${item.unit}' : item.unit);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.check_box_outline_blank, size: 20, color: AppColors.lime),
                    title: Text(item.ingredient),
                    subtitle: item.suggestion != null
                        ? Text(item.suggestion!, style: Theme.of(context).textTheme.bodySmall)
                        : (item.neededAmount != null
                            ? Text('Χρειάζεσαι ${item.neededAmount} ${item.neededUnit}', style: Theme.of(context).textTheme.bodySmall)
                            : null),
                    trailing: Text(buy, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: formatList(items)));
                onCopied();
              },
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Αντιγραφή λίστας'),
            ),
          ],
        ],
      ),
    );
  }
}
