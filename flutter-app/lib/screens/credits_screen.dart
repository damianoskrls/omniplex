import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../config/tenant_config.dart';
import '../models/booking.dart';
import '../models/service.dart';
import '../models/user_stats.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/ui_kit.dart';
import '../widgets/payment_sheet.dart';
import 'nutrition_consultation_booking_screen.dart';

class CreditsScreen extends StatefulWidget {
  const CreditsScreen({super.key});

  @override
  State<CreditsScreen> createState() => _CreditsScreenState();
}

class _CreditsScreenState extends State<CreditsScreen> {
  List<MembershipCredit> _credits = [];
  List<PaymentRecord> _pendingPayments = [];
  int _totalBalanceCents = 0;
  Map<String, dynamic>? _paymentOptions;
  bool _loading = true;
  String? _error;
  BookService? _nutritionConsultService;
  Map<String, dynamic> _nutritionCredits = {};
  Map<String, dynamic>? _nutritionPendingBooking;
  Map<String, dynamic>? _nutritionUpcomingBooking;
  List<Map<String, dynamic>> _nutritionists = [];
  bool _nutritionConsultCanBook = false;
  bool _needsNutritionistChoice = false;

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
    try {
      final auth = context.read<AuthService>();
      final config = context.read<TenantConfig>();
      final credits = await auth.api.fetchMyCredits();
      BookService? consultService;
      Map<String, dynamic> consultCredits = {};
      Map<String, dynamic>? pendingBooking;
      Map<String, dynamic>? upcomingBooking;
      List<Map<String, dynamic>> nutritionists = [];
      var consultCanBook = false;
      var needsNutritionistChoice = false;

      if (config.featureOnlinePayments) {
        try {
          final payResult = await auth.api.fetchMyPayments();
          final opts = await auth.api.fetchPaymentOptions();
          if (mounted) setState(() {
            _pendingPayments = payResult.payments.where((p) => p.balanceCents > 0 && p.status != 'paid').toList();
            _totalBalanceCents = payResult.totalBalanceCents;
            _paymentOptions = opts['enabled'] == true ? opts : null;
          });
        } on ApiException catch (_) {}
      }

      if (config.featureNutrition) {
        try {
          final consult = await auth.api.fetchNutritionConsultation();
          consultService = consult.service;
          consultCredits = consult.credits;
          pendingBooking = consult.pendingBooking;
          upcomingBooking = consult.upcomingBooking;
          nutritionists = consult.nutritionists;
          consultCanBook = consult.canBook;
          needsNutritionistChoice = consult.needsNutritionistChoice;
        } on ApiException catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _credits = credits;
        _nutritionConsultService = consultService;
        _nutritionCredits = consultCredits;
        _nutritionPendingBooking = pendingBooking;
        _nutritionUpcomingBooking = upcomingBooking;
        _nutritionists = nutritionists;
        _nutritionConsultCanBook = consultCanBook;
        _needsNutritionistChoice = needsNutritionistChoice;
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _periodLabel(String? period) {
    const map = {'monthly': 'Μηνιαίο', 'yearly': 'Ετήσιο', 'weekly': 'Εβδομαδιαίο'};
    return map[period] ?? period ?? '';
  }

  Future<void> _openNutritionBooking() async {
    final service = _nutritionConsultService;
    if (service == null) return;
    final booked = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => NutritionConsultationBookingScreen(
          service: service,
          credits: _nutritionCredits,
          pendingBooking: _nutritionPendingBooking,
          upcomingBooking: _nutritionUpcomingBooking,
          nutritionists: _nutritionists,
          needsNutritionistChoice: _needsNutritionistChoice,
        ),
      ),
    );
    if (booked == true) _load();
  }

  Future<void> _cancelMembership(MembershipCredit credit) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Διακοπή συνδρομής'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Θέλεις να διακόψεις τη συνδρομή σου;'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Λόγος (προαιρετικό)',
                hintText: 'π.χ. Μετακόμιση',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Άκυρο')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Διακοπή', style: TextStyle(color: AppColors.orange)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await context.read<AuthService>().api.cancelMembership(
        credit.id,
        reason: reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Η συνδρομή διακόπηκε')),
      );
      _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  List<String> _nutritionFeatures(MembershipCredit credit) {
    final features = <String>[];
    if (credit.nutritionIncludesMealPlan == true) features.add('Πλάνο γευμάτων');
    if (credit.nutritionIncludesMeasurements == true) features.add('Μετρήσεις');
    if (credit.nutritionIncludesFoodDiary == true) features.add('Ημερολόγιο διατροφής');
    if (credit.nutritionIncludesConsultations == true) {
      final n = credit.nutritionConsultationSessions;
      features.add(n != null ? '$n επισκέψεις διατροφολόγου' : 'Επισκέψεις διατροφολόγου');
    }
    return features;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.lime));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _load, child: const Text('Δοκίμασε ξανά')),
          ],
        ),
      );
    }

    if (_credits.isEmpty) {
      return const EmptyState(
        icon: Icons.card_membership_outlined,
        title: 'Δεν έχεις ενεργά πακέτα',
      );
    }

    final hasPendingBalance = _paymentOptions != null && _totalBalanceCents > 0 && _pendingPayments.isNotEmpty;

    return RefreshIndicator(
      color: AppColors.lime,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        itemCount: _credits.length + (hasPendingBalance ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          if (hasPendingBalance && index == 0) {
            return _PaymentBanner(
              totalCents: _totalBalanceCents,
              payments: _pendingPayments,
              paymentOptions: _paymentOptions!,
              onPaid: _load,
            );
          }
          final creditIndex = hasPendingBalance ? index - 1 : index;
          return _buildCreditCard(context, _credits[creditIndex], creditIndex);
        },
      ),
    );
  }

  Widget _buildCreditCard(BuildContext context, MembershipCredit credit, int index) {
    final renewal = DateFormat('d MMMM yyyy', 'el_GR').format(credit.validUntil);
    final started = DateFormat('d MMM yyyy', 'el_GR').format(credit.validFrom);
    final title = credit.planName ?? credit.serviceName ?? 'Γενικό πακέτο';
    final isNutrition = credit.isNutritionProgram || credit.isNutritionConsultation;
    final accent = isNutrition
        ? const Color(0xFF0f766e)
        : AppColors.cardGradient(index).first;
    final features = credit.isNutritionProgram ? _nutritionFeatures(credit) : const <String>[];

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 48,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    if (credit.isNutritionProgram)
                      const Text(
                        'Πρόγραμμα διατροφής',
                        style: TextStyle(color: Color(0xFF0f766e), fontWeight: FontWeight.w600, fontSize: 13),
                      )
                    else if (credit.isNutritionConsultation)
                      const Text(
                        'Επισκέψεις διατροφολόγου',
                        style: TextStyle(color: Color(0xFF0f766e), fontWeight: FontWeight.w600, fontSize: 13),
                      )
                    else if (credit.serviceDescription != null)
                      Text(
                        credit.serviceDescription!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (credit.inGrace)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Η συνδρομή έληξε — περίοδος χάριτος ${credit.daysInGraceLeft ?? 0} ημέρες. Ανένεωσε για να συνεχίσεις.',
                  style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ),
          if (features.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: features.map((f) => PillChip(
                label: f,
                color: const Color(0xFF0f766e).withValues(alpha: 0.12),
                textColor: const Color(0xFF0f766e),
              )).toList(),
            ),
          ],
          const SizedBox(height: 16),
          if (credit.isNutritionProgram)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0f766e).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Icon(Icons.restaurant_menu_outlined, size: 18, color: Color(0xFF0f766e)),
                  SizedBox(width: 8),
                  Text('Ενεργό πρόγραμμα διατροφής', style: TextStyle(color: Color(0xFF0f766e), fontWeight: FontWeight.w700)),
                ],
              ),
            )
          else if (credit.planServices != null && credit.planServices!.length > 1)
            // Combo plan: show per-service breakdown
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Υπόλοιπο συνεδριών', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                ...credit.planServices!.map((svc) {
                  final svcName = svc['service_name'] as String? ?? '';
                  final isUnlim = svc['is_unlimited'] == true;
                  final remaining = svc['remaining'] as int?;
                  final perPeriod = svc['sessions_per_period'] as int?;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(isUnlim ? Icons.all_inclusive : Icons.fitness_center, size: 15, color: accent),
                        const SizedBox(width: 8),
                        Expanded(child: Text(svcName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                        Text(
                          isUnlim
                              ? 'Απεριόριστες'
                              : '${remaining ?? 0} / $perPeriod αυτόν τον μήνα',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: accent),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            )
          else if (credit.isUnlimited)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.lime.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Icon(Icons.all_inclusive, size: 18, color: AppColors.lime),
                  SizedBox(width: 8),
                  Text('Απεριόριστες συνεδρίες', style: TextStyle(color: AppColors.lime, fontWeight: FontWeight.w700)),
                ],
              ),
            )
          else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Υπόλοιπο', style: Theme.of(context).textTheme.bodyMedium),
                Text(
                  '${credit.remaining} / ${credit.totalSessions}',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: accent),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: credit.usageProgress.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: AppColors.border,
                color: accent,
              ),
            ),
          ],
          const SizedBox(height: 16),
          _InfoRow(icon: Icons.event, label: 'Έναρξη', value: started),
          _InfoRow(icon: Icons.autorenew, label: credit.isNutritionProgram ? 'Λήξη' : 'Επόμενη ανανέωση', value: renewal),
          if (credit.lastPaymentDate != null)
            _InfoRow(
              icon: Icons.receipt_long_outlined,
              label: 'Τελευταία πληρωμή',
              value: DateFormat('d MMM yyyy', 'el_GR').format(DateTime.parse(credit.lastPaymentDate!)),
            ),
          if (credit.billingPeriod != null)
            _InfoRow(icon: Icons.payments, label: 'Περίοδος', value: _periodLabel(credit.billingPeriod)),
          if (credit.planPriceCents != null)
            _InfoRow(icon: Icons.euro, label: 'Τιμή', value: '€${(credit.planPriceCents! / 100).toStringAsFixed(2)}'),
          if (credit.notes != null && credit.notes!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(credit.notes!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12)),
            ),
          if (credit.isNutritionConsultation && _nutritionConsultService != null) ...[
            const SizedBox(height: 16),
            if (_nutritionPendingBooking != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Έχεις αίτημα κράτησης σε αναμονή επιβεβαίωσης.',
                  style: TextStyle(color: Colors.amber, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              )
            else if (_nutritionUpcomingBooking != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.lime.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Έχεις επιβεβαιωμένο ραντεβού με τον διατροφολόγο.',
                  style: TextStyle(color: AppColors.lime, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              )
            else if (credit.remaining > 0)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _nutritionConsultCanBook ? _openNutritionBooking : null,
                  icon: const Icon(Icons.monitor_heart_outlined, size: 18),
                  label: Text(_nutritionConsultCanBook ? 'Κράτηση διατροφολόγου' : 'Δεν υπάρχει διαθέσιμος διατροφολόγος'),
                ),
              ),
          ],
          if (credit.canCancel && !credit.isNutritionConsultation) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => _cancelMembership(credit),
              icon: const Icon(Icons.cancel_outlined, size: 18),
              label: const Text('Διακοπή συνδρομής'),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Payment Banner ────────────────────────────────────────────────────────────

class _PaymentBanner extends StatelessWidget {
  const _PaymentBanner({
    required this.totalCents, required this.payments,
    required this.paymentOptions, required this.onPaid,
  });
  final int totalCents;
  final List<PaymentRecord> payments;
  final Map<String, dynamic> paymentOptions;
  final VoidCallback onPaid;

  String _eur(int cents) => '€${(cents / 100).toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.orange.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.orange, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Εκκρεμής πληρωμή ${_eur(totalCents)}',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.orange),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (payments.length == 1)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => showPaymentSheet(
                  context,
                  payment: payments.first,
                  paymentOptions: paymentOptions,
                  onPaid: onPaid,
                ),
                icon: const Icon(Icons.payment, size: 18),
                label: Text('Πλήρωσε ${_eur(payments.first.balanceCents)}'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            )
          else
            ...payments.map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => showPaymentSheet(
                    context,
                    payment: p,
                    paymentOptions: paymentOptions,
                    onPaid: onPaid,
                  ),
                  icon: const Icon(Icons.payment, size: 16),
                  label: Text('${p.description ?? "Πληρωμή"} · ${_eur(p.balanceCents)}',
                      overflow: TextOverflow.ellipsis),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.orange,
                    side: const BorderSide(color: AppColors.orange),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            )),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text('$label: ', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}
