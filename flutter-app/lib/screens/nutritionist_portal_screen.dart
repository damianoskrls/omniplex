import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import 'nutritionist_client_screen.dart';

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

  String _statusLabel(String? status) {
    switch (status) {
      case 'pending': return 'Αναμονή';
      case 'confirmed': return 'Επιβεβαιωμένη';
      case 'cancelled': return 'Ακυρωμένη';
      case 'completed': return 'Ολοκληρωμένη';
      case 'no_show': return 'Δεν προσήλθε';
      default: return status ?? '';
    }
  }

  String _when(dynamic value) {
    final raw = value?.toString() ?? '';
    if (raw.length < 16) return raw;
    return raw.substring(0, 16).replaceFirst('T', ' ');
  }

  Future<void> _act(String id, String value) async {
    final api = context.read<AuthService>().api;
    try {
      if (value == 'delete') {
        await api.deleteNutritionBooking(id);
      } else {
        await api.updateNutritionBookingStatus(id, value);
      }
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _create() async {
    final api = context.read<AuthService>().api;
    try {
      final clients = await api.fetchBookableNutritionClients();
      if (!mounted) return;
      if (clients.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Κανένας πελάτης δεν έχει διαθέσιμες επισκέψεις.')),
        );
        return;
      }
      String? userId;
      var date = DateTime.now();
      String? time;
      final done = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setSheet) => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Νέα κράτηση', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: userId,
                  decoration: const InputDecoration(labelText: 'Πελάτης'),
                  items: clients.map((c) => DropdownMenuItem(
                    value: c['id'].toString(),
                    child: Text(c['full_name']?.toString() ?? ''),
                  )).toList(),
                  onChanged: (v) => setSheet(() => userId = v),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${date.day}/${date.month}/${date.year}'),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: date,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 60)),
                    );
                    if (picked != null) setSheet(() => date = picked);
                  },
                ),
                TextButton(
                  onPressed: () async {
                    final slots = await api.fetchNutritionBookingSlots(date.toIso8601String().substring(0, 10));
                    if (!ctx.mounted) return;
                    final picked = await showModalBottomSheet<String>(
                      context: ctx,
                      builder: (sheetCtx) => ListView(
                        children: [
                          if (slots.isEmpty) const ListTile(title: Text('Δεν υπάρχουν ελεύθερες ώρες')),
                          ...slots.where((s) => (s['available_count'] as num?) == null || (s['available_count'] as num) > 0).map((s) {
                            final t = (s['time'] ?? '').toString();
                            final label = t.length >= 5 ? t.substring(0, 5) : t;
                            return ListTile(title: Text(label), onTap: () => Navigator.pop(sheetCtx, label));
                          }),
                        ],
                      ),
                    );
                    if (picked != null) setSheet(() => time = picked);
                  },
                  child: Text(time == null ? 'Επίλεξε ώρα' : 'Ώρα $time'),
                ),
                FilledButton(
                  onPressed: userId == null || time == null ? null : () => Navigator.pop(ctx, true),
                  child: const Text('Κράτηση'),
                ),
              ],
            ),
          ),
        ),
      );
      if (done == true && userId != null && time != null) {
        await api.createNutritionBooking(
          userId: userId!,
          date: date.toIso8601String().substring(0, 10),
          time: time!,
        );
        await _load();
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.lime));
    if (_error != null) return Center(child: Text(_error!));
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('Νέα κράτηση'),
      ),
      body: _rows.isEmpty
          ? const Center(child: Text('Δεν υπάρχουν ραντεβού διατροφής.', style: TextStyle(color: AppColors.textSecondary)))
          : RefreshIndicator(
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
            subtitle: Text('${_when(b['starts_at'])} · ${_statusLabel(b['status']?.toString())}'),
            trailing: PopupMenuButton<String>(
              onSelected: (value) => _act(b['id'].toString(), value),
              itemBuilder: (_) => [
                if (b['status'] == 'pending') const PopupMenuItem(value: 'confirmed', child: Text('Επιβεβαίωση')),
                if (b['status'] == 'pending') const PopupMenuItem(value: 'cancelled', child: Text('Ακύρωση')),
                if (b['status'] == 'confirmed') const PopupMenuItem(value: 'completed', child: Text('Ολοκληρώθηκε')),
                if (b['status'] == 'confirmed') const PopupMenuItem(value: 'no_show', child: Text('Δεν προσήλθε')),
                const PopupMenuItem(value: 'delete', child: Text('Διαγραφή')),
              ],
            ),
          );
        },
      ),
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


class NutritionistScheduleScreen extends StatefulWidget {
  const NutritionistScheduleScreen({super.key});

  @override
  State<NutritionistScheduleScreen> createState() => _NutritionistScheduleScreenState();
}

class _NutritionistScheduleScreenState extends State<NutritionistScheduleScreen> {
  static const _days = ['Δευ', 'Τρί', 'Τετ', 'Πέμ', 'Παρ', 'Σάβ', 'Κυρ'];
  static const _times = ['09:00', '10:00', '11:00', '12:00', '13:00', '17:00', '18:00', '19:00', '20:00'];
  List<Map<String, dynamic>> _rows = [];
  final Set<int> _daysPicked = {};
  final Set<String> _timesPicked = {};
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
      final rows = await context.read<AuthService>().api.fetchNutritionSchedules();
      if (mounted) setState(() => _rows = rows);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add() async {
    if (_daysPicked.isEmpty || _timesPicked.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Επίλεξε ημέρες και ώρες')));
      return;
    }
    try {
      await context.read<AuthService>().api.addNutritionSchedules(
        weekdays: _daysPicked.toList(),
        startTimes: _timesPicked.toList(),
      );
      setState(() { _daysPicked.clear(); _timesPicked.clear(); });
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.lime));
    if (_error != null) return Center(child: Text(_error!));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const Text('Ώρες συνεδριών', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 8),
        Wrap(spacing: 6, children: [
          for (var i = 0; i < _days.length; i++)
            FilterChip(
              label: Text(_days[i]),
              selected: _daysPicked.contains(i),
              onSelected: (on) => setState(() => on ? _daysPicked.add(i) : _daysPicked.remove(i)),
            ),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 6, children: [
          for (final t in _times)
            FilterChip(
              label: Text(t),
              selected: _timesPicked.contains(t),
              onSelected: (on) => setState(() => on ? _timesPicked.add(t) : _timesPicked.remove(t)),
            ),
        ]),
        const SizedBox(height: 10),
        FilledButton(onPressed: _add, child: const Text('Προσθήκη ωρών')),
        const SizedBox(height: 16),
        if (_rows.isEmpty) const Text('Δεν έχεις ορίσει ώρες ακόμα.', style: TextStyle(color: AppColors.textSecondary)),
        ..._rows.map((s) {
          final day = (s['weekday'] as num?)?.toInt() ?? 0;
          final time = (s['start_time']?.toString() ?? '').length >= 5
              ? s['start_time'].toString().substring(0, 5)
              : s['start_time']?.toString() ?? '';
          return ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('${day >= 0 && day < 7 ? _days[day] : day} · $time'),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                await context.read<AuthService>().api.deleteNutritionSchedule(s['id'].toString());
                await _load();
              },
            ),
          );
        }),
      ],
    );
  }
}
