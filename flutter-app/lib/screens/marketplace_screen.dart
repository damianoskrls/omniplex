import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/ui_kit.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  List<Map<String, dynamic>> _products = [];
  bool _loading = true;
  String? _error;
  final Map<String, int> _cart = {};
  bool _ordering = false;
  Map<String, bool> _paymentMethods = {'cash': true, 'pickup': true};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = context.read<AuthService>().api;
      final results = await Future.wait([
        api.fetchMarketplaceProducts(),
        api.fetchMarketplaceSettings(),
      ]);
      final products = results[0] as List<Map<String, dynamic>>;
      final settings = results[1] as Map<String, dynamic>;
      final pm = settings['payment_methods'] as Map<String, dynamic>? ?? {};
      setState(() {
        _products = products;
        _paymentMethods = pm.map((k, v) => MapEntry(k, v == true));
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _cartTotal {
    int t = 0;
    for (final e in _cart.entries) {
      final p = _products.firstWhere((x) => x['id'] == e.key, orElse: () => {});
      t += ((p['price_cents'] as int? ?? 0) * e.value);
    }
    return t;
  }

  int get _cartItemCount => _cart.values.fold(0, (a, b) => a + b);

  void _add(String id) {
    final wasZero = (_cart[id] ?? 0) == 0;
    setState(() => _cart[id] = (_cart[id] ?? 0) + 1);
    if (wasZero && mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Προστέθηκε στο καλάθι'),
          duration: const Duration(seconds: 3),
          backgroundColor: AppColors.surface,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Καλάθι →',
            textColor: AppColors.lime,
            onPressed: _showCart,
          ),
        ),
      );
    }
  }

  void _remove(String id) => setState(() {
    final q = (_cart[id] ?? 0) - 1;
    if (q <= 0) _cart.remove(id); else _cart[id] = q;
  });

  Future<void> _placeOrder({
    required String paymentMethod,
    required String deliveryMethod,
    required String customerName,
    required String customerPhone,
    String? shippingAddress,
    String? notes,
  }) async {
    if (_cart.isEmpty) return;
    setState(() => _ordering = true);
    try {
      final api = context.read<AuthService>().api;
      final items = _cart.entries
          .map((e) => {'product_id': e.key, 'qty': e.value})
          .toList();
      await api.placeMarketplaceOrder(
        items,
        paymentMethod: paymentMethod,
        deliveryMethod: deliveryMethod,
        customerName: customerName,
        customerPhone: customerPhone,
        shippingAddress: shippingAddress,
        notes: notes,
      );
      setState(() => _cart.clear());
      if (mounted) {
        Navigator.pop(context); // close checkout sheet
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text('Παραγγελία καταχωρήθηκε! 🎉'),
            content: const Text('Θα λάβεις ειδοποίηση όταν είναι έτοιμη.'),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(backgroundColor: AppColors.lime, foregroundColor: AppColors.bg),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _ordering = false);
    }
  }

  String _eur(int cents) => '€${(cents / 100).toStringAsFixed(2)}';

  void _openProduct(Map<String, dynamic> product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ProductPage(
          product: product,
          qty: _cart[product['id']] ?? 0,
          onAdd: () { _add(product['id'] as String); setState(() {}); },
          onRemove: () { _remove(product['id'] as String); setState(() {}); },
          getQty: () => _cart[product['id']] ?? 0,
        ),
      ),
    );
  }

  void _showCart() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setInner) => _CartSheet(
          products: _products,
          cart: _cart,
          ordering: _ordering,
          paymentMethods: _paymentMethods,
          onAdd: (id) { _add(id); setInner(() {}); },
          onRemove: (id) { _remove(id); setInner(() {}); },
          onCheckout: (data) => _placeOrder(
            paymentMethod: data['payment_method'] as String,
            deliveryMethod: data['delivery_method'] as String,
            customerName: data['customer_name'] as String,
            customerPhone: data['customer_phone'] as String,
            shippingAddress: data['shipping_address'] as String?,
            notes: data['notes'] as String?,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Marketplace'),
        actions: [
          if (_cartItemCount > 0)
            GestureDetector(
              onTap: _showCart,
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.shopping_bag_outlined, color: AppColors.lime, size: 28),
                    Positioned(
                      right: -6, top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(color: AppColors.orange, shape: BoxShape.circle),
                        child: Text('$_cartItemCount',
                            style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.lime))
          : _error != null
              ? Center(child: Text(_error!))
              : _products.isEmpty
                  ? const EmptyState(
                      icon: Icons.storefront_outlined,
                      title: 'Δεν υπάρχουν προϊόντα',
                      subtitle: 'Το γυμναστήριο δεν έχει ανεβάσει προϊόντα ακόμα.',
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.lime,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                        itemCount: _products.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (ctx, i) => _ProductRow(
                          product: _products[i],
                          qty: _cart[_products[i]['id']] ?? 0,
                          onTap: () => _openProduct(_products[i]),
                          onAdd: () => _add(_products[i]['id'] as String),
                          onRemove: () => _remove(_products[i]['id'] as String),
                        ),
                      ),
                    ),
      bottomNavigationBar: _cartItemCount > 0
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: FilledButton.icon(
                  onPressed: _showCart,
                  icon: const Icon(Icons.shopping_bag_outlined),
                  label: Text('Καλάθι · ${_eur(_cartTotal)} ($_cartItemCount)'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.lime,
                    foregroundColor: AppColors.bg,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

// ── Product List Row ──────────────────────────────────────────────────────────

class _ProductRow extends StatelessWidget {
  const _ProductRow({
    required this.product, required this.qty,
    required this.onTap, required this.onAdd, required this.onRemove,
  });
  final Map<String, dynamic> product;
  final int qty;
  final VoidCallback onTap, onAdd, onRemove;

  String _eur(int cents) => '€${(cents / 100).toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final imageUrl = product['image_url'] as String?;
    final name = product['name'] as String? ?? '';
    final description = product['description'] as String?;
    final price = product['price_cents'] as int? ?? 0;
    final stock = product['stock'] as int?;
    final outOfStock = stock != null && stock <= 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: qty > 0 ? AppColors.lime.withValues(alpha: 0.5) : AppColors.border),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(15)),
              child: SizedBox(
                width: 90, height: 90,
                child: _NetworkImage(url: imageUrl),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    if (description != null && description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(description,
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ),
                    const SizedBox(height: 6),
                    if (outOfStock)
                      const Text('Εξαντλήθηκε',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary))
                    else
                      Text(_eur(price),
                          style: const TextStyle(color: AppColors.lime, fontWeight: FontWeight.w800, fontSize: 15)),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: outOfStock
                  ? const SizedBox.shrink()
                  : qty == 0
                      ? _CircleBtn(icon: Icons.add, onTap: onAdd)
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _CircleBtn(icon: Icons.remove, onTap: onRemove),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text('$qty',
                                  style: const TextStyle(fontWeight: FontWeight.w800,
                                      color: AppColors.lime, fontSize: 15)),
                            ),
                            _CircleBtn(icon: Icons.add, onTap: onAdd),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Full Product Page ─────────────────────────────────────────────────────────

class _ProductPage extends StatefulWidget {
  const _ProductPage({
    required this.product, required this.qty,
    required this.onAdd, required this.onRemove, required this.getQty,
  });
  final Map<String, dynamic> product;
  final int qty;
  final VoidCallback onAdd, onRemove;
  final int Function() getQty;

  @override
  State<_ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<_ProductPage> {
  Map<String, dynamic>? _full;
  bool _loading = true;
  int _imageIndex = 0;
  late int _qty;

  @override
  void initState() {
    super.initState();
    _qty = widget.qty;
    _fetchFull();
  }

  Future<void> _fetchFull() async {
    try {
      final api = context.read<AuthService>().api;
      final data = await api.fetchMarketplaceProduct(widget.product['id'] as String);
      if (mounted) setState(() { _full = data; _loading = false; });
    } on ApiException catch (_) {
      if (mounted) setState(() { _full = widget.product; _loading = false; });
    }
  }

  void _add() { widget.onAdd(); setState(() => _qty++); }
  void _remove() { if (_qty > 0) { widget.onRemove(); setState(() => _qty--); } }

  String _eur(int cents) => '€${(cents / 100).toStringAsFixed(2)}';

  List<String> get _images {
    final data = _full ?? widget.product;
    final imgs = data['images'];
    if (imgs is List && imgs.isNotEmpty) {
      return imgs.cast<String>();
    }
    final single = data['image_url'] as String?;
    if (single != null && single.isNotEmpty) return [single];
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final data = _full ?? widget.product;
    final name = data['name'] as String? ?? '';
    final description = data['description'] as String?;
    final category = data['category'] as String?;
    final price = data['price_cents'] as int? ?? 0;
    final stock = data['stock'] as int?;
    final sku = data['sku'] as String?;
    final weightGrams = data['weight_grams'];
    final notes = data['notes'] as String?;
    final ingredients = data['ingredients'] as String?;
    final usageInstructions = data['usage_instructions'] as String?;
    final outOfStock = stock != null && stock <= 0;
    final images = _images;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          // ── Image gallery header
          SliverAppBar(
            expandedHeight: images.isNotEmpty ? 300 : 80,
            pinned: true,
            backgroundColor: AppColors.bg,
            flexibleSpace: images.isNotEmpty
                ? FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        PageView.builder(
                          itemCount: images.length,
                          onPageChanged: (i) => setState(() => _imageIndex = i),
                          itemBuilder: (_, i) => _NetworkImage(url: images[i], fit: BoxFit.cover),
                        ),
                        if (images.length > 1)
                          Positioned(
                            bottom: 12,
                            left: 0, right: 0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(images.length, (i) => Container(
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                width: _imageIndex == i ? 20 : 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: _imageIndex == i ? AppColors.lime : Colors.white38,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              )),
                            ),
                          ),
                      ],
                    ),
                  )
                : null,
          ),

          // ── Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category chip
                  if (category != null && category.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: PillChip(
                        label: category,
                        color: AppColors.lime.withValues(alpha: 0.12),
                        textColor: AppColors.lime,
                      ),
                    ),

                  // Name + price
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(name,
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(width: 16),
                      Text(_eur(price),
                          style: const TextStyle(color: AppColors.lime, fontWeight: FontWeight.w900, fontSize: 24)),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Description
                  if (description != null && description.isNotEmpty) ...[
                    Text(description,
                        style: const TextStyle(fontSize: 15, height: 1.65, color: AppColors.textSecondary)),
                    const SizedBox(height: 20),
                  ],

                  // Info grid
                  if (stock != null || sku != null || weightGrams != null) ...[
                    _SectionTitle('Πληροφορίες'),
                    const SizedBox(height: 10),
                    _InfoGrid(items: [
                      if (stock != null)
                        _InfoItem(
                          icon: Icons.inventory_2_outlined,
                          label: 'Απόθεμα',
                          value: outOfStock ? 'Εξαντλήθηκε' : '$stock τεμ.',
                          valueColor: outOfStock ? AppColors.pink : null,
                        ),
                      if (sku != null && sku.isNotEmpty)
                        _InfoItem(icon: Icons.qr_code_outlined, label: 'SKU', value: sku),
                      if (weightGrams != null)
                        _InfoItem(
                          icon: Icons.scale_outlined,
                          label: 'Βάρος',
                          value: weightGrams is int && weightGrams >= 1000
                              ? '${(weightGrams / 1000).toStringAsFixed(1)} kg'
                              : '${weightGrams}g',
                        ),
                    ]),
                    const SizedBox(height: 20),
                  ],

                  // Ingredients
                  if (ingredients != null && ingredients.isNotEmpty) ...[
                    _SectionTitle('Συστατικά'),
                    const SizedBox(height: 8),
                    Text(ingredients,
                        style: const TextStyle(fontSize: 14, height: 1.6, color: AppColors.textSecondary)),
                    const SizedBox(height: 20),
                  ],

                  // Usage instructions
                  if (usageInstructions != null && usageInstructions.isNotEmpty) ...[
                    _SectionTitle('Οδηγίες χρήσης'),
                    const SizedBox(height: 8),
                    Text(usageInstructions,
                        style: const TextStyle(fontSize: 14, height: 1.6, color: AppColors.textSecondary)),
                    const SizedBox(height: 20),
                  ],

                  // Notes
                  if (notes != null && notes.isNotEmpty) ...[
                    _SectionTitle('Σημειώσεις'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(notes,
                          style: const TextStyle(fontSize: 14, height: 1.6, color: AppColors.textSecondary)),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Loading indicator while fetching full data
                  if (_loading)
                    const Center(child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(color: AppColors.lime),
                    )),
                ],
              ),
            ),
          ),
        ],
      ),

      // ── Sticky bottom: qty + add to cart
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border.withValues(alpha: 0.5))),
          ),
          child: outOfStock
              ? const Center(
                  child: Text('Εξαντλήθηκε',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 15)))
              : Row(
                  children: [
                    // Qty stepper
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.bg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _CircleBtn(icon: Icons.remove, onTap: _qty > 0 ? _remove : null, small: false),
                          SizedBox(
                            width: 36,
                            child: Text('$_qty',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          ),
                          _CircleBtn(icon: Icons.add, onTap: _add, small: false),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _add,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.lime,
                          foregroundColor: AppColors.bg,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          _qty == 0
                              ? 'Προσθήκη στο καλάθι'
                              : 'Προσθήκη · ${_eur(price * (_qty + 1))}',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ── Cart Sheet ────────────────────────────────────────────────────────────────

class _CartSheet extends StatefulWidget {
  const _CartSheet({
    required this.products, required this.cart, required this.ordering,
    required this.paymentMethods,
    required this.onAdd, required this.onRemove, required this.onCheckout,
  });
  final List<Map<String, dynamic>> products;
  final Map<String, int> cart;
  final bool ordering;
  final Map<String, bool> paymentMethods;
  final void Function(String) onAdd, onRemove;
  final void Function(Map<String, dynamic>) onCheckout;

  @override
  State<_CartSheet> createState() => _CartSheetState();
}

class _CartSheetState extends State<_CartSheet> {
  bool _showCheckout = false;
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _deliveryMethod = 'pickup';
  String? _paymentMethod;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    // Pre-fill from auth if available
    final auth = context.read<AuthService>();
    if (auth.isLoggedIn) {
      _nameCtrl.text = auth.user?.fullName ?? '';
      _phoneCtrl.text = auth.user?.phone ?? '';
    }
    // Set default payment method to first enabled one
    final enabled = widget.paymentMethods.entries.where((e) => e.value).toList();
    if (enabled.isNotEmpty) _paymentMethod = enabled.first.key;
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _phoneCtrl.dispose();
    _addressCtrl.dispose(); _notesCtrl.dispose();
    super.dispose();
  }

  String _eur(int cents) => '€${(cents / 100).toStringAsFixed(2)}';

  int get _total {
    int t = 0;
    for (final e in widget.cart.entries) {
      final p = widget.products.firstWhere((x) => x['id'] == e.key, orElse: () => {});
      t += ((p['price_cents'] as int? ?? 0) * e.value);
    }
    return t;
  }

  String _paymentLabel(String key) {
    switch (key) {
      case 'cash': return 'Μετρητά';
      case 'card': return 'Κάρτα';
      case 'pickup': return 'Παραλαβή από κατάστημα';
      case 'stripe': return 'Online πληρωμή';
      case 'bank': return 'Τραπεζική μεταφορά';
      default: return key;
    }
  }

  IconData _paymentIcon(String key) {
    switch (key) {
      case 'cash': return Icons.payments_outlined;
      case 'card': return Icons.credit_card_outlined;
      case 'pickup': return Icons.store_outlined;
      case 'stripe': return Icons.credit_card;
      case 'bank': return Icons.account_balance_outlined;
      default: return Icons.payment;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: _showCheckout ? _buildCheckout() : _buildCartList(),
    );
  }

  Widget _buildCartList() {
    final items = widget.cart.entries
        .map((e) => MapEntry(widget.products.firstWhere((p) => p['id'] == e.key, orElse: () => {}), e.value))
        .where((e) => e.key.isNotEmpty)
        .toList();

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).padding.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
          )),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('Καλάθι', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const Spacer(),
              const Icon(Icons.shopping_bag_outlined, color: AppColors.lime),
            ],
          ),
          const SizedBox(height: 16),
          ...items.map((e) {
            final product = e.key;
            final qty = e.value;
            final price = product['price_cents'] as int? ?? 0;
            final imageUrl = product['image_url'] as String?;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(width: 52, height: 52, child: _NetworkImage(url: imageUrl)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(product['name'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(_eur(price), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _CircleBtn(icon: Icons.remove, onTap: () => widget.onRemove(product['id'] as String)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text('$qty', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.lime, fontSize: 15)),
                      ),
                      _CircleBtn(icon: Icons.add, onTap: () => widget.onAdd(product['id'] as String)),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Text(_eur(price * qty), style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.lime)),
                ],
              ),
            );
          }),
          const Divider(height: 24),
          Row(
            children: [
              const Text('Σύνολο', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const Spacer(),
              Text(_eur(_total), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: AppColors.lime)),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => setState(() => _showCheckout = true),
              icon: const Icon(Icons.arrow_forward),
              label: Text('Συνέχεια · ${_eur(_total)}'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.lime,
                foregroundColor: AppColors.bg,
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckout() {
    final enabledPayments = widget.paymentMethods.entries.where((e) => e.value).toList();

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).padding.bottom + 24),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
              )),
              const SizedBox(height: 16),
              Row(
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _showCheckout = false),
                    child: const Icon(Icons.arrow_back_ios, size: 18, color: AppColors.textSecondary),
                  ),
                  const SizedBox(width: 8),
                  Text('Ολοκλήρωση', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const Spacer(),
                  Text(_eur(_total), style: const TextStyle(color: AppColors.lime, fontWeight: FontWeight.w900, fontSize: 18)),
                ],
              ),
              const SizedBox(height: 24),

              // Contact info
              _SectionTitle('Στοιχεία επικοινωνίας'),
              const SizedBox(height: 10),
              TextFormField(
                controller: _nameCtrl,
                decoration: _inputDecoration('Ονοματεπώνυμο', Icons.person_outline),
                validator: (v) => v == null || v.trim().isEmpty ? 'Απαιτείται' : null,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _phoneCtrl,
                decoration: _inputDecoration('Τηλέφωνο', Icons.phone_outlined),
                keyboardType: TextInputType.phone,
                validator: (v) => v == null || v.trim().isEmpty ? 'Απαιτείται' : null,
              ),
              const SizedBox(height: 24),

              // Delivery method
              _SectionTitle('Τρόπος παραλαβής'),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _DeliveryOption(
                    icon: Icons.store_outlined,
                    label: 'Από το κατάστημα',
                    selected: _deliveryMethod == 'pickup',
                    onTap: () => setState(() { _deliveryMethod = 'pickup'; }),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: _DeliveryOption(
                    icon: Icons.local_shipping_outlined,
                    label: 'Αποστολή',
                    selected: _deliveryMethod == 'delivery',
                    onTap: () => setState(() { _deliveryMethod = 'delivery'; }),
                  )),
                ],
              ),
              if (_deliveryMethod == 'delivery') ...[
                const SizedBox(height: 10),
                TextFormField(
                  controller: _addressCtrl,
                  decoration: _inputDecoration('Διεύθυνση αποστολής', Icons.location_on_outlined),
                  validator: (v) => _deliveryMethod == 'delivery' && (v == null || v.trim().isEmpty) ? 'Απαιτείται' : null,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ],
              const SizedBox(height: 24),

              // Payment method
              if (enabledPayments.isNotEmpty) ...[
                _SectionTitle('Τρόπος πληρωμής'),
                const SizedBox(height: 10),
                ...enabledPayments.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _paymentMethod = e.key),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: _paymentMethod == e.key ? AppColors.lime.withValues(alpha: 0.12) : AppColors.bg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _paymentMethod == e.key ? AppColors.lime : AppColors.border,
                          width: _paymentMethod == e.key ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(_paymentIcon(e.key), color: _paymentMethod == e.key ? AppColors.lime : AppColors.textSecondary, size: 20),
                          const SizedBox(width: 12),
                          Text(_paymentLabel(e.key), style: TextStyle(
                            fontWeight: _paymentMethod == e.key ? FontWeight.w700 : FontWeight.w500,
                            color: _paymentMethod == e.key ? AppColors.lime : AppColors.textPrimary,
                          )),
                          const Spacer(),
                          if (_paymentMethod == e.key)
                            const Icon(Icons.check_circle, color: AppColors.lime, size: 20),
                        ],
                      ),
                    ),
                  ),
                )),
                const SizedBox(height: 16),
              ],

              // Notes
              TextFormField(
                controller: _notesCtrl,
                decoration: _inputDecoration('Σημειώσεις παραγγελίας (προαιρετικό)', Icons.notes_outlined),
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 24),

              // Order summary
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Text('Σύνολο παραγγελίας', style: TextStyle(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text(_eur(_total), style: const TextStyle(color: AppColors.lime, fontWeight: FontWeight.w900, fontSize: 20)),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: widget.ordering ? null : _submit,
                  icon: widget.ordering
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bg))
                      : const Icon(Icons.check_circle_outline),
                  label: Text(widget.ordering ? 'Υποβολή...' : 'Υποβολή παραγγελίας'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.lime,
                    foregroundColor: AppColors.bg,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_paymentMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Επίλεξε τρόπο πληρωμής')));
      return;
    }
    widget.onCheckout({
      'payment_method': _paymentMethod!,
      'delivery_method': _deliveryMethod,
      'customer_name': _nameCtrl.text.trim(),
      'customer_phone': _phoneCtrl.text.trim(),
      'shipping_address': _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
      'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    });
  }

  InputDecoration _inputDecoration(String hint, IconData icon) => InputDecoration(
    hintText: hint,
    prefixIcon: Icon(icon, size: 18, color: AppColors.textSecondary),
    filled: true,
    fillColor: AppColors.bg,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.lime, width: 1.5)),
    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.pink)),
    focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.pink, width: 1.5)),
    hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
  );
}

class _DeliveryOption extends StatelessWidget {
  const _DeliveryOption({required this.icon, required this.label, required this.selected, required this.onTap});
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.lime.withValues(alpha: 0.12) : AppColors.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? AppColors.lime : AppColors.border, width: selected ? 1.5 : 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? AppColors.lime : AppColors.textSecondary, size: 22),
            const SizedBox(height: 6),
            Text(label, textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: selected ? AppColors.lime : AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

// ── Section helpers ───────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800));
}

class _InfoItem {
  _InfoItem({required this.icon, required this.label, required this.value, this.valueColor});
  final IconData icon;
  final String label, value;
  final Color? valueColor;
}

class _InfoGrid extends StatelessWidget {
  const _InfoGrid({required this.items});
  final List<_InfoItem> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10, runSpacing: 10,
      children: items.map((item) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(item.icon, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.label,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                Text(item.value,
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13,
                        color: item.valueColor ?? AppColors.textPrimary)),
              ],
            ),
          ],
        ),
      )).toList(),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

class _CircleBtn extends StatelessWidget {
  const _CircleBtn({required this.icon, required this.onTap, this.small = true});
  final IconData icon;
  final VoidCallback? onTap;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final size = small ? 28.0 : 36.0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(
          color: onTap != null
              ? AppColors.lime.withValues(alpha: 0.15)
              : AppColors.border.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(small ? 8 : 10),
        ),
        child: Icon(icon, size: small ? 16 : 20,
            color: onTap != null ? AppColors.lime : AppColors.textSecondary),
      ),
    );
  }
}

class _NetworkImage extends StatelessWidget {
  const _NetworkImage({this.url, this.fit = BoxFit.cover});
  final String? url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) return _placeholder();
    return Image.network(
      url!,
      fit: fit,
      loadingBuilder: (_, child, progress) => progress == null
          ? child
          : Container(color: AppColors.bg,
              child: const Center(child: CircularProgressIndicator(color: AppColors.lime, strokeWidth: 2))),
      errorBuilder: (_, __, ___) => _placeholder(),
    );
  }

  Widget _placeholder() => Container(
    color: AppColors.bg,
    child: const Center(child: Icon(Icons.storefront_outlined, size: 28, color: AppColors.border)),
  );
}
