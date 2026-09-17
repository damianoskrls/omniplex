import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  List<Map<String, dynamic>> _orders = [];
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
      final api = context.read<AuthService>().api;
      final orders = await api.fetchMyMarketplaceOrders();
      if (mounted) setState(() => _orders = orders);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _eur(int cents) => '€${(cents / 100).toStringAsFixed(2)}';

  String _shortId(String id) => '#${id.replaceAll('-', '').toUpperCase().substring(0, 8)}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: const Text('Οι Παραγγελίες μου', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? Center(child: const CircularProgressIndicator(color: AppColors.lime))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.textSecondary, size: 48),
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: AppColors.textSecondary)),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _load,
                        style: FilledButton.styleFrom(backgroundColor: AppColors.lime, foregroundColor: AppColors.bg),
                        child: const Text('Επανάληψη'),
                      ),
                    ],
                  ),
                )
              : _orders.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.shopping_bag_outlined, size: 48, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 20),
                          const Text('Δεν υπάρχουν παραγγελίες', style: TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          const Text('Οι παραγγελίες σου θα εμφανίζονται εδώ', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.lime,
                      backgroundColor: AppColors.surface,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _orders.length,
                        itemBuilder: (context, i) {
                          final o = _orders[i];
                          return _OrderCard(
                            order: o,
                            shortId: _shortId(o['id'] as String? ?? '00000000'),
                            eur: _eur,
                          );
                        },
                      ),
                    ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.shortId, required this.eur});

  final Map<String, dynamic> order;
  final String shortId;
  final String Function(int) eur;

  @override
  Widget build(BuildContext context) {
    final status = order['status'] as String? ?? 'pending';
    final totalCents = order['total_cents'] as int? ?? 0;
    final createdAt = _formatDate(order['created_at'] as String?);
    final items = (order['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final cfg = _statusConfig(status);

    return GestureDetector(
      onTap: () => _showDetail(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cfg.bgColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(cfg.icon, color: cfg.color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(shortId, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15, fontFamily: 'monospace')),
                        const SizedBox(height: 2),
                        Text(createdAt, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: cfg.bgColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(cfg.label, style: TextStyle(color: cfg.color, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),

            // Items
            if (items.isNotEmpty) ...[
              Container(height: 1, color: AppColors.border),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Column(
                  children: items.take(3).map((item) {
                    final qty = item['qty'] as int? ?? 1;
                    final name = item['name'] as String? ?? '';
                    final unitCents = item['unit_price_cents'] as int? ?? 0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Center(
                              child: Text('$qty', style: const TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w700)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13), overflow: TextOverflow.ellipsis)),
                          Text(eur(unitCents * qty), style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              if (items.length > 3)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: Text('+${items.length - 3} ακόμη', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ),
            ],

            // Total
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Σύνολο', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  Text(eur(totalCents), style: TextStyle(color: AppColors.lime, fontSize: 15, fontWeight: FontWeight.w700)),
                ],
              ),
            ),

            // Status bar for in-progress orders
            if (_showTimeline(status))
              _StatusTimeline(status: status),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (_) => _OrderDetailSheet(order: order, shortId: shortId, eur: eur),
    );
  }

  bool _showTimeline(String status) => ['pending', 'paid', 'processing'].contains(status);

  static _StatusConfig _statusConfig(String status) {
    switch (status) {
      case 'pending':
        return _StatusConfig('Εκκρεμεί', const Color(0xFFF59E0B), const Color(0x22F59E0B), Icons.hourglass_empty_rounded);
      case 'paid':
        return _StatusConfig('Πληρώθηκε', const Color(0xFF60A5FA), const Color(0x2260A5FA), Icons.payment_rounded);
      case 'processing':
        return _StatusConfig('Σε επεξεργασία', const Color(0xFFA78BFA), const Color(0x22A78BFA), Icons.settings_rounded);
      case 'fulfilled':
        return _StatusConfig('Έτοιμη', AppColors.lime, Color(0x22B8F55E), Icons.check_circle_rounded);
      case 'cancelled':
        return _StatusConfig('Ακυρώθηκε', const Color(0xFFFF5757), const Color(0x22FF5757), Icons.cancel_rounded);
      case 'refunded':
        return _StatusConfig('Επιστροφή', const Color(0xFF94A3B8), const Color(0x2294A3B8), Icons.undo_rounded);
      default:
        return _StatusConfig(status, AppColors.textSecondary, AppColors.surfaceLight, Icons.circle_outlined);
    }
  }

  static String _formatDate(String? iso) {
    if (iso == null) return '—';
    try {
      final d = DateTime.parse(iso).toLocal();
      final months = ['Ιαν', 'Φεβ', 'Μαρ', 'Απρ', 'Μαϊ', 'Ιουν', 'Ιουλ', 'Αυγ', 'Σεπ', 'Οκτ', 'Νοε', 'Δεκ'];
      return '${d.day} ${months[d.month - 1]} ${d.year}, ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) { return iso; }
  }
}

class _StatusConfig {
  const _StatusConfig(this.label, this.color, this.bgColor, this.icon);
  final String label;
  final Color color;
  final Color bgColor;
  final IconData icon;
}

class _StatusTimeline extends StatelessWidget {
  const _StatusTimeline({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final steps = ['pending', 'paid', 'processing', 'fulfilled'];
    final idx = steps.indexOf(status);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (i) {
          if (i.isOdd) {
            // connector line
            final stepIdx = i ~/ 2;
            final active = stepIdx < idx;
            return Expanded(
              child: Container(height: 2, color: active ? AppColors.lime : AppColors.border),
            );
          }
          final stepIdx = i ~/ 2;
          final done = stepIdx <= idx;
          final labels = ['Εκκρεμεί', 'Πληρώθηκε', 'Επεξ.', 'Έτοιμη'];
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? AppColors.lime : AppColors.border,
                ),
                child: done
                    ? const Icon(Icons.check, size: 13, color: AppColors.bg)
                    : null,
              ),
              const SizedBox(height: 4),
              Text(labels[stepIdx], style: TextStyle(fontSize: 9, color: done ? AppColors.lime : AppColors.textSecondary, fontWeight: FontWeight.w600)),
            ],
          );
        }),
      ),
    );
  }
}

class _OrderDetailSheet extends StatelessWidget {
  const _OrderDetailSheet({required this.order, required this.shortId, required this.eur});

  final Map<String, dynamic> order;
  final String shortId;
  final String Function(int) eur;

  @override
  Widget build(BuildContext context) {
    final items = (order['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final status = order['status'] as String? ?? 'pending';
    final totalCents = order['total_cents'] as int? ?? 0;
    final cfg = _OrderCard._statusConfig(status);
    final createdAt = _OrderCard._formatDate(order['created_at'] as String?);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (_, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(shortId, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 20, fontFamily: 'monospace')),
                    const SizedBox(height: 4),
                    Text(createdAt, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: cfg.bgColor, borderRadius: BorderRadius.circular(20)),
                child: Text(cfg.label, style: TextStyle(color: cfg.color, fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Items
          const Text('Προϊόντα', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                ...items.asMap().entries.map((entry) {
                  final i = entry.key;
                  final item = entry.value;
                  final qty = item['qty'] as int? ?? 1;
                  final name = item['name'] as String? ?? '';
                  final unitCents = item['unit_price_cents'] as int? ?? 0;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      border: i < items.length - 1 ? const Border(bottom: BorderSide(color: AppColors.border)) : null,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(8)),
                          child: Center(child: Text('$qty', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13))),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14))),
                        Text(eur(unitCents * qty), style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                      ],
                    ),
                  );
                }),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Σύνολο', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
                      Text(eur(totalCents), style: TextStyle(color: AppColors.lime, fontWeight: FontWeight.w800, fontSize: 16)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (['pending', 'paid', 'processing'].contains(status)) ...[
            const SizedBox(height: 20),
            const Text('Πορεία', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.all(16),
              child: _StatusTimeline(status: status),
            ),
          ],
        ],
      ),
    );
  }
}
