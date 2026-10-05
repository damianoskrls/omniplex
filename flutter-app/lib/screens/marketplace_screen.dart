import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import '../services/stripe_checkout.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../l10n/tr.dart';


class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _products = [];
  Map<String, dynamic> _settings = {};
  String _query = '';
  String _category = tr('Όλα');
  final Map<String, int> _cart = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = context.read<AuthService>().api;
      final products = await api.fetchMarketplaceProducts();
      Map<String, dynamic> settings = {};
      try { settings = await api.fetchMarketplaceSettings(); } catch (_) {}
      if (!mounted) return;
      setState(() {
        _products = products;
        _settings = settings;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : tr('Δεν φορτώθηκε το κατάστημα');
        _loading = false;
      });
    }
  }

  int get _cartCount => _cart.values.fold(0, (sum, n) => sum + n);

  List<String> get _categories {
    final names = _products
        .map((p) => (p['category'] as String?)?.trim() ?? '')
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return [tr('Όλα'), ...names];
  }

  List<Map<String, dynamic>> get _visible {
    final q = _query.trim().toLowerCase();
    return _products.where((p) {
      final cat = (p['category'] as String?)?.trim() ?? '';
      if (_category != 'Όλα' && cat != _category) return false;
      if (q.isEmpty) return true;
      final name = (p['name'] as String? ?? '').toLowerCase();
      final desc = (p['description'] as String? ?? '').toLowerCase();
      return name.contains(q) || desc.contains(q);
    }).toList();
  }

  void _add(Map<String, dynamic> product, {int qty = 1}) {
    final id = product['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final stock = product['stock'];
    final next = (_cart[id] ?? 0) + qty;
    if (stock is num && next > stock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Δεν υπάρχει άλλο απόθεμα'))),
      );
      return;
    }
    setState(() => _cart[id] = next);
  }

  void _setQty(String id, int qty) {
    setState(() {
      if (qty <= 0) {
        _cart.remove(id);
      } else {
        _cart[id] = qty;
      }
    });
  }

  Map<String, dynamic>? _productById(String id) {
    for (final p in _products) {
      if (p['id']?.toString() == id) return p;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.tenantPrimary;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(tr('Κατάστημα'), style: GoogleFonts.inter(
                      color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                  ),
                  IconButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const _MyOrdersPage(),
                    )),
                    icon: const Icon(Icons.receipt_long_outlined, color: Colors.white),
                  ),
                  IconButton(
                    onPressed: _cart.isEmpty ? null : () => _openCart(accent),
                    icon: Badge(
                      isLabelVisible: _cartCount > 0,
                      label: Text('$_cartCount'),
                      child: const Icon(Icons.shopping_bag_outlined, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _body(accent)),
          ],
        ),
      ),
    );
  }

  Widget _body(Color accent) {
    if (_loading) return Center(child: CircularProgressIndicator(color: accent));
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(tr(_error!), textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: Text(tr('Ξανά'))),
            ],
          ),
        ),
      );
    }
    final items = _visible;
    return RefreshIndicator(
      color: accent,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
        children: [
          TextField(
            onChanged: (v) => setState(() => _query = v),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: tr('Αναζήτηση προϊόντος'),
              hintStyle: const TextStyle(color: AppColors.textSecondary),
              prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final name = _categories[i];
                final on = name == _category;
                return GestureDetector(
                  onTap: () => setState(() => _category = name),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: on ? accent : AppColors.surface,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(tr(name), style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: on ? AppColors.onFill(accent) : AppColors.textSecondary)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          if (items.isEmpty)
            Padding(
              padding: EdgeInsets.only(top: 48),
              child: Text(tr('Δεν υπάρχουν προϊόντα'), textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary)),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.68,
              ),
              itemCount: items.length,
              itemBuilder: (_, i) => _card(items[i], accent),
            ),
        ],
      ),
    );
  }

  Widget _card(Map<String, dynamic> product, Color accent) {
    final stock = product['stock'];
    final out = stock is num && stock <= 0;
    return GestureDetector(
      onTap: () => _openProduct(product, accent),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _photo(product['image_url'] as String?)),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr(product['name']?.toString() ?? ''), maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(child: Text(tr(_eur(product['price_cents'])),
                        style: GoogleFonts.inter(color: accent, fontWeight: FontWeight.w800))),
                      if (out)
                        Text(tr('Εξαντλήθηκε'), style: TextStyle(color: AppColors.textSecondary, fontSize: 11))
                      else
                        GestureDetector(
                          onTap: () => _add(product),
                          child: CircleAvatar(
                            radius: 14,
                            backgroundColor: accent,
                            child: Icon(Icons.add, size: 16, color: AppColors.onFill(accent)),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photo(String? url) {
    if (url == null || url.isEmpty) {
      return const ColoredBox(
        color: Color(0xFF121214),
        child: Center(child: Icon(Icons.inventory_2_outlined, color: AppColors.textSecondary)),
      );
    }
    return Image.network(url, fit: BoxFit.cover, width: double.infinity,
      errorBuilder: (context, error, stack) => const ColoredBox(
        color: Color(0xFF121214),
        child: Center(child: Icon(Icons.broken_image_outlined, color: AppColors.textSecondary)),
      ));
  }

  void _openProduct(Map<String, dynamic> product, Color accent) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        var qty = 1;
        final stock = product['stock'];
        final out = stock is num && stock <= 0;
        return StatefulBuilder(builder: (ctx, setLocal) {
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.viewInsetsOf(ctx).bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(height: 180, width: double.infinity, child: _photo(product['image_url'] as String?)),
                ),
                const SizedBox(height: 14),
                Text(tr(product['name']?.toString() ?? ''), style: GoogleFonts.inter(
                  color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(tr(_eur(product['price_cents'])), style: GoogleFonts.inter(
                  color: accent, fontSize: 18, fontWeight: FontWeight.w800)),
                if ((product['description'] as String?)?.isNotEmpty == true) ...[
                  const SizedBox(height: 10),
                  Text(tr(product['description'].toString()), style: const TextStyle(color: AppColors.textSecondary)),
                ],
                if ((product['ingredients'] as String?)?.isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  Text(tr('Συστατικά: ${product['ingredients']}'), style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                ],
                if ((product['usage_instructions'] as String?)?.isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  Text(tr(product['usage_instructions'].toString()), style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    _qtyButton(Icons.remove, () { if (qty > 1) setLocal(() => qty--); }),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(tr('$qty'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                    ),
                    _qtyButton(Icons.add, () {
                      if (stock is num && qty >= stock) return;
                      setLocal(() => qty++);
                    }),
                    const Spacer(),
                    FilledButton(
                      onPressed: out ? null : () {
                        _add(product, qty: qty);
                        Navigator.pop(ctx);
                      },
                      style: FilledButton.styleFrom(backgroundColor: accent, foregroundColor: AppColors.onFill(accent)),
                      child: Text(tr(out ? 'Εξαντλήθηκε' : tr('Στο καλάθι'))),
                    ),
                  ],
                ),
              ],
            ),
          );
        });
      },
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }

  void _openCart(Color accent) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
        final lines = _cart.entries.map((e) => (e.key, e.value, _productById(e.key))).where((e) => e.$3 != null).toList();
        var cents = 0;
        for (final line in lines) {
          cents += ((line.$3!['price_cents'] as num?)?.toInt() ?? 0) * line.$2;
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(tr('Καλάθι'), style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              for (final line in lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(child: Text(tr(line.$3!['name']?.toString() ?? ''), style: const TextStyle(color: Colors.white))),
                      _qtyButton(Icons.remove, () { _setQty(line.$1, line.$2 - 1); setSheet(() {}); }),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(tr('${line.$2}'), style: const TextStyle(color: Colors.white)),
                      ),
                      _qtyButton(Icons.add, () { _add(line.$3!); setSheet(() {}); }),
                    ],
                  ),
                ),
              const Divider(color: AppColors.border),
              Row(
                children: [
                  Text(tr('Σύνολο'), style: TextStyle(color: AppColors.textSecondary)),
                  const Spacer(),
                  Text(tr(_eur(cents)), style: TextStyle(color: accent, fontWeight: FontWeight.w800, fontSize: 18)),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: lines.isEmpty ? null : () {
                    Navigator.pop(ctx);
                    _openCheckout(accent, cents);
                  },
                  style: FilledButton.styleFrom(backgroundColor: accent, foregroundColor: AppColors.onFill(accent)),
                  child: Text(tr('Ολοκλήρωση')),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  void _openCheckout(Color accent, int subtotal) {
    final user = context.read<AuthService>().user;
    final name = TextEditingController(text: user?.fullName ?? '');
    final phone = TextEditingController(text: user?.phone ?? '');
    final address = TextEditingController();
    final notes = TextEditingController();
    final methods = _enabledMethods();
    var method = methods.isEmpty ? 'cash' : methods.first;
    final shipping = _settings['shipping'] is Map ? Map<String, dynamic>.from(_settings['shipping'] as Map) : <String, dynamic>{};
    final shipOn = shipping['enabled'] == true;
    var delivery = 'pickup';
    var busy = false;

    int shippingCents() {
      if (delivery != 'shipping') return 0;
      final rate = (shipping['flat_rate_cents'] as num?)?.toInt() ?? 0;
      final threshold = (shipping['free_threshold_cents'] as num?)?.toInt() ?? 0;
      if (threshold > 0 && subtotal >= threshold) return 0;
      return rate;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) {
        final total = subtotal + shippingCents();
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.viewInsetsOf(ctx).bottom),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('Παραγγελία'), style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                _field(name, tr('Ονοματεπώνυμο')),
                _field(phone, tr('Τηλέφωνο'), type: TextInputType.phone),
                const SizedBox(height: 8),
                Text(tr('Παραλαβή'), style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                RadioListTile<String>(
                  value: 'pickup', groupValue: delivery, activeColor: accent,
                  title: Text(tr('Παραλαβή από το γυμναστήριο'), style: TextStyle(color: Colors.white, fontSize: 14)),
                  onChanged: (v) => setLocal(() => delivery = v!),
                ),
                if (shipOn)
                  RadioListTile<String>(
                    value: 'shipping', groupValue: delivery, activeColor: accent,
                    title: Text(tr('Αποστολή · ${_eur(shippingCents())}'), style: const TextStyle(color: Colors.white, fontSize: 14)),
                    subtitle: (shipping['estimated_days'] ?? '').toString().isEmpty
                        ? null
                        : Text(tr('Παράδοση ${shipping['estimated_days']}'), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    onChanged: (v) => setLocal(() => delivery = v!),
                  ),
                if (delivery == 'shipping') _field(address, tr('Διεύθυνση')),
                const SizedBox(height: 8),
                Text(tr('Πληρωμή'), style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                for (final key in (methods.isEmpty ? ['cash'] : methods))
                  RadioListTile<String>(
                    value: key, groupValue: method, activeColor: accent,
                    title: Text(_methodLabel(key), style: const TextStyle(color: Colors.white, fontSize: 14)),
                    onChanged: (v) => setLocal(() => method = v!),
                  ),
                _field(notes, tr('Σημειώσεις')),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(tr('Πληρωτέο'), style: TextStyle(color: AppColors.textSecondary)),
                    const Spacer(),
                    Text(tr(_eur(total)), style: TextStyle(color: accent, fontWeight: FontWeight.w800, fontSize: 18)),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: busy ? null : () async {
                      if (name.text.trim().isEmpty || phone.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Συμπλήρωσε όνομα και τηλέφωνο'))));
                        return;
                      }
                      setLocal(() => busy = true);
                      final ok = await _place(
                        method: method,
                        delivery: delivery,
                        name: name.text.trim(),
                        phone: phone.text.trim(),
                        address: address.text.trim(),
                        notes: notes.text.trim(),
                      );
                      if (!ctx.mounted) return;
                      setLocal(() => busy = false);
                      if (ok) Navigator.pop(ctx);
                    },
                    style: FilledButton.styleFrom(backgroundColor: accent, foregroundColor: AppColors.onFill(accent)),
                    child: Text(tr(busy ? 'Αποστολή…' : tr('Καταχώρηση'))),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _field(TextEditingController c, String label, {TextInputType? type}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        keyboardType: type,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: tr(label),
          labelStyle: const TextStyle(color: AppColors.textSecondary),
          filled: true,
          fillColor: const Color(0xFF121214),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  List<String> _enabledMethods() {
    final raw = _settings['payment_methods'];
    if (raw is! Map) return ['cash', 'card'];
    const order = ['cash', 'card', 'bank_transfer', 'stripe'];
    return order.where((k) => raw[k] == true).toList();
  }

  String _methodLabel(String key) {
    switch (key) {
      case 'card': return tr('Κάρτα στο κατάστημα');
      case 'stripe': return tr('Κάρτα online');
      case 'bank_transfer': return tr('Τραπεζική κατάθεση');
      default: return tr('Μετρητά στο κατάστημα');
    }
  }

  Future<bool> _place({
    required String method,
    required String delivery,
    required String name,
    required String phone,
    required String address,
    required String notes,
  }) async {
    try {
      final api = context.read<AuthService>().api;
      final items = _cart.entries.map((e) => {'product_id': e.key, 'qty': e.value}).toList();
      final result = await api.placeMarketplaceOrder(
        items,
        notes: notes,
        paymentMethod: method,
        customerName: name,
        customerPhone: phone,
        shippingAddress: delivery == 'shipping' ? address : null,
        deliveryMethod: delivery,
      );
      final payment = result['payment'];
      if (payment is Map && payment['client_secret'] != null) {
        await presentCardPaymentSheet(
          publishableKey: payment['publishable_key']?.toString() ?? '',
          clientSecret: payment['client_secret'].toString(),
          merchantDisplayName: 'OmniPlex',
        );
      }
      if (!mounted) return true;
      setState(_cart.clear);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Η παραγγελία καταχωρήθηκε'))),
      );
      return true;
    } on StripeException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(e.error.localizedMessage ?? tr('Η πληρωμή ακυρώθηκε. Η παραγγελία έμεινε σε εκκρεμότητα.')))),
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(e is ApiException ? e.message : tr('Η παραγγελία δεν καταχωρήθηκε')))),
        );
      }
      return false;
    }
  }
}

class _MyOrdersPage extends StatefulWidget {
  const _MyOrdersPage();

  @override
  State<_MyOrdersPage> createState() => _MyOrdersPageState();
}

class _MyOrdersPageState extends State<_MyOrdersPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _orders = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final rows = await context.read<AuthService>().api.fetchMyMarketplaceOrders();
      if (!mounted) return;
      setState(() { _orders = rows; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : tr('Δεν φορτώθηκαν οι παραγγελίες');
        _loading = false;
      });
    }
  }

  String _status(String? raw) {
    switch (raw) {
      case 'paid': return tr('Πληρώθηκε');
      case 'processing': return tr('Σε επεξεργασία');
      case 'fulfilled': return tr('Παραδόθηκε');
      case 'cancelled': return tr('Ακυρώθηκε');
      case 'refunded': return tr('Επιστράφηκε');
      default: return tr('Εκκρεμεί');
    }
  }

  List<Map<String, dynamic>> _items(dynamic raw) {
    dynamic value = raw;
    if (value is String && value.isNotEmpty) {
      try { value = jsonDecode(value); } catch (_) { return []; }
    }
    if (value is! List) return [];
    return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.tenantPrimary;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: Colors.white,
        title: Text(tr('Οι παραγγελίες μου')),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: accent))
          : _error != null
              ? Center(child: Text(tr(_error!), style: const TextStyle(color: AppColors.textSecondary)))
              : _orders.isEmpty
                  ? Center(child: Text(tr('Δεν έχεις παραγγελίες'), style: TextStyle(color: AppColors.textSecondary)))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _orders.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final order = _orders[i];
                        final lines = _items(order['items']);
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(tr(_status(order['status']?.toString())),
                                    style: TextStyle(color: accent, fontWeight: FontWeight.w800)),
                                  const Spacer(),
                                  Text(tr(_eur(order['total_cents'])), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              for (final line in lines)
                                Text(tr('${line['qty'] ?? 1} × ${line['name'] ?? ''}'),
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}

String _eur(dynamic cents) {
  final n = (cents is num) ? cents.toInt() : int.tryParse('$cents') ?? 0;
  return '€${(n / 100).toStringAsFixed(2)}';
}
