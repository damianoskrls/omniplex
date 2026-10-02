import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/ui_kit.dart';
import '../l10n/tr.dart';


class StaffTrialsScreen extends StatefulWidget {
  const StaffTrialsScreen({super.key});

  @override
  State<StaffTrialsScreen> createState() => _StaffTrialsScreenState();
}

class _StaffTrialsScreenState extends State<StaffTrialsScreen> {
  List<Map<String, dynamic>> _trials = [];
  Map<String, dynamic> _stats = const {};
  bool _loading = true;
  String? _error;
  int _filter = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final api = context.read<AuthService>().api;
    try {
      final results = await Future.wait([
        api.fetchStaffTrials(),
        api.fetchStaffTrialSummary(),
      ]);
      if (!mounted) return;
      setState(() {
        _trials = (results[0] as List).cast<Map<String, dynamic>>();
        _stats = results[1] as Map<String, dynamic>;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = tr('Δεν φορτώθηκαν τα δοκιμαστικά'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int _n(dynamic value) => value is int ? value : int.tryParse('$value') ?? 0;

  bool _flag(dynamic value) => value == true || value == 1 || value == '1';

  bool _mine(Map<String, dynamic> trial, String? staffId) {
    final assigned = trial['staff_id'] as String?;
    return assigned != null && staffId != null && assigned == staffId;
  }

  List<Map<String, dynamic>> _visible(String? staffId) {
    final now = DateTime.now();
    return _trials.where((trial) {
      if (_filter == 1) return _mine(trial, staffId);
      if (_filter == 2) return true;
      if (trial['staff_id'] == null) return true;
      if (!_mine(trial, staffId)) return false;
      final start = DateTime.tryParse('${trial['starts_at']}')?.toLocal();
      return start == null || !start.isBefore(now);
    }).toList();
  }

  Future<void> _claim(Map<String, dynamic> trial) async {
    final name = trial['user_name'] as String? ?? tr('τον πελάτη');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Θα το κάνω εγώ')),
        content: Text(tr('Αναλαμβάνεις το δοκιμαστικό του $name;')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Άκυρο'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Ναι'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<AuthService>().api.claimTrial(trial['id'] as String);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Το δοκιμαστικό είναι δικό σου'))),
      );
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(e.message))));
    }
  }

  Future<void> _feedback(Map<String, dynamic> trial) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (_) => _FeedbackSheet(trial: trial),
    );
    if (saved == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final staffId = context.read<AuthService>().staffId;
    final rows = _visible(staffId);
    return ColoredBox(
      color: AppColors.bg,
      child: RefreshIndicator(
        color: context.tenantPrimary,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(tr('Δοκιμαστικά'),
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(tr('Ανάλαβε όσα είναι ελεύθερα και γράψε αποτέλεσμα μετά.'),
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 14),
            Row(
              children: [
                _Stat(tr('Ανοιχτά'), _n(_stats['open'])),
                const SizedBox(width: 8),
                _Stat(tr('Έκανα'), _n(_stats['done'])),
                const SizedBox(width: 8),
                _Stat(tr('Έγιναν πελάτες'), _n(_stats['became_members'])),
                const SizedBox(width: 8),
                _Stat(tr('Ικανοποιημένοι'), _n(_stats['satisfied'])),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              children: [
                _chip(0, tr('Ανοιχτά')),
                _chip(1, tr('Δικά μου')),
                _chip(2, tr('Όλα')),
              ],
            ),
            const SizedBox(height: 14),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Text(tr(_error!), style: const TextStyle(color: AppColors.textSecondary))
            else if (rows.isEmpty)
              Padding(
                padding: EdgeInsets.only(top: 32),
                child: Text(tr('Δεν υπάρχουν δοκιμαστικά σε αυτή την προβολή.'),
                    style: TextStyle(color: AppColors.textSecondary)),
              )
            else
              ...rows.map((trial) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _TrialTile(
                      trial: trial,
                      mine: _mine(trial, staffId),
                      became: _flag(trial['trial_became_member']),
                      considering: _flag(trial['trial_considering']),
                      satisfied: trial['trial_satisfied'],
                      onClaim: () => _claim(trial),
                      onFeedback: () => _feedback(trial),
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _chip(int index, String label) {
    final on = _filter == index;
    final color = context.tenantPrimary;
    return ChoiceChip(
      label: Text(label),
      selected: on,
      onSelected: (_) => setState(() => _filter = index),
      selectedColor: color.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: on ? color : AppColors.textSecondary,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Text(tr('$value'),
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800, color: context.tenantPrimary)),
            const SizedBox(height: 2),
            Text(tr(label),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, height: 1.2)),
          ],
        ),
      ),
    );
  }
}

class _TrialTile extends StatelessWidget {
  const _TrialTile({
    required this.trial,
    required this.mine,
    required this.became,
    required this.considering,
    required this.satisfied,
    required this.onClaim,
    required this.onFeedback,
  });

  final Map<String, dynamic> trial;
  final bool mine;
  final bool became;
  final bool considering;
  final dynamic satisfied;
  final VoidCallback onClaim;
  final VoidCallback onFeedback;

  String _when(String? iso) {
    if (iso == null) return '';
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return iso;
    return DateFormat('EEE d MMM, HH:mm', 'el_GR').format(parsed.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final name = (trial['user_name'] as String?)?.trim();
    final phone = trial['user_phone'] as String?;
    final service = trial['service_name'] as String?;
    final place = trial['location_name'] as String?;
    final notes = trial['notes'] as String?;
    final unassigned = trial['staff_id'] == null;
    final other = trial['staff_name'] as String?;
    final color = context.tenantPrimary;

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr(name == null || name.isEmpty ? 'Χωρίς όνομα' : name),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 4),
          Text(
            tr([service, place, _when(trial['starts_at'] as String?)]
                .whereType<String>()
                .where((part) => part.isNotEmpty)
                .join(' · ')),
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          if (phone != null && phone.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(tr(phone), style: const TextStyle(fontSize: 13)),
          ],
          const SizedBox(height: 8),
          Text(
            tr(unassigned
                ? 'Χωρίς γυμναστή'
                : mine
                    ? 'Το έχεις αναλάβει εσύ'
                    : tr('Το έχει ο ${other ?? 'άλλος'}')),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: unassigned ? AppColors.orange : (mine ? color : AppColors.textSecondary),
            ),
          ),
          if (became || considering || satisfied != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (satisfied == 1 || satisfied == true)
                  _Tag(tr('Ικανοποιήθηκε'), Color(0xFF16A34A)),
                if (satisfied == 0 || satisfied == false)
                  _Tag(tr('Δεν ικανοποιήθηκε'), Color(0xFFDC2626)),
                if (became) _Tag(tr('Έγινε πελάτης'), Color(0xFF16A34A)),
                if (considering && !became) _Tag(tr('Το σκέφτεται'), Color(0xFFD97706)),
              ],
            ),
          ],
          if (notes != null && notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(tr(notes), style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ],
          if (unassigned || mine) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (unassigned)
                  Expanded(
                    child: FilledButton(
                      onPressed: onClaim,
                      style: FilledButton.styleFrom(backgroundColor: color),
                      child: Text(tr('Θα το κάνω εγώ'), style: TextStyle(color: AppColors.onFill(color))),
                    ),
                  ),
                if (mine)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onFeedback,
                      child: Text(tr('Αποτέλεσμα')),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(tr(label), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _FeedbackSheet extends StatefulWidget {
  const _FeedbackSheet({required this.trial});
  final Map<String, dynamic> trial;

  @override
  State<_FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<_FeedbackSheet> {
  late final TextEditingController _notes;
  bool? _satisfied;
  String _outcome = 'no';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final trial = widget.trial;
    _notes = TextEditingController(text: trial['notes'] as String? ?? '');
    final sat = trial['trial_satisfied'];
    if (sat == 1 || sat == true) _satisfied = true;
    if (sat == 0 || sat == false) _satisfied = false;
    if (trial['trial_became_member'] == 1 || trial['trial_became_member'] == true) {
      _outcome = 'member';
    } else if (trial['trial_considering'] == 1 || trial['trial_considering'] == true) {
      _outcome = 'considering';
    }
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await context.read<AuthService>().api.saveTrialFeedback(
            widget.trial['id'] as String,
            notes: _notes.text.trim(),
            satisfied: _satisfied,
            becameMember: _outcome == 'member',
            considering: _outcome == 'considering',
          );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(e.message))));
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.trial['user_name'] as String? ?? '';
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tr('Αποτέλεσμα δοκιμαστικού'),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            if (name.isNotEmpty)
              Text(tr(name), style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            Text(tr('Έμεινε ικανοποιημένος;'), style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: Text(tr('Ναι')),
                  selected: _satisfied == true,
                  onSelected: (_) => setState(() => _satisfied = true),
                ),
                ChoiceChip(
                  label: Text(tr('Όχι')),
                  selected: _satisfied == false,
                  onSelected: (_) => setState(() => _satisfied = false),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(tr('Θα γίνει πελάτης;'), style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: Text(tr('Ναι')),
                  selected: _outcome == 'member',
                  onSelected: (_) => setState(() => _outcome = 'member'),
                ),
                ChoiceChip(
                  label: Text(tr('Το σκέφτεται')),
                  selected: _outcome == 'considering',
                  onSelected: (_) => setState(() => _outcome = 'considering'),
                ),
                ChoiceChip(
                  label: Text(tr('Όχι')),
                  selected: _outcome == 'no',
                  onSelected: (_) => setState(() => _outcome = 'no'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notes,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: tr('Σχόλια'),
                hintText: tr('Τι είδε, τι του άρεσε, τι τον κράτησε πίσω…'),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(tr(_saving ? 'Αποθήκευση…' : tr('Αποθήκευση'))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
