import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/workout_health.dart';
import '../theme/app_colors.dart';
import 'ui_kit.dart';

class WorkoutHealthPanel extends StatelessWidget {
  const WorkoutHealthPanel({
    super.key,
    required this.loading,
    required this.permissionDenied,
    required this.unsupported,
    required this.candidates,
    required this.selected,
    required this.onSelect,
    required this.onSync,
    this.error,
  });

  final bool loading;
  final bool permissionDenied;
  final bool unsupported;
  final List<WorkoutHealthSummary> candidates;
  final WorkoutHealthSummary? selected;
  final ValueChanged<WorkoutHealthSummary?> onSelect;
  final VoidCallback onSync;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final timeFmt = DateFormat('HH:mm', 'el_GR');

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.watch_outlined, color: AppColors.lime, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Δεδομένα από ρολόι / Health',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton.icon(
                onPressed: loading ? null : onSync,
                icon: loading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync, size: 16),
                label: const Text('Συγχρονισμός'),
              ),
            ],
          ),
          Text(
            'Συνδέσου με Apple Health ή Health Connect (Zepp Life, Apple Watch κ.λπ.)',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          if (unsupported)
            Text(
              'Διαθέσιμο μόνο σε iPhone/Android',
              style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13),
            )
          else if (permissionDenied)
            Text(
              'Δεν δόθηκαν δικαιώματα Health. Ενεργοποίησέ τα από Ρυθμίσεις.',
              style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13),
            )
          else if (error != null)
            Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13))
          else if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (selected != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.lime.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.lime.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          selected!.activityLabel,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (selected!.isAutoMatch)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.lime.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: const Text(
                            'Auto-match',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${timeFmt.format(selected!.startedAt)} – ${timeFmt.format(selected!.endedAt)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    selected!.summaryLine,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            if (candidates.length > 1) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _openPicker(context, timeFmt),
                icon: const Icon(Icons.list_alt, size: 18),
                label: Text('Επιλογή άλλης προπόνησης (${candidates.length})'),
              ),
            ],
            TextButton(
              onPressed: () => onSelect(null),
              child: const Text('Χωρίς δεδομένα ρολογιού'),
            ),
          ] else if (candidates.isEmpty)
            Text(
              'Δεν βρέθηκε workout στο Health για αυτή την ώρα. Βεβαιώσου ότι το ρολόι συγχρονίζει με Health.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            )
          else
            OutlinedButton.icon(
              onPressed: () => _openPicker(context, timeFmt),
              icon: const Icon(Icons.list_alt, size: 18),
              label: Text('Επίλεξε προπόνηση (${candidates.length})'),
            ),
        ],
      ),
    );
  }

  Future<void> _openPicker(BuildContext context, DateFormat timeFmt) async {
    final picked = await showModalBottomSheet<WorkoutHealthSummary>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Προπόνηση από Health', style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 12),
              SizedBox(
                height: 320,
                child: ListView.separated(
                  itemCount: candidates.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final w = candidates[i];
                    final isSel = selected?.externalId == w.externalId;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        isSel ? Icons.check_circle : Icons.fitness_center_outlined,
                        color: isSel ? AppColors.lime : AppColors.textSecondary,
                      ),
                      title: Text(w.activityLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        '${timeFmt.format(w.startedAt)} – ${timeFmt.format(w.endedAt)}\n${w.summaryLine}',
                      ),
                      isThreeLine: true,
                      onTap: () => Navigator.pop(ctx, w),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) onSelect(picked);
  }
}
