import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:provider/provider.dart';
import '../models/user_stats.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/stripe_checkout.dart';
import '../theme/app_colors.dart';
import '../l10n/tr.dart';


/// Shows the payment method bottom sheet for a given [PaymentRecord].
/// Call via [showPaymentSheet].
void showPaymentSheet(
  BuildContext context, {
  required PaymentRecord payment,
  required Map<String, dynamic> paymentOptions,
  required VoidCallback onPaid,
}) {
  final methods = (paymentOptions['methods'] as List? ?? [])
      .whereType<Map>()
      .map((m) => Map<String, dynamic>.from(m))
      .toList();

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
  bool _storeRequested = false;
  String? _storeMessage;

  String _eur(int cents) => '€${(cents / 100).toStringAsFixed(2)}';

  Future<void> _payWithCard() async {
    setState(() => _submitting = true);
    try {
      final api = context.read<AuthService>().api;
      final intent = await api.startPaymentIntent(widget.payment.id);
      final secret = intent['client_secret'] as String?;
      final publishable = intent['publishable_key'] as String?;
      final intentId = intent['intent_id'] as String?;
      if (secret == null || publishable == null || intentId == null) {
        throw ApiException(tr('Η πληρωμή με κάρτα δεν είναι διαθέσιμη'));
      }
      await presentCardPaymentSheet(
        publishableKey: publishable,
        clientSecret: secret,
        merchantDisplayName: 'OmniPlex',
      );
      await api.confirmOnlinePayment(paymentId: widget.payment.id, intentId: intentId);
      if (!mounted) return;
      widget.onPaid();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Η πληρωμή ολοκληρώθηκε'))),
      );
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) return;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(e.error.localizedMessage ?? tr('Η πληρωμή ακυρώθηκε')))),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(e.message))));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _requestPayInStore() async {
    setState(() => _submitting = true);
    try {
      final api = context.read<AuthService>().api;
      final result = await api.requestPayInStore(widget.payment.id);
      if (!mounted) return;
      setState(() {
        _storeRequested = true;
        final _storeMessage = result['message'] as String? ??
            tr('Το αίτημα στάλθηκε. Μπορείς να πληρώσεις στο κατάστημα.');
      });
      widget.onPaid();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(e.message))));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _declareBankTransfer() async {
    setState(() => _submitting = true);
    try {
      final api = context.read<AuthService>().api;
      await api.declareBankTransfer(widget.payment.id);
      setState(() => _bankDeclared = true);
      widget.onPaid();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(e.message))));
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
          Text(tr('Επιλογή τρόπου πληρωμής'), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            tr('${widget.payment.description ?? "Πληρωμή"} · ${_eur(widget.payment.balanceCents)}'),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),

          if (hasCard)
            PaymentMethodTile(
              icon: Icons.credit_card,
              title: tr('Κάρτα'),
              subtitle: tr('Άμεση χρέωση μέσω Stripe'),
              selected: _selected == 'card',
              onTap: () => setState(() => _selected = 'card'),
            ),

          const SizedBox(height: 12),
          PaymentMethodTile(
            icon: Icons.storefront_outlined,
            title: tr('Θα πληρώσω στο κατάστημα'),
            subtitle: tr('Ζήτα παράταση και πλήρωσε από κοντά'),
            selected: _selected == 'in_store',
            onTap: () => setState(() => _selected = 'in_store'),
          ),

          if (hasBank) ...[
            const SizedBox(height: 12),
            PaymentMethodTile(
              icon: Icons.account_balance,
              title: tr('Τραπεζική κατάθεση'),
              subtitle: tr('Κατάθεσε και ειδοποίησε τον admin'),
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
                  Text(tr('Στοιχεία κατάθεσης'),
                      style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.lime)),
                  const SizedBox(height: 12),
                  if (bankMethod['beneficiary'] != null)
                    BankRow(tr('Δικαιούχος'), bankMethod['beneficiary'] as String),
                  if (bankMethod['bank_name'] != null)
                    BankRow(tr('Τράπεζα'), bankMethod['bank_name'] as String),
                  BankRow('IBAN', bankMethod['iban'] as String, copyable: true),
                  BankRow(tr('Ποσό'), _eur(widget.payment.balanceCents)),
                  BankRow(tr('Αιτιολογία'), widget.payment.description ?? tr('Πληρωμή συνδρομής')),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_bankDeclared)
              Row(children: [
                const Icon(Icons.check_circle, color: AppColors.lime, size: 20),
                SizedBox(width: 8),
                Expanded(child: Text(tr('Καταχωρήθηκε! Αναμένει επιβεβαίωση από το γυμναστήριο.'),
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
                      : Text(tr('Έχω κάνει την κατάθεση')),
                ),
              ),
          ],

          if (_selected == 'card') ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submitting ? null : _payWithCard,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.lime,
                  foregroundColor: AppColors.bg,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _submitting
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bg))
                    : Text(tr('Πληρωμή ${_eur(widget.payment.balanceCents)}')),
              ),
            ),
          ],

          if (_selected == 'in_store') ...[
            const SizedBox(height: 20),
            if (_storeRequested)
              Row(children: [
                const Icon(Icons.check_circle, color: AppColors.lime, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  tr(_storeMessage ?? tr('Το αίτημα στάλθηκε. Μπορείς να πληρώσεις στο κατάστημα.')),
                  style: const TextStyle(color: AppColors.lime, fontWeight: FontWeight.w600),
                )),
              ])
            else ...[
              Text(
                tr('Το γυμναστήριο θα δει ότι θα πληρώσεις από κοντά. Το πακέτο μένει ανοιχτό για 7 μέρες μέχρι να περάσεις.'),
                style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submitting ? null : _requestPayInStore,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.lime,
                    foregroundColor: AppColors.bg,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _submitting
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bg))
                      : Text(tr('Αίτημα παράτασης')),
                ),
              ),
            ],
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
                Text(tr(title), style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: selected ? AppColors.lime : AppColors.textPrimary,
                )),
                Text(tr(subtitle), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
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
            child: Text(tr(label), style: const TextStyle(
              color: AppColors.textSecondary, fontSize: 12,
            )),
          ),
          Expanded(
            child: Text(tr(value), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          if (copyable)
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(tr('IBAN αντιγράφηκε')), duration: Duration(seconds: 1)),
                );
              },
              child: Icon(Icons.copy, size: 16, color: AppColors.lime),
            ),
        ],
      ),
    );
  }
}
