import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/user_stats.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';

/// Shows the payment method bottom sheet for a given [PaymentRecord].
/// Call via [showPaymentSheet].
void showPaymentSheet(
  BuildContext context, {
  required PaymentRecord payment,
  required Map<String, dynamic> paymentOptions,
  required VoidCallback onPaid,
}) {
  final methods = (paymentOptions['methods'] as List? ?? [])
      .cast<Map<String, dynamic>>();
  if (methods.isEmpty) return;

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => PaymentSheet(
      payment: payment,
      methods: methods,
      onPaid: onPaid,
    ),
  );
}

class PaymentSheet extends StatefulWidget {
  const PaymentSheet({
    super.key,
    required this.payment,
    required this.methods,
    required this.onPaid,
  });
  final PaymentRecord payment;
  final List<Map<String, dynamic>> methods;
  final VoidCallback onPaid;

  @override
  State<PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<PaymentSheet> {
  String? _selected;
  bool _submitting = false;
  bool _bankDeclared = false;

  String _eur(int cents) => '€${(cents / 100).toStringAsFixed(2)}';

  Future<void> _declareBankTransfer() async {
    setState(() => _submitting = true);
    try {
      final api = context.read<AuthService>().api;
      await api.declareBankTransfer(widget.payment.id);
      setState(() => _bankDeclared = true);
      widget.onPaid();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bankMethod = widget.methods.firstWhere(
      (m) => m['type'] == 'bank_transfer', orElse: () => {},
    );
    final hasBank = bankMethod.isNotEmpty;
    final hasCard = widget.methods.any((m) => m['type'] == 'card');

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
          Text('Επιλογή τρόπου πληρωμής', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            '${widget.payment.description ?? "Πληρωμή"} · ${_eur(widget.payment.balanceCents)}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),

          if (hasCard)
            PaymentMethodTile(
              icon: Icons.credit_card,
              title: 'Κάρτα',
              subtitle: 'Άμεση χρέωση μέσω Stripe',
              selected: _selected == 'card',
              onTap: () => setState(() => _selected = 'card'),
            ),

          if (hasBank) ...[
            if (hasCard) const SizedBox(height: 12),
            PaymentMethodTile(
              icon: Icons.account_balance,
              title: 'Τραπεζική κατάθεση',
              subtitle: 'Κατάθεσε και ειδοποίησε τον admin',
              selected: _selected == 'bank_transfer',
              onTap: () => setState(() => _selected = 'bank_transfer'),
            ),
          ],

          if (_selected == 'bank_transfer' && hasBank) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Στοιχεία κατάθεσης',
                      style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.lime)),
                  const SizedBox(height: 12),
                  if (bankMethod['beneficiary'] != null)
                    BankRow('Δικαιούχος', bankMethod['beneficiary'] as String),
                  if (bankMethod['bank_name'] != null)
                    BankRow('Τράπεζα', bankMethod['bank_name'] as String),
                  BankRow('IBAN', bankMethod['iban'] as String, copyable: true),
                  BankRow('Ποσό', _eur(widget.payment.balanceCents)),
                  BankRow('Αιτιολογία', widget.payment.description ?? 'Πληρωμή συνδρομής'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_bankDeclared)
              const Row(children: [
                Icon(Icons.check_circle, color: AppColors.lime, size: 20),
                SizedBox(width: 8),
                Expanded(child: Text('Καταχωρήθηκε! Αναμένει επιβεβαίωση από το γυμναστήριο.',
                    style: TextStyle(color: AppColors.lime, fontWeight: FontWeight.w600))),
              ])
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submitting ? null : _declareBankTransfer,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.lime,
                    foregroundColor: AppColors.bg,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _submitting
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bg))
                      : const Text('Έχω κάνει την κατάθεση'),
                ),
              ),
          ],

          if (_selected == 'card') ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline, color: AppColors.lime, size: 20),
                SizedBox(width: 10),
                Expanded(child: Text(
                  'Η πληρωμή με κάρτα θα ολοκληρωθεί μέσω του ασφαλούς περιβάλλοντος Stripe.',
                  style: TextStyle(fontSize: 13, height: 1.4),
                )),
              ]),
            ),
          ],
        ],
      ),
    );
  }
}

class PaymentMethodTile extends StatelessWidget {
  const PaymentMethodTile({
    super.key,
    required this.icon, required this.title, required this.subtitle,
    required this.selected, required this.onTap,
  });
  final IconData icon;
  final String title, subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.lime.withValues(alpha: 0.1) : AppColors.bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.lime : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? AppColors.lime : AppColors.textSecondary, size: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: selected ? AppColors.lime : AppColors.textPrimary,
                )),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ]),
            ),
            if (selected) const Icon(Icons.check_circle, color: AppColors.lime, size: 20),
          ],
        ),
      ),
    );
  }
}

class BankRow extends StatelessWidget {
  const BankRow(this.label, this.value, {super.key, this.copyable = false});
  final String label, value;
  final bool copyable;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: const TextStyle(
              color: AppColors.textSecondary, fontSize: 12,
            )),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          if (copyable)
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('IBAN αντιγράφηκε'), duration: Duration(seconds: 1)),
                );
              },
              child: const Icon(Icons.copy, size: 16, color: AppColors.lime),
            ),
        ],
      ),
    );
  }
}
