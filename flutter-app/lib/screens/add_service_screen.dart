import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';

class AddServiceScreen extends StatefulWidget {
  const AddServiceScreen({super.key});

  @override
  State<AddServiceScreen> createState() => _AddServiceScreenState();
}

class _AddServiceScreenState extends State<AddServiceScreen> {
  List<Map<String, dynamic>> _services = [];
  bool _loading = true;
  String? _error;
  String? _buyingId;

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
      final services = await context.read<AuthService>().api.fetchExtraServices();
      if (!mounted) return;
      setState(() => _services = services);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _price(int cents) {
    final eur = cents / 100;
    return '€${eur % 1 == 0 ? eur.toInt() : eur.toStringAsFixed(2)}';
  }

  String _sessions(dynamic value) {
    if (value == null) return 'Απεριόριστες συνεδρίες';
    final n = value is num ? value.toInt() : int.tryParse('$value');
    if (n == null || n <= 0 || n >= 9999) return 'Απεριόριστες συνεδρίες';
    return n == 1 ? '1 συνεδρία' : '$n συνεδρίες';
  }

  Future<void> _buy(Map<String, dynamic> plan) async {
    final planId = plan['id']?.toString();
    if (planId == null) return;
    setState(() => _buyingId = planId);
    try {
      final api = context.read<AuthService>().api;
      final result = await api.buyExtraPlan(planId);
      var message = result['message'] as String? ?? 'Η υπηρεσία προστέθηκε.';
      if (result['mode'] == 'stripe') {
        Stripe.publishableKey = result['publishable_key'] as String;
        await Stripe.instance.initPaymentSheet(
          paymentSheetParameters: SetupPaymentSheetParameters(
            paymentIntentClientSecret: result['client_secret'] as String,
            merchantDisplayName: 'OmniPlex',
            style: ThemeMode.dark,
          ),
        );
        await Stripe.instance.presentPaymentSheet();
        final confirmed = await api.confirmExtraPlan(
          planId: planId,
          intentId: result['intent_id'] as String,
        );
        message = confirmed['message'] as String? ?? 'Το πακέτο αγοράστηκε.';
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      Navigator.pop(context, true);
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) return;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.error.localizedMessage ?? 'Η πληρωμή ακυρώθηκε')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _buyingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: const Text('Πρόσθεσε υπηρεσία'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.lime))
          : _error != null
              ? Center(child: Text(_error!))
              : _services.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Έχεις ήδη όλες τις υπηρεσίες του γυμναστηρίου.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      color: AppColors.lime,
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                        itemCount: _services.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 16),
                        itemBuilder: (_, i) => _serviceCard(_services[i]),
                      ),
                    ),
    );
  }

  Widget _serviceCard(Map<String, dynamic> service) {
    final plans = (service['plans'] as List? ?? []).cast<Map<String, dynamic>>();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            service['name']?.toString() ?? '',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          if ((service['description']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              service['description'].toString(),
              style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
            ),
          ],
          const SizedBox(height: 12),
          if (plans.isEmpty)
            const Text(
              'Δεν υπάρχει πακέτο για αυτή την υπηρεσία.',
              style: TextStyle(color: AppColors.textSecondary),
            )
          else
            ...plans.map((plan) {
              final id = plan['id']?.toString();
              final cents = (plan['price_cents'] as num?)?.toInt() ?? 0;
              final busy = _buyingId == id;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(plan['name']?.toString() ?? 'Πακέτο',
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text(
                            '${_sessions(plan['sessions'])} · ${_price(cents)}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    FilledButton(
                      onPressed: busy || _buyingId != null ? null : () => _buy(plan),
                      style: FilledButton.styleFrom(
                        foregroundColor: Colors.white,
                      ),
                      child: busy
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Πάρε το'),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
