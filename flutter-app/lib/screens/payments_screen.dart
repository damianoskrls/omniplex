import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../config/tenant_config.dart';
import '../models/user_stats.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/ui_kit.dart';
import '../widgets/payment_sheet.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  List<PaymentRecord> _payments = [];
  int _totalBalance = 0;
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _paymentOptions;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = context.read<AuthService>().api;
      final config = context.read<TenantConfig>();
      final result = await api.fetchMyPayments();
      setState(() {
        _payments = result.payments;
        _totalBalance = result.totalBalanceCents;
      });
      if (config.featureOnlinePayments) {
        final opts = await api.fetchPaymentOptions();
        if (mounted) setState(() => _paymentOptions = opts);
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _eur(int cents) => '€${(cents / 100).toStringAsFixed(2)}';

  Color _statusColor(String status) {
    switch (status) {
      case 'paid':      return AppColors.lime;
      case 'partial':   return AppColors.orange;
      case 'overdue':   return AppColors.pink;
      default:          return AppColors.purple;
    }
  }

  void _showPaymentSheet(PaymentRecord p) {
    final opts = _paymentOptions;
    if (opts == null || opts['enabled'] != true) return;
    showPaymentSheet(context, payment: p, paymentOptions: opts, onPaid: _load);
  }

  @override
  Widget build(BuildContext context) {
    final hasOnline = _paymentOptions?['enabled'] == true &&
        (_paymentOptions!['methods'] as List? ?? []).isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Οι πληρωμές μου')),
      body: _loading
          ? Center(child: const CircularProgressIndicator(color: AppColors.lime))
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.lime,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      SurfaceCard(
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Υπόλοιπο προς πληρωμή',
                                      style: Theme.of(context).textTheme.bodyMedium),
                                  Text(
                                    _eur(_totalBalance),
                                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: _totalBalance > 0 ? AppColors.orange : AppColors.lime,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              _totalBalance > 0 ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                              color: _totalBalance > 0 ? AppColors.orange : AppColors.lime,
                              size: 32,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_payments.isEmpty)
                        const EmptyState(
                          icon: Icons.receipt_long_outlined,
                          title: 'Δεν υπάρχουν καταχωρήσεις',
                          subtitle: 'Ο διαχειριστής θα προσθέσει τις πληρωμές σου εδώ.',
                        )
                      else
                        ..._payments.map((p) {
                          final date = p.paymentDate ?? p.dueDate;
                          final canPay = hasOnline && p.balanceCents > 0 && p.status != 'paid';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: SurfaceCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          p.description ?? 'Πληρωμή',
                                          style: Theme.of(context).textTheme.titleMedium,
                                        ),
                                      ),
                                      PillChip(
                                        label: p.statusLabel,
                                        color: _statusColor(p.status).withValues(alpha: 0.15),
                                        textColor: _statusColor(p.status),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text('Σύνολο: ${_eur(p.amountCents)} · Πληρώθηκε: ${_eur(p.paidAmountCents)}'),
                                  if (p.balanceCents > 0)
                                    Text(
                                      'Υπόλοιπο: ${_eur(p.balanceCents)}',
                                      style: const TextStyle(color: AppColors.orange, fontWeight: FontWeight.w600),
                                    ),
                                  if (date != null)
                                    Text(
                                      DateFormat('d MMM yyyy', 'el_GR').format(date),
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  if (p.notes != null && p.notes!.isNotEmpty)
                                    Text(p.notes!, style: Theme.of(context).textTheme.bodyMedium),
                                  if (canPay) ...[
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: FilledButton.icon(
                                        onPressed: () => _showPaymentSheet(p),
                                        icon: const Icon(Icons.payment, size: 18),
                                        label: Text('Πλήρωσε ${_eur(p.balanceCents)}'),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: AppColors.lime,
                                          foregroundColor: AppColors.bg,
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
    );
  }
}
