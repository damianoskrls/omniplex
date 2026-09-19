import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../l10n/app_strings.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/language_service.dart';
import '../theme/app_colors.dart';
import '../widgets/ui_kit.dart';

class StaffLeavesScreen extends StatefulWidget {
  const StaffLeavesScreen({super.key});

  @override
  State<StaffLeavesScreen> createState() => _StaffLeavesScreenState();
}

class _StaffLeavesScreenState extends State<StaffLeavesScreen> {
  List<Map<String, dynamic>> _leaves = [];
  int _annualDays = 20;
  int _usedDays   = 0;
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
      final api  = context.read<AuthService>().api;
      final data = await api.fetchStaffLeaves();
      setState(() {
        _leaves     = (data['leaves'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        _annualDays = (data['annual_leave_days'] as num?)?.toInt() ?? 20;
        _usedDays   = ((data['used_days'] ?? data['days_used']) as num?)?.toInt() ?? 0;
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(String leaveId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(AppStrings.of(context).staffLeavesCancelTitle),
        content: Text(AppStrings.of(context).staffLeavesCancelBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppStrings.of(context).cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.orange),
            child: Text(AppStrings.of(context).staffLeavesCancelBtn),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await context.read<AuthService>().api.deleteStaffLeave(leaveId);
      if (mounted) _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _showAddSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _AddLeaveSheet(onSaved: _load),
    );
  }

  String _formatRange(String? from, String? to) {
    if (from == null) return '';
    try {
      final fmt = DateFormat('d MMM yyyy', LanguageService.instance.isGreek ? 'el_GR' : 'en_US');
      final f = fmt.format(DateTime.parse(from));
      if (to == null || to == from) return f;
      return '$f – ${fmt.format(DateTime.parse(to))}';
    } catch (_) { return from; }
  }

  int _dayCount(String? from, String? to) {
    if (from == null) return 1;
    try {
      final f = DateTime.parse(from);
      final t = to != null ? DateTime.parse(to) : f;
      return t.difference(f).inDays + 1;
    } catch (_) { return 1; }
  }

  Color _statusColor(String? s) {
    switch (s) {
      case 'approved': return AppColors.lime;
      case 'rejected': return AppColors.orange;
      default:         return const Color(0xFFF59E0B);
    }
  }

  String _statusLabel(String? s, BuildContext context) {
    switch (s) {
      case 'approved': return AppStrings.of(context).staffLeavesStatusApproved;
      case 'rejected': return AppStrings.of(context).staffLeavesStatusRejected;
      default:         return AppStrings.of(context).staffLeavesStatusPending;
    }
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _annualDays - _usedDays;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.lime))
          : _error != null
              ? Center(child: Text(_error!))
              : Column(
                  children: [
                    // Balance banner
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48, height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.lime.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.beach_access_outlined, color: AppColors.lime, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(AppStrings.of(context).staffLeavesBalance,
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                Text(AppStrings.of(context).staffLeavesOf(remaining, _annualDays),
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(AppStrings.of(context).staffLeavesUsed,
                                  style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                              Text(AppStrings.of(context).staffLeavesDays(_usedDays),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.orange)),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Leaves list
                    Expanded(
                      child: _leaves.isEmpty
                          ? EmptyState(
                              icon: Icons.beach_access_outlined,
                              title: AppStrings.of(context).staffLeavesEmpty,
                              subtitle: AppStrings.of(context).staffLeavesEmptySub,
                            )
                          : RefreshIndicator(
                              onRefresh: _load,
                              color: AppColors.lime,
                              child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                                itemCount: _leaves.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 10),
                                itemBuilder: (_, i) {
                                  final leave   = _leaves[i];
                                  final days    = _dayCount(leave['date_from'] as String?, leave['date_to'] as String?);
                                  final status  = leave['status'] as String? ?? 'pending';
                                  final sColor  = _statusColor(status);
                                  final isPending = status == 'pending';
                                  return SurfaceCard(
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 48, height: 48,
                                          decoration: BoxDecoration(
                                            color: sColor.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text('$days', style: TextStyle(
                                                  fontWeight: FontWeight.w800, fontSize: 20,
                                                  color: sColor, height: 1)),
                                              Text(days == 1 ? 'μέρα' : 'μέρες',
                                                  style: TextStyle(fontSize: 9, color: sColor)),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _formatRange(leave['date_from'] as String?, leave['date_to'] as String?),
                                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                              ),
                                              if (leave['reason'] != null && (leave['reason'] as String).isNotEmpty)
                                                Text(leave['reason'] as String,
                                                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                                              const SizedBox(height: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: sColor.withValues(alpha: 0.12),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(_statusLabel(status, context),
                                                    style: TextStyle(
                                                        fontSize: 11, fontWeight: FontWeight.w700, color: sColor)),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (isPending)
                                          IconButton(
                                            onPressed: () => _delete(leave['id'] as String),
                                            icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 20),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            tooltip: AppStrings.of(context).staffLeavesCancelAction,
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddSheet,
        backgroundColor: AppColors.lime,
        foregroundColor: AppColors.bg,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _AddLeaveSheet extends StatefulWidget {
  const _AddLeaveSheet({required this.onSaved});
  final VoidCallback onSaved;

  @override
  State<_AddLeaveSheet> createState() => _AddLeaveSheetState();
}

class _AddLeaveSheetState extends State<_AddLeaveSheet> {
  DateTime? _from;
  DateTime? _to;
  final _reasonCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _from != null && _to != null
          ? DateTimeRange(start: _from!, end: _to!)
          : null,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(primary: AppColors.lime, surface: AppColors.surface),
        ),
        child: child!,
      ),
    );
    if (range != null && mounted) {
      setState(() { _from = range.start; _to = range.end; });
    }
  }

  Future<void> _save() async {
    if (_from == null) {
      setState(() => _error = AppStrings.of(context).staffLeavesEnterDate);
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final fmt = DateFormat('yyyy-MM-dd');
      await context.read<AuthService>().api.addStaffLeave(
        dateFrom: fmt.format(_from!),
        dateTo: fmt.format(_to ?? _from!),
        reason: _reasonCtrl.text.trim().isEmpty ? null : _reasonCtrl.text.trim(),
      );
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  String _rangeLabel(BuildContext context) {
    if (_from == null) return AppStrings.of(context).staffLeavesSelectDate;
    final fmt = DateFormat('d MMM yyyy', LanguageService.instance.isGreek ? 'el_GR' : 'en_US');
    final f = fmt.format(_from!);
    if (_to == null || _to == _from) return f;
    return '$f – ${fmt.format(_to!)}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppStrings.of(context).staffLeavesNewRequest,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 4),
          Text(AppStrings.of(context).staffLeavesNewRequestSub,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 20),

          // Date range picker
          GestureDetector(
            onTap: _pickRange,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.date_range_outlined, color: AppColors.textSecondary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(_rangeLabel(context),
                        style: TextStyle(
                          color: _from != null ? AppColors.textPrimary : AppColors.textSecondary,
                          fontWeight: _from != null ? FontWeight.w600 : FontWeight.w400,
                        )),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 18),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),
          TextField(
            controller: _reasonCtrl,
            decoration: InputDecoration(
              labelText: AppStrings.of(context).staffLeavesReason,
              prefixIcon: const Icon(Icons.notes_outlined, color: AppColors.textSecondary),
            ),
            textInputAction: TextInputAction.done,
          ),

          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.orange, fontSize: 13)),
          ],

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _save,
              child: _loading
                  ? const SizedBox(height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bg))
                  : Text(AppStrings.of(context).staffLeavesSend),
            ),
          ),
        ],
      ),
    );
  }
}
