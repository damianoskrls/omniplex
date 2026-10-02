import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:provider/provider.dart';
import '../models/location.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../l10n/tr.dart';


class AddServiceScreen extends StatefulWidget {
  const AddServiceScreen({super.key});

  @override
  State<AddServiceScreen> createState() => _AddServiceScreenState();
}

class _AddServiceScreenState extends State<AddServiceScreen> {
  List<Map<String, dynamic>> _services = [];
  bool _loading = true;
  bool _stripeReady = false;
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
      final result = await context.read<AuthService>().api.fetchExtraServices();
      if (!mounted) return;
      setState(() {
        _services = result.services;
        _stripeReady = result.stripeReady;
      });
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
    if (value == null) return tr('Απεριόριστες συνεδρίες');
    final n = value is num ? value.toInt() : int.tryParse('$value');
    if (n == null || n <= 0 || n >= 9999) return tr('Απεριόριστες συνεδρίες');
    return n == 1 ? '1 συνεδρία' : tr('$n συνεδρίες');
  }

  String _fmtSlot(String? date, String? time) {
    if (date == null || date.length < 10) return time ?? '';
    final days = [tr('Δευτέρα'), tr('Τρίτη'), tr('Τετάρτη'), tr('Πέμπτη'), tr('Παρασκευή'), tr('Σάββατο'), tr('Κυριακή')];
    final months = [tr('Ιαν'), tr('Φεβ'), tr('Μαρ'), tr('Απρ'), tr('Μαΐ'), tr('Ιουν'), tr('Ιουλ'), tr('Αυγ'), tr('Σεπ'), tr('Οκτ'), tr('Νοε'), tr('Δεκ')];
    final d = DateTime.tryParse(date);
    if (d == null) return '$date ${time ?? ''}'.trim();
    return '${days[d.weekday - 1]} ${d.day} ${months[d.month - 1]}, ${time ?? ''}'.trim();
  }

  Future<void> _request(Map<String, dynamic> plan, String serviceId) async {
    final planId = plan['id']?.toString();
    if (planId == null) return;
    final kind = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(tr('Τι θέλεις να ζητήσεις;'), style: TextStyle(color: Colors.white)),
        content: Text(
          tr('Το γυμναστήριο θα δει το αίτημα και θα το αποδεχτεί.'),
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Άκυρο'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'trial'),
            child: Text(tr('Πρώτα δοκιμαστικό')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'enroll'),
            child: Text(tr('Εγγραφή στο πακέτο')),
          ),
        ],
      ),
    );
    if (kind == null || !mounted) return;
    String? locationId;
    String? locationName;
    try {
      final locs = await context.read<AuthService>().api.fetchLocations(serviceId: serviceId);
      if (!mounted) return;
      if (locs.locations.length > 1) {
        final picked = await showDialog<GymLocation>(
          context: context,
          builder: (ctx) => SimpleDialog(
            title: Text(tr('Σε ποιο κατάστημα;')),
            children: [
              for (final loc in locs.locations)
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, loc),
                  child: Text(tr(loc.displayLine.isEmpty ? loc.name : '${loc.name}\n${loc.displayLine}')),
                ),
            ],
          ),
        );
        if (picked == null || !mounted) return;
        locationId = picked.id;
        locationName = picked.name;
      } else if (locs.locations.length == 1) {
        locationId = locs.locations.first.id;
        locationName = locs.locations.first.name;
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(e.message))));
      }
      return;
    }
    String? trialDate;
    String? trialTime;
    if (kind == 'trial') {
      setState(() => _buyingId = planId);
      Map<String, dynamic>? slot;
      try {
        slot = await context.read<AuthService>().api.fetchNextSlot(
          serviceId: serviceId,
          locationId: locationId,
        );
      } on ApiException catch (e) {
        if (mounted) {
          setState(() => _buyingId = null);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(e.message))));
        }
        return;
      }
      if (!mounted) return;
      setState(() => _buyingId = null);
      if (slot == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('Δεν βρέθηκε διαθέσιμο ραντεβού τις επόμενες 2 εβδομάδες'))),
        );
        return;
      }
      trialDate = slot['date']?.toString();
      trialTime = slot['time']?.toString();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(tr('Επόμενο διαθέσιμο'), style: TextStyle(color: Colors.white)),
          content: Text(
            tr('${locationName != null ? '$locationName\n' : ''}${_fmtSlot(trialDate, trialTime)}\n\nΘα λάβεις ειδοποίηση έγκρισης πριν κλειστεί το ραντεβού.'),
            style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Άκυρο'))),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Στείλε αίτημα'))),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    setState(() => _buyingId = planId);
    try {
      final result = await context.read<AuthService>().api.requestExtraPlan(
        planId: planId,
        kind: kind,
        serviceId: serviceId,
        trialDate: trialDate,
        trialTime: trialTime,
        locationId: locationId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(result['message']?.toString() ?? tr('Το αίτημα στάλθηκε')))),
      );
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(e.message))));
      }
    } finally {
      if (mounted) setState(() => _buyingId = null);
    }
  }

  Future<void> _buy(Map<String, dynamic> plan) async {
    final planId = plan['id']?.toString();
    if (planId == null) return;
    setState(() => _buyingId = planId);
    try {
      final api = context.read<AuthService>().api;
      final result = await api.buyExtraPlan(planId);
      var message = result['message'] as String? ?? tr('Η υπηρεσία προστέθηκε.');
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
        final message = confirmed['message'] as String? ?? tr('Το πακέτο αγοράστηκε.');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(message))));
      Navigator.pop(context, true);
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
      if (mounted) setState(() => _buyingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: Text(tr('Πρόσθεσε υπηρεσία')),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.lime))
          : _error != null
              ? Center(child: Text(tr(_error!)))
              : _services.isEmpty
                  ? Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          tr('Έχεις ήδη όλες τις υπηρεσίες του γυμναστηρίου.'),
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
    final serviceId = service['id']?.toString() ?? '';
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
            tr(service['name']?.toString() ?? ''),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          if ((service['description']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              tr(service['description'].toString()),
              style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
            ),
          ],
          const SizedBox(height: 12),
          if (plans.isEmpty)
            Text(
              tr('Δεν υπάρχει πακέτο για αυτή την υπηρεσία.'),
              style: TextStyle(color: AppColors.textSecondary),
            )
          else
            ...plans.map((plan) {
              final id = plan['id']?.toString();
              final cents = (plan['price_cents'] as num?)?.toInt() ?? 0;
              final pending = plan['pending_kind']?.toString();
              final busy = _buyingId == id;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr(plan['name']?.toString() ?? tr('Πακέτο')),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(
                      tr('${_sessions(plan['sessions'])} · ${_price(cents)}'),
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    if (pending != null)
                      Text(
                        tr(pending == 'trial' ? 'Εκκρεμεί αίτημα δοκιμαστικού' : tr('Εκκρεμεί αίτημα εγγραφής')),
                        style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (_stripeReady)
                            FilledButton(
                              onPressed: busy || _buyingId != null ? null : () => _buy(plan),
                              child: busy
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : Text(tr('Πλήρωσε τώρα')),
                            ),
                          OutlinedButton(
                            onPressed: busy || _buyingId != null ? null : () => _request(plan, serviceId),
                            child: Text(tr('Αίτημα')),
                          ),
                        ],
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
