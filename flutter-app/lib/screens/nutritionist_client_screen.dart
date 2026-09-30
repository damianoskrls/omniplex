import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';

const _days = ['Δευ', 'Τρί', 'Τετ', 'Πέμ', 'Παρ', 'Σάβ', 'Κυρ'];
const _meals = [
  ('breakfast', 'Πρωινό'),
  ('lunch', 'Μεσημεριανό'),
  ('dinner', 'Βραδινό'),
  ('snack', 'Σνακ'),
];
const _units = ['g', 'kg', 'ml', 'l', 'cup', 'κ.σ.', 'κ.γ.', 'τεμ', 'φέτες'];

class NutritionistClientScreen extends StatefulWidget {
  const NutritionistClientScreen({super.key, required this.userId, required this.name});
  final String userId;
  final String name;

  @override
  State<NutritionistClientScreen> createState() => _NutritionistClientScreenState();
}

class _MealOption {
  _MealOption({this.title = '', this.notes = '', List<_Portion>? portions})
      : portions = portions ?? [_Portion()];
  String title;
  String notes;
  List<_Portion> portions;

  Map<String, dynamic> toJson() => {
    'title': title,
    'description': title,
    'notes': notes,
    'portions': portions
        .where((p) => p.ingredient.trim().isNotEmpty)
        .map((p) => {
              'ingredient': p.ingredient.trim(),
              'amount': p.amount.trim(),
              'unit': p.unit,
            })
        .toList(),
  };
}

class _Portion {
  _Portion({this.ingredient = '', this.amount = '', this.unit = 'g'});
  String ingredient;
  String amount;
  String unit;
}

class _NutritionistClientScreenState extends State<NutritionistClientScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool _loading = true;
  String? _error;

  final _weight = TextEditingController();
  final _height = TextEditingController();
  final _fat = TextEditingController();
  final _bmi = TextEditingController();
  final _muscle = TextEditingController();
  final _fatMass = TextEditingController();
  final _visceral = TextEditingController();
  final _notes = TextEditingController();
  String _measuredOn = DateTime.now().toIso8601String().substring(0, 10);
  String _timeOfDay = 'morning';

  List<Map<String, dynamic>> _measurements = [];
  final _targetWeight = TextEditingController();
  final _targetFat = TextEditingController();
  final _goalHeight = TextEditingController();

  final Map<String, List<_MealOption>> _slots = {};
  String _effectiveFrom = DateTime.now().toIso8601String().substring(0, 10);
  final _planNotes = TextEditingController();
  List<Map<String, dynamic>> _versions = [];
  List<Map<String, dynamic>> _templates = [];
  int _day = 1;

  DateTime _logDate = DateTime.now();
  Map<String, dynamic> _dayDetail = {};

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    for (final c in [_weight, _height, _fat, _bmi, _muscle, _fatMass, _visceral, _notes, _targetWeight, _targetFat, _goalHeight, _planNotes]) {
      c.dispose();
    }
    super.dispose();
  }

  String _key(int day, String meal) => '$day:$meal';

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = context.read<AuthService>().api;
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final results = await Future.wait([
        api.fetchNutritionGoalsAdmin(widget.userId),
        api.fetchNutritionMealPlanAdmin(widget.userId),
        api.fetchNutritionMeasurementsAdmin(widget.userId),
        api.fetchNutritionClientDay(widget.userId, today),
        api.fetchNutritionTemplates(),
        api.fetchNutritionPlanVersions(widget.userId),
      ]);
      if (!mounted) return;
      final goals = results[0] as Map<String, dynamic>;
      final plan = results[1] as Map<String, dynamic>;
      final measurements = results[2] as Map<String, dynamic>;
      setState(() {
        _targetWeight.text = goals['target_weight_kg']?.toString() ?? '';
        _targetFat.text = goals['target_body_fat_pct']?.toString() ?? '';
        _goalHeight.text = goals['height_cm']?.toString() ?? '';
        _measurements = ((measurements['measurements'] as List?) ?? []).cast<Map<String, dynamic>>();
        _applyPlan(plan);
        _versions = results[5] as List<Map<String, dynamic>>;
        _templates = results[4] as List<Map<String, dynamic>>;
        _dayDetail = results[3] as Map<String, dynamic>;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyPlan(Map<String, dynamic> plan) {
    _slots.clear();
    final slots = (plan['slots'] as List?) ?? const [];
    for (final raw in slots) {
      if (raw is! Map) continue;
      final day = (raw['day_of_week'] as num?)?.toInt() ?? 1;
      final meal = raw['meal_type']?.toString() ?? 'breakfast';
      final options = ((raw['options'] as List?) ?? []).whereType<Map>().map((o) {
        final portions = ((o['portions'] as List?) ?? []).whereType<Map>().map((p) => _Portion(
          ingredient: p['ingredient']?.toString() ?? '',
          amount: p['amount']?.toString() ?? '',
          unit: p['unit']?.toString() ?? 'g',
        )).toList();
        return _MealOption(
          title: o['title']?.toString() ?? o['description']?.toString() ?? '',
          notes: o['notes']?.toString() ?? '',
          portions: portions.isEmpty ? [_Portion()] : portions,
        );
      }).toList();
      _slots[_key(day, meal)] = options;
    }
    _effectiveFrom = plan['effective_from']?.toString() ?? _effectiveFrom;
    _planNotes.text = plan['notes']?.toString() ?? '';
  }

  List<Map<String, dynamic>> _slotPayload() {
    final slots = <Map<String, dynamic>>[];
    for (var day = 1; day <= 7; day++) {
      for (final meal in _meals) {
        final options = _slots[_key(day, meal.$1)] ?? const <_MealOption>[];
        final kept = options.where((o) => o.title.trim().isNotEmpty).toList();
        if (kept.isEmpty) continue;
        slots.add({
          'day_of_week': day,
          'meal_type': meal.$1,
          'options': kept.map((o) => o.toJson()).toList(),
        });
      }
    }
    return slots;
  }

  Future<void> _saveMeasurement() async {
    try {
      await context.read<AuthService>().api.addNutritionMeasurement(widget.userId, {
        'measured_on': _measuredOn,
        'time_of_day': _timeOfDay,
        'weight_kg': _weight.text.trim(),
        'height_cm': _height.text.trim(),
        'body_fat_pct': _fat.text.trim(),
        'bmi': _bmi.text.trim(),
        'muscle_mass_kg': _muscle.text.trim(),
        'fat_mass_kg': _fatMass.text.trim(),
        'visceral_fat_level': _visceral.text.trim(),
        'notes': _notes.text.trim(),
      });
      _weight.clear();
      _fat.clear();
      _bmi.clear();
      _muscle.clear();
      _fatMass.clear();
      _visceral.clear();
      _notes.clear();
      await _load();
      if (mounted) _toast('Η μέτρηση καταχωρήθηκε');
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }

  Future<void> _saveGoals() async {
    try {
      await context.read<AuthService>().api.saveNutritionGoalsAdmin(widget.userId, {
        'target_weight_kg': _targetWeight.text.trim(),
        'target_body_fat_pct': _targetFat.text.trim(),
        'height_cm': _goalHeight.text.trim(),
      });
      _toast('Οι στόχοι αποθηκεύτηκαν');
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }

  Future<void> _savePlan() async {
    try {
      final plan = await context.read<AuthService>().api.saveNutritionMealPlan(widget.userId, {
        'effective_from': _effectiveFrom,
        'notes': _planNotes.text.trim(),
        'slots': _slotPayload(),
      });
      final versions = await context.read<AuthService>().api.fetchNutritionPlanVersions(widget.userId);
      if (!mounted) return;
      setState(() {
        _applyPlan(plan);
        _versions = versions;
      });
      _toast('Το πρόγραμμα αποθηκεύτηκε');
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }

  Future<void> _applyTemplate(String id) async {
    try {
      await context.read<AuthService>().api.applyNutritionTemplate(widget.userId, id, effectiveFrom: _effectiveFrom);
      final plan = await context.read<AuthService>().api.fetchNutritionMealPlanAdmin(widget.userId, date: _effectiveFrom);
      if (!mounted) return;
      setState(() => _applyPlan(plan));
      _toast('Το πρότυπο εφαρμόστηκε');
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }

  Future<void> _saveAsTemplate() async {
    final name = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Αποθήκευση ως πρότυπο'),
        content: TextField(controller: name, decoration: const InputDecoration(labelText: 'Όνομα προτύπου')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Άκυρο')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Αποθήκευση')),
        ],
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    try {
      await context.read<AuthService>().api.saveNutritionTemplate({
        'name': name.text.trim(),
        'notes': _planNotes.text.trim(),
        'slots': _slotPayload(),
      });
      _toast('Το πρότυπο αποθηκεύτηκε');
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }

  Future<void> _shopping() async {
    try {
      final items = await context.read<AuthService>().api.smartNutritionShoppingList(_slotPayload());
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          builder: (_, scroll) => ListView(
            controller: scroll,
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Λίστα αγορών', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 12),
              if (items.isEmpty) const Text('Δεν υπάρχουν υλικά στο πρόγραμμα.'),
              ...items.map((item) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item['ingredient']?.toString() ?? ''),
                subtitle: Text(item['suggestion']?.toString()
                    ?? '${item['buy_amount'] ?? item['needed_amount'] ?? ''} ${item['buy_unit'] ?? item['needed_unit'] ?? ''}'),
              )),
            ],
          ),
        ),
      );
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }

  Future<void> _notify() async {
    final body = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ειδοποίηση πελάτη'),
        content: TextField(controller: body, maxLines: 3, decoration: const InputDecoration(labelText: 'Μήνυμα')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Άκυρο')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Αποστολή')),
        ],
      ),
    );
    if (ok != true || body.text.trim().isEmpty) return;
    try {
      await context.read<AuthService>().api.notifyNutritionClient(
        widget.userId,
        title: 'Υπενθύμιση διατροφής',
        body: body.text.trim(),
      );
      _toast('Η ειδοποίηση στάλθηκε');
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }

  Future<void> _loadDay(DateTime date) async {
    final iso = date.toIso8601String().substring(0, 10);
    try {
      final day = await context.read<AuthService>().api.fetchNutritionClientDay(widget.userId, iso);
      if (mounted) setState(() { _logDate = date; _dayDetail = day; });
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }

  Future<void> _editOption(int day, String meal, _MealOption? existing) async {
    final option = existing ?? _MealOption();
    final saved = await showModalBottomSheet<_MealOption>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _MealEditorSheet(option: option),
    );
    if (saved == null) return;
    setState(() {
      final list = _slots.putIfAbsent(_key(day, meal), () => []);
      final index = list.indexOf(option);
      if (index >= 0) {
        list[index] = saved;
      } else {
        list.add(saved);
      }
    });
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: Text(widget.name),
        actions: [
          IconButton(onPressed: _notify, icon: const Icon(Icons.notifications_outlined), tooltip: 'Ειδοποίηση'),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Μετρήσεις'),
            Tab(text: 'Πρόγραμμα'),
            Tab(text: 'Ημέρα'),
            Tab(text: 'Στόχοι'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.lime))
          : _error != null
              ? Center(child: Text(_error!))
              : TabBarView(
                  controller: _tabs,
                  children: [
                    _measurementsTab(),
                    _planTab(),
                    _dayTab(),
                    _goalsTab(),
                  ],
                ),
    );
  }

  Widget _card(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        ...children,
      ]),
    );
  }

  Widget _num(TextEditingController c, String label) {
    return TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label),
    );
  }

  Widget _measurementsTab() {
    const times = {'morning': 'Πρωί', 'noon': 'Μεσημέρι', 'afternoon': 'Απόγευμα', 'evening': 'Βράδυ'};
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        _card('Νέα μέτρηση επίσκεψης', [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Ημερομηνία'),
            subtitle: Text(_measuredOn),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.tryParse(_measuredOn) ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 1)),
              );
              if (picked != null) setState(() => _measuredOn = picked.toIso8601String().substring(0, 10));
            },
          ),
          DropdownButtonFormField<String>(
            value: _timeOfDay,
            decoration: const InputDecoration(labelText: 'Στιγμή ημέρας'),
            items: times.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
            onChanged: (v) => setState(() => _timeOfDay = v ?? 'morning'),
          ),
          const SizedBox(height: 8),
          const Text('Βασικές μετρήσεις', style: TextStyle(fontWeight: FontWeight.w700)),
          _num(_weight, 'Βάρος kg'),
          _num(_height, 'Ύψος cm'),
          _num(_fat, 'Λίπος %'),
          _num(_bmi, 'BMI'),
          const SizedBox(height: 8),
          const Text('Σύνθεση σώματος', style: TextStyle(fontWeight: FontWeight.w700)),
          _num(_muscle, 'Μυϊκή μάζα kg'),
          _num(_fatMass, 'Λιπώδης μάζα kg'),
          _num(_visceral, 'Σπλαχνικό λίπος'),
          TextField(controller: _notes, decoration: const InputDecoration(labelText: 'Σημειώσεις', hintText: 'π.χ. Μετά από InBody')),
          const SizedBox(height: 10),
          FilledButton(onPressed: _saveMeasurement, child: const Text('Καταχώρηση μέτρησης')),
        ]),
        _card('Ιστορικό επισκέψεων', [
          if (_measurements.isEmpty) const Text('Δεν υπάρχουν μετρήσεις.'),
          ..._measurements.map((m) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${m['measured_on'] ?? ''} · ${times[m['time_of_day']] ?? m['time_of_day'] ?? ''}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
              Text([
                if (m['weight_kg'] != null) '${m['weight_kg']} kg',
                if (m['body_fat_pct'] != null) 'λίπος ${m['body_fat_pct']}%',
                if (m['muscle_mass_kg'] != null) 'μυς ${m['muscle_mass_kg']} kg',
                if (m['bmi'] != null) 'BMI ${m['bmi']}',
              ].join(' · ')),
              if ((m['notes']?.toString() ?? '').isNotEmpty)
                Text(m['notes'].toString(), style: const TextStyle(color: AppColors.textSecondary)),
            ]),
          )),
        ]),
      ],
    );
  }

  Widget _planTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Text('Ισχύει από $_effectiveFrom', style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        const Text('Το πρόγραμμα επαναλαμβάνεται κάθε εβδομάδα μέχρι νέα έκδοση.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final v in _versions)
            ActionChip(
              label: Text(v['effective_from']?.toString() ?? 'έκδοση'),
              onPressed: () async {
                final date = v['effective_from']?.toString();
                if (date == null) return;
                final plan = await context.read<AuthService>().api.fetchNutritionMealPlanAdmin(widget.userId, date: date);
                if (mounted) setState(() => _applyPlan(plan));
              },
            ),
        ]),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (picked == null) return;
            setState(() => _effectiveFrom = picked.toIso8601String().substring(0, 10));
            _toast('Νέα έκδοση από $_effectiveFrom. Αποθήκευσε για να ισχύσει.');
          },
          child: const Text('Νέα έκδοση'),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (var i = 1; i <= 7; i++)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(_days[i - 1]),
                  selected: _day == i,
                  onSelected: (_) => setState(() => _day = i),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 12),
        for (final meal in _meals) ...[
          Text(meal.$2, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          ...(_slots[_key(_day, meal.$1)] ?? const <_MealOption>[]).map((option) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(option.title.isEmpty ? 'Χωρίς τίτλο' : option.title),
            subtitle: Text([
              if (option.notes.isNotEmpty) option.notes,
              ...option.portions.where((p) => p.ingredient.isNotEmpty).map((p) => '${p.ingredient} ${p.amount} ${p.unit}'),
            ].join('\n')),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => setState(() => _slots[_key(_day, meal.$1)]?.remove(option)),
            ),
            onTap: () => _editOption(_day, meal.$1, option),
          )),
          TextButton.icon(
            onPressed: () => _editOption(_day, meal.$1, null),
            icon: const Icon(Icons.add),
            label: const Text('Γεύμα'),
          ),
          const Divider(),
        ],
        TextField(controller: _planNotes, decoration: const InputDecoration(labelText: 'Σημειώσεις προγράμματος'), maxLines: 2),
        const SizedBox(height: 10),
        FilledButton(onPressed: _savePlan, child: const Text('Αποθήκευση προγράμματος')),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton(onPressed: _shopping, child: const Text('Λίστα αγορών')),
          OutlinedButton(onPressed: _saveAsTemplate, child: const Text('Αποθήκευση ως πρότυπο')),
          for (final t in _templates)
            ActionChip(
              label: Text('Πρότυπο: ${t['name'] ?? ''}'),
              onPressed: () => _applyTemplate(t['id'].toString()),
            ),
        ]),
      ],
    );
  }

  Widget _dayTab() {
    final planned = ((_dayDetail['planned_slots'] as List?) ?? []).cast<Map<String, dynamic>>();
    final logs = ((_dayDetail['food_logs'] as List?) ?? []).cast<Map<String, dynamic>>();
    final label = '${_logDate.day}/${_logDate.month}/${_logDate.year}';
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Row(children: [
          IconButton(onPressed: () => _loadDay(_logDate.subtract(const Duration(days: 1))), icon: const Icon(Icons.chevron_left)),
          Expanded(child: Text(label, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800))),
          IconButton(onPressed: () => _loadDay(_logDate.add(const Duration(days: 1))), icon: const Icon(Icons.chevron_right)),
        ]),
        TextButton(onPressed: () => _loadDay(DateTime.now()), child: const Text('Σήμερα')),
        _card('Πρόγραμμα', [
          if (planned.isEmpty) const Text('Δεν υπάρχει πρόγραμμα για αυτή την ημέρα.'),
          ...planned.map((slot) {
            final options = ((slot['options'] as List?) ?? []).cast<Map<String, dynamic>>();
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(slot['meal_type_label']?.toString() ?? slot['meal_type']?.toString() ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
                ...options.map((o) => Text(o['title']?.toString() ?? '')),
              ]),
            );
          }),
        ]),
        _card('Καταγραφή', [
          if (logs.isEmpty) const Text('Δεν έχει καταγράψει γεύματα αυτή την ημέρα.'),
          ...logs.map((log) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('${log['meal_type_label'] ?? log['meal_type'] ?? ''} · ${log['description'] ?? ''}'),
          )),
        ]),
      ],
    );
  }

  Widget _goalsTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        _card('Στόχοι ασκούμενου', [
          _num(_targetWeight, 'Στόχος βάρους kg'),
          _num(_targetFat, 'Στόχος λίπους %'),
          _num(_goalHeight, 'Ύψος cm'),
          const SizedBox(height: 10),
          FilledButton(onPressed: _saveGoals, child: const Text('Αποθήκευση στόχων')),
        ]),
      ],
    );
  }
}

class _MealEditorSheet extends StatefulWidget {
  const _MealEditorSheet({required this.option});
  final _MealOption option;

  @override
  State<_MealEditorSheet> createState() => _MealEditorSheetState();
}

class _MealEditorSheetState extends State<_MealEditorSheet> {
  late final TextEditingController _title;
  late final TextEditingController _notes;
  late final List<_Portion> _portions;
  final List<TextEditingController> _ingredients = [];
  final List<TextEditingController> _amounts = [];

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.option.title);
    _notes = TextEditingController(text: widget.option.notes);
    _portions = widget.option.portions
        .map((p) => _Portion(ingredient: p.ingredient, amount: p.amount, unit: p.unit))
        .toList();
    if (_portions.isEmpty) _portions.add(_Portion());
    for (final p in _portions) {
      _ingredients.add(TextEditingController(text: p.ingredient));
      _amounts.add(TextEditingController(text: p.amount));
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    for (final c in _ingredients) {
      c.dispose();
    }
    for (final c in _amounts) {
      c.dispose();
    }
    super.dispose();
  }

  void _addPortion() {
    setState(() {
      _portions.add(_Portion());
      _ingredients.add(TextEditingController());
      _amounts.add(TextEditingController());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Γεύμα', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            TextField(controller: _title, decoration: const InputDecoration(labelText: 'Τίτλος')),
            TextField(controller: _notes, decoration: const InputDecoration(labelText: 'Σημειώσεις')),
            const SizedBox(height: 8),
            const Text('Υλικά', style: TextStyle(fontWeight: FontWeight.w700)),
            for (var i = 0; i < _portions.length; i++)
              Row(children: [
                Expanded(flex: 3, child: TextField(
                  controller: _ingredients[i],
                  decoration: const InputDecoration(labelText: 'Υλικό'),
                )),
                const SizedBox(width: 8),
                Expanded(child: TextField(
                  controller: _amounts[i],
                  decoration: const InputDecoration(labelText: 'Ποσ.'),
                  keyboardType: TextInputType.number,
                )),
                DropdownButton<String>(
                  value: _units.contains(_portions[i].unit) ? _portions[i].unit : 'g',
                  items: _units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                  onChanged: (v) => setState(() => _portions[i].unit = v ?? 'g'),
                ),
              ]),
            TextButton(onPressed: _addPortion, child: const Text('Υλικό')),
            FilledButton(
              onPressed: () {
                final portions = <_Portion>[];
                for (var i = 0; i < _portions.length; i++) {
                  portions.add(_Portion(
                    ingredient: _ingredients[i].text,
                    amount: _amounts[i].text,
                    unit: _portions[i].unit,
                  ));
                }
                Navigator.pop(context, _MealOption(
                  title: _title.text.trim(),
                  notes: _notes.text.trim(),
                  portions: portions,
                ));
              },
              child: const Text('Εντάξει'),
            ),
          ],
        ),
      ),
    );
  }
}
