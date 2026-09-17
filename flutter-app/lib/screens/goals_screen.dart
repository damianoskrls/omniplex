import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../config/tenant_config.dart';
import '../models/fitness_profile.dart';
import '../models/user_stats.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/ui_kit.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  UserStats? _stats;
  List<FitnessGoalOption> _goalOptions = [];
  bool _loading = true;
  bool _savingFitness = false;
  bool _savingSessions = false;
  int _target = 6;

  final _weightCtrl = TextEditingController();
  final _targetWeightCtrl = TextEditingController();
  String? _selectedFitnessGoal;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _targetWeightCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final api = context.read<AuthService>().api;
    try {
      UserStats? stats;
      try {
        stats = await api.fetchMyStats();
      } catch (_) {}

      final options = await api.fetchFitnessGoals();
      await context.read<AuthService>().refreshUser();
      final profile = context.read<AuthService>().user?.fitnessProfile ?? const FitnessProfile();

      if (!mounted) return;
      setState(() {
        _stats = stats;
        _goalOptions = options;
        if (stats != null) _target = stats.goal.targetSessions;
        _selectedFitnessGoal = profile.fitnessGoal;
        _weightCtrl.text = _formatWeight(profile.weightKg);
        _targetWeightCtrl.text = _formatWeight(profile.targetWeightKg);
      });
    } on ApiException catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  String _formatWeight(double? value) {
    if (value == null) return '';
    final text = value.toStringAsFixed(1);
    return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
  }

  double? _parseWeight(String raw) {
    final normalized = raw.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  Future<void> _saveFitness() async {
    final weight = _parseWeight(_weightCtrl.text);
    final targetWeight = _parseWeight(_targetWeightCtrl.text);
    if (weight != null && (weight <= 0 || weight > 500)) {
      _showSnack('Το βάρος πρέπει να είναι μεταξύ 0 και 500 kg', success: false);
      return;
    }
    if (targetWeight != null && (targetWeight <= 0 || targetWeight > 500)) {
      _showSnack('Ο στόχος βάρους πρέπει να είναι μεταξύ 0 και 500 kg', success: false);
      return;
    }

    setState(() => _savingFitness = true);
    try {
      await context.read<AuthService>().api.updateMyFitnessProfile(
            weightKg: weight,
            targetWeightKg: targetWeight,
            fitnessGoal: _selectedFitnessGoal,
          );
      await context.read<AuthService>().refreshUser();
      if (mounted) _showSnack('Τα στοιχεία σου αποθηκεύτηκαν');
    } on ApiException catch (e) {
      if (mounted) _showSnack(e.message, success: false);
    } finally {
      if (mounted) setState(() => _savingFitness = false);
    }
  }

  Future<void> _saveSessionsGoal() async {
    setState(() => _savingSessions = true);
    try {
      final stats = await context.read<AuthService>().api.updateMyGoal(_target);
      setState(() => _stats = stats);
      if (mounted) _showSnack('Ο μηνιαίος στόχος ενημερώθηκε');
    } on ApiException catch (e) {
      if (mounted) _showSnack(e.message, success: false);
    } finally {
      if (mounted) setState(() => _savingSessions = false);
    }
  }

  void _showSnack(String message, {bool success = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            color: success ? AppColors.bg : AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: success ? AppColors.lime : AppColors.surface,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;
    final user = context.watch<AuthService>().user;
    final profile = user?.fitnessProfile ?? const FitnessProfile();
    final config = context.read<TenantConfig>();
    final showLoyalty = config.featureLoyaltyPoints;

    return Scaffold(
      appBar: AppBar(title: const Text('Στόχοι')),
      body: _loading
          ? Center(child: const CircularProgressIndicator(color: AppColors.lime))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text('Φυσική κατάσταση', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  'Ορίσε τον στόχο σου (π.χ. απώλεια βάρους) και καταχώρησε το τρέχον και το επιθυμητό βάρος.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Τύπος στόχου', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _goalOptions.map((option) {
                          final selected = _selectedFitnessGoal == option.id;
                          return FilterChip(
                            label: Text(option.label),
                            selected: selected,
                            onSelected: (_) => setState(() => _selectedFitnessGoal = option.id),
                            selectedColor: AppColors.lime.withValues(alpha: 0.2),
                            checkmarkColor: AppColors.lime,
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _weightCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Τρέχον βάρος (kg)',
                                prefixIcon: Icon(Icons.monitor_weight_outlined),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _targetWeightCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Στόχος βάρους (kg)',
                                prefixIcon: Icon(Icons.flag_outlined),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (profile.fitnessGoal == 'weight_loss' &&
                          profile.weightKg != null &&
                          profile.targetWeightKg != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Απόσταση από στόχο: ${(profile.weightKg! - profile.targetWeightKg!).toStringAsFixed(1)} kg',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.lime),
                        ),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _savingFitness ? null : _saveFitness,
                          child: _savingFitness
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bg),
                                )
                              : const Text('Αποθήκευση στοιχείων'),
                        ),
                      ),
                    ],
                  ),
                ),
                if (showLoyalty && stats != null) ...[
                  const SizedBox(height: 28),
                  Text('Προπόνηση & πόντοι', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  GradientCard(
                    colors: const [Color(0xFF3D2F8F), AppColors.purple],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Loyalty πόντοι', style: TextStyle(color: Colors.white70)),
                        Text(
                          '${stats.loyaltyPoints}',
                          style: const TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Πρόοδος μήνα', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: stats.goalProgressPct / 100,
                            minHeight: 12,
                            backgroundColor: AppColors.border,
                            color: AppColors.lime,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('${stats.sessionsThisMonth} / ${stats.goal.targetSessions} προπονήσεις'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Μηνιαίος στόχος προπονήσεων', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: _target > 1 ? () => setState(() => _target--) : null,
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text(
                        '$_target',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      IconButton(
                        onPressed: _target < 30 ? () => setState(() => _target++) : null,
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    alignment: WrapAlignment.center,
                    children: [4, 6, 8, 12].map((n) {
                      return ActionChip(
                        label: Text('$n/μήνα'),
                        onPressed: () => setState(() => _target = n),
                        backgroundColor:
                            _target == n ? AppColors.lime.withValues(alpha: 0.2) : AppColors.surface,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _savingSessions ? null : _saveSessionsGoal,
                      child: _savingSessions
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bg),
                            )
                          : const Text('Αποθήκευση στόχου προπονήσεων'),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
