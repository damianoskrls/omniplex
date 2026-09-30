import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';

class NutritionistClientsScreen extends StatefulWidget {
  const NutritionistClientsScreen({super.key});

  @override
  State<NutritionistClientsScreen> createState() => _NutritionistClientsScreenState();
}

class _NutritionistClientsScreenState extends State<NutritionistClientsScreen> {
  List<Map<String, dynamic>> _clients = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final rows = await context.read<AuthService>().api.fetchNutritionClients();
      if (mounted) setState(() => _clients = rows);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.lime));
    if (_error != null) return Center(child: Text(_error!));
    if (_clients.isEmpty) {
      return const Center(child: Text('Δεν υπάρχουν πελάτες διατροφής.', style: TextStyle(color: AppColors.textSecondary)));
    }
    return RefreshIndicator(
      color: AppColors.lime,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: _clients.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final c = _clients[i];
          return ListTile(
            tileColor: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: Text(c['full_name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(c['plan_name']?.toString() ?? 'Πακέτο διατροφής'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => NutritionistClientScreen(
                userId: c['id'].toString(),
                name: c['full_name']?.toString() ?? '',
              ),
            )),
          );
        },
      ),
    );
  }
}

class NutritionistBookingsScreen extends StatefulWidget {
  const NutritionistBookingsScreen({super.key});

  @override
  State<NutritionistBookingsScreen> createState() => _NutritionistBookingsScreenState();
}

class _NutritionistBookingsScreenState extends State<NutritionistBookingsScreen> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final rows = await context.read<AuthService>().api.fetchNutritionBookings();
      if (mounted) setState(() => _rows = rows);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.lime));
    if (_error != null) return Center(child: Text(_error!));
    if (_rows.isEmpty) {
      return const Center(child: Text('Δεν υπάρχουν ραντεβού διατροφής.', style: TextStyle(color: AppColors.textSecondary)));
    }
    return RefreshIndicator(
      color: AppColors.lime,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: _rows.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final b = _rows[i];
          return ListTile(
            tileColor: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: Text(b['client_name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('${b['starts_at'] ?? ''} · ${b['status'] ?? ''}'),
          );
        },
      ),
    );
  }
}

class NutritionistTemplatesScreen extends StatefulWidget {
  const NutritionistTemplatesScreen({super.key});

  @override
  State<NutritionistTemplatesScreen> createState() => _NutritionistTemplatesScreenState();
}

class _NutritionistTemplatesScreenState extends State<NutritionistTemplatesScreen> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final rows = await context.read<AuthService>().api.fetchNutritionTemplates();
      if (mounted) setState(() => _rows = rows);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.lime));
    if (_error != null) return Center(child: Text(_error!));
    if (_rows.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Δεν υπάρχουν έτοιμα προγράμματα. Τα αποθηκευμένα πρότυπα του web φαίνονται εδώ.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }
    return RefreshIndicator(
      color: AppColors.lime,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: _rows.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final t = _rows[i];
          return ListTile(
            tileColor: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: Text(t['name']?.toString() ?? 'Πρόγραμμα', style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('Έτοιμο / αποθηκευμένο πρόγραμμα'),
          );
        },
      ),
    );
  }
}

class NutritionistClientScreen extends StatefulWidget {
  const NutritionistClientScreen({super.key, required this.userId, required this.name});
  final String userId;
  final String name;

  @override
  State<NutritionistClientScreen> createState() => _NutritionistClientScreenState();
}

class _NutritionistClientScreenState extends State<NutritionistClientScreen> {
  Map<String, dynamic> _goals = {};
  Map<String, dynamic> _plan = {};
  List<Map<String, dynamic>> _measurements = [];
  List<Map<String, dynamic>> _logs = [];
  List<Map<String, dynamic>> _templates = [];
  bool _loading = true;
  String? _error;
  final _targetWeight = TextEditingController();
  final _targetFat = TextEditingController();
  final _height = TextEditingController();
  final _visitWeight = TextEditingController();
  final _visitFat = TextEditingController();
  final _visitNotes = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _targetWeight.dispose();
    _targetFat.dispose();
    _height.dispose();
    _visitWeight.dispose();
    _visitFat.dispose();
    _visitNotes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = context.read<AuthService>().api;
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final results = await Future.wait([
        api.fetchNutritionGoalsAdmin(widget.userId),
        api.fetchNutritionMealPlan(widget.userId),
        api.fetchNutritionMeasurementsAdmin(widget.userId),
        api.fetchNutritionClientDay(widget.userId, today),
        api.fetchNutritionTemplates(),
      ]);
      if (!mounted) return;
      final goals = results[0] as Map<String, dynamic>;
      final measurements = results[2] as Map<String, dynamic>;
      final day = results[3] as Map<String, dynamic>;
      setState(() {
        _goals = goals;
        _plan = results[1] as Map<String, dynamic>;
        _measurements = ((measurements['measurements'] as List?) ?? []).cast<Map<String, dynamic>>();
        _logs = ((day['food_logs'] as List?) ?? []).cast<Map<String, dynamic>>();
        _templates = results[4] as List<Map<String, dynamic>>;
        _targetWeight.text = goals['target_weight_kg']?.toString() ?? '';
        _targetFat.text = goals['target_body_fat_pct']?.toString() ?? '';
        _height.text = goals['height_cm']?.toString() ?? '';
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveGoals() async {
    try {
      await context.read<AuthService>().api.saveNutritionGoalsAdmin(widget.userId, {
        'target_weight_kg': _targetWeight.text.trim(),
        'target_body_fat_pct': _targetFat.text.trim(),
        'height_cm': _height.text.trim(),
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Οι στόχοι αποθηκεύτηκαν')));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _saveVisit() async {
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      await context.read<AuthService>().api.addNutritionMeasurement(widget.userId, {
        'measured_on': today,
        'time_of_day': 'morning',
        'weight_kg': _visitWeight.text.trim(),
        'body_fat_pct': _visitFat.text.trim(),
        'notes': _visitNotes.text.trim(),
      });
      _visitWeight.clear();
      _visitFat.clear();
      _visitNotes.clear();
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Η μέτρηση καταχωρήθηκε')));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _applyTemplate(String id) async {
    try {
      await context.read<AuthService>().api.applyNutritionTemplate(widget.userId, id);
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Το πρόγραμμα εφαρμόστηκε')));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final meals = ((_plan['meals'] as List?) ?? []).cast<Map<String, dynamic>>();
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(backgroundColor: AppColors.bg, title: Text(widget.name)),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.lime))
          : _error != null
              ? Center(child: Text(_error!))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    _section('Στόχοι ασκουμένου', [
                      Text('Τρέχον βάρος: ${_goals['weight_kg'] ?? '—'} kg · λίπος: ${_goals['body_fat_pct'] ?? '—'}%'),
                      const SizedBox(height: 8),
                      TextField(controller: _targetWeight, decoration: const InputDecoration(labelText: 'Στόχος βάρους (kg)'), keyboardType: TextInputType.number),
                      TextField(controller: _targetFat, decoration: const InputDecoration(labelText: 'Στόχος λίπους (%)'), keyboardType: TextInputType.number),
                      TextField(controller: _height, decoration: const InputDecoration(labelText: 'Ύψος (cm)'), keyboardType: TextInputType.number),
                      const SizedBox(height: 8),
                      FilledButton(onPressed: _saveGoals, child: const Text('Αποθήκευση στόχων')),
                    ]),
                    _section('Νέα μέτρηση επίσκεψης', [
                      TextField(controller: _visitWeight, decoration: const InputDecoration(labelText: 'Βάρος (kg)'), keyboardType: TextInputType.number),
                      TextField(controller: _visitFat, decoration: const InputDecoration(labelText: 'Λίπος (%)'), keyboardType: TextInputType.number),
                      TextField(controller: _visitNotes, decoration: const InputDecoration(labelText: 'Σημειώσεις')),
                      const SizedBox(height: 8),
                      FilledButton(onPressed: _saveVisit, child: const Text('Καταχώριση μέτρησης')),
                    ]),
                    _section('Μετρήσεις σώματος', [
                      if (_measurements.isEmpty) const Text('Δεν υπάρχουν μετρήσεις.'),
                      ..._measurements.take(8).map((m) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text('${m['measured_on'] ?? ''} · ${m['weight_kg'] ?? '—'} kg · λίπος ${m['body_fat_pct'] ?? '—'}%'),
                      )),
                    ]),
                    _section('Ημερολόγιο διατροφής (σήμερα)', [
                      if (_logs.isEmpty) const Text('Δεν έχει καταγραφές σήμερα.'),
                      ..._logs.map((log) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text('${log['meal_type'] ?? ''} · ${log['description'] ?? log['title'] ?? ''}'),
                      )),
                    ]),
                    _section('Επαναλαμβανόμενο εβδομαδιαίο πρόγραμμα', [
                      Text(_plan['effective_from'] != null ? 'Ισχύει από ${_plan['effective_from']}' : 'Δεν υπάρχει ενεργό πρόγραμμα.'),
                      const SizedBox(height: 8),
                      if (meals.isEmpty) const Text('Δεν έχουν περαστεί γεύματα.'),
                      ...meals.take(20).map((meal) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text('Ημ. ${meal['day_of_week'] ?? ''} · ${meal['meal_type'] ?? ''} · ${meal['description'] ?? meal['title'] ?? ''}'),
                      )),
                    ]),
                    _section('Έτοιμα και αποθηκευμένα προγράμματα', [
                      if (_templates.isEmpty) const Text('Δεν υπάρχουν πρότυπα.'),
                      ..._templates.map((t) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(t['name']?.toString() ?? 'Πρόγραμμα'),
                        trailing: TextButton(
                          onPressed: () => _applyTemplate(t['id'].toString()),
                          child: const Text('Εφαρμογή'),
                        ),
                      )),
                    ]),
                  ],
                ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}
