import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/booking.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/ui_kit.dart';
import 'dropin_confirm_screen.dart';

class DropinScreen extends StatefulWidget {
  const DropinScreen({super.key});

  @override
  State<DropinScreen> createState() => _DropinScreenState();
}

class _DropinScreenState extends State<DropinScreen> {
  List<Map<String, dynamic>> _services = [];
  bool _loadingServices = true;
  String? _selectedServiceId;
  Map<String, dynamic>? _selectedService;

  DateTime _selectedDate = DateTime.now();
  List<TimeSlot> _slots = [];
  bool _loadingSlots = false;
  String? _slotsMessage;

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices() async {
    setState(() => _loadingServices = true);
    try {
      final api = context.read<AuthService>().api;
      final svcs = await api.fetchDropinServices();
      setState(() {
        _services = svcs;
        if (svcs.isNotEmpty) {
          _selectedService = svcs.first;
          _selectedServiceId = svcs.first['id'] as String;
        }
      });
      if (_selectedServiceId != null) await _loadSlots();
    } catch (e) {
      if (mounted) _showError('$e');
    } finally {
      if (mounted) setState(() => _loadingServices = false);
    }
  }

  Future<void> _loadSlots() async {
    if (_selectedServiceId == null) return;
    setState(() { _loadingSlots = true; _slots = []; _slotsMessage = null; });
    try {
      final api = context.read<AuthService>().api;
      final dateStr = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2,'0')}-${_selectedDate.day.toString().padLeft(2,'0')}';
      final result = await api.fetchSlots(serviceId: _selectedServiceId!, date: dateStr);
      setState(() {
        _slots = result.slots;
        _slotsMessage = result.message;
      });
    } catch (_) {
      setState(() => _slotsMessage = 'Δεν ήταν δυνατή η φόρτωση ωρών');
    } finally {
      if (mounted) setState(() => _loadingSlots = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  String _fmtDate(DateTime d) {
    const days = ['Δευ', 'Τρι', 'Τετ', 'Πεμ', 'Παρ', 'Σαβ', 'Κυρ'];
    const months = ['Ιαν','Φεβ','Μαρ','Απρ','Μαΐ','Ιουν','Ιουλ','Αυγ','Σεπ','Οκτ','Νοε','Δεκ'];
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) return 'Σήμερα';
    final tom = now.add(const Duration(days: 1));
    if (d.year == tom.year && d.month == tom.month && d.day == tom.day) return 'Αύριο';
    return '${days[d.weekday - 1]} ${d.day} ${months[d.month - 1]}';
  }

  int _dropin(Map<String, dynamic> s) => (s['drop_in_price_cents'] as num?)?.toInt() ?? 0;
  String _priceStr(int cents) => '${(cents / 100).toStringAsFixed(2)} €';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Drop-in', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('Κλείσε μία συνεδρία χωρίς συνδρομή', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ),
            const SizedBox(height: 16),

            if (_loadingServices)
              const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.lime)))
            else if (_services.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bolt_outlined, size: 48, color: AppColors.textSecondary),
                      const SizedBox(height: 12),
                      Text('Δεν υπάρχουν διαθέσιμα drop-in μαθήματα', style: TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              )
            else ...[
              // Service chips
              SizedBox(
                height: 38,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  itemCount: _services.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final s = _services[i];
                    final selected = s['id'] == _selectedServiceId;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedService = s;
                          _selectedServiceId = s['id'] as String;
                        });
                        _loadSlots();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected ? AppColors.lime : AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: selected ? AppColors.lime : AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Text(
                              s['name'] as String? ?? '',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: selected ? Colors.black : AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: selected ? Colors.black.withValues(alpha: 0.15) : AppColors.border,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                _priceStr(_dropin(s)),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: selected ? Colors.black : AppColors.lime,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Date tabs
              SizedBox(
                height: 60,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  itemCount: 8,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final d = DateTime.now().add(Duration(days: i));
                    final selected = _selectedDate.year == d.year && _selectedDate.month == d.month && _selectedDate.day == d.day;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedDate = d);
                        _loadSlots();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: selected ? AppColors.lime : AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: selected ? AppColors.lime : AppColors.border),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${d.day}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: selected ? Colors.black : AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              _fmtDate(d).split(' ').first.length <= 4 ? _fmtDate(d).split(' ').first : _fmtDate(d).substring(0, 3),
                              style: TextStyle(fontSize: 10, color: selected ? Colors.black87 : AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 4),

              // Service info row
              if (_selectedService != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.access_time_rounded, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        '${_selectedService!['duration_mins']} λεπτά',
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.bolt_rounded, size: 14, color: AppColors.lime),
                      const SizedBox(width: 4),
                      Text(
                        _priceStr(_dropin(_selectedService!)) + ' / συνεδρία',
                        style: const TextStyle(fontSize: 13, color: AppColors.lime, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),

              // Time slots
              Expanded(
                child: _loadingSlots
                  ? const Center(child: CircularProgressIndicator(color: AppColors.lime, strokeWidth: 2))
                  : _slots.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            _slotsMessage ?? 'Δεν υπάρχουν διαθέσιμες ώρες για αυτή την ημέρα',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                        itemCount: _slots.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final slot = _slots[i];
                          final full = slot.isFull;
                          final spots = slot.remainingSpots;
                          return _SlotCard(
                            slot: slot,
                            price: _priceStr(_dropin(_selectedService!)),
                            isFull: full,
                            remainingSpots: spots,
                            onBook: full ? null : () => _openBookSheet(slot),
                          );
                        },
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openBookSheet(TimeSlot slot) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DropinBookSheet(
        slot: slot,
        service: _selectedService!,
        date: _selectedDate,
        onBooked: (booking) {
          Navigator.pop(context); // close sheet
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => DropinConfirmScreen(booking: booking)),
          );
        },
      ),
    );
  }
}

class _SlotCard extends StatelessWidget {
  const _SlotCard({
    required this.slot,
    required this.price,
    required this.isFull,
    required this.remainingSpots,
    required this.onBook,
  });

  final TimeSlot slot;
  final String price;
  final bool isFull;
  final int? remainingSpots;
  final VoidCallback? onBook;

  @override
  Widget build(BuildContext context) {
    final staffName = slot.availableStaff.isNotEmpty ? slot.availableStaff.first.fullName : null;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isFull ? AppColors.border : AppColors.border),
      ),
      child: InkWell(
        onTap: onBook,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: isFull ? AppColors.border : AppColors.lime.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    slot.time,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isFull ? AppColors.textSecondary : AppColors.lime,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (staffName != null)
                      Text(staffName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    if (remainingSpots != null)
                      Text(
                        isFull ? 'Πλήρης' : '$remainingSpots θέσεις',
                        style: TextStyle(fontSize: 12, color: isFull ? Colors.red[400] : AppColors.textSecondary),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isFull ? AppColors.border : AppColors.lime,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      price,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isFull ? AppColors.textSecondary : Colors.black,
                      ),
                    ),
                  ),
                  if (!isFull)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text('Κράτηση →', style: TextStyle(fontSize: 11, color: AppColors.lime)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DropinBookSheet extends StatefulWidget {
  const _DropinBookSheet({
    required this.slot,
    required this.service,
    required this.date,
    required this.onBooked,
  });

  final TimeSlot slot;
  final Map<String, dynamic> service;
  final DateTime date;
  final void Function(Map<String, dynamic>) onBooked;

  @override
  State<_DropinBookSheet> createState() => _DropinBookSheetState();
}

class _DropinBookSheetState extends State<_DropinBookSheet> {
  final _nameCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  String _payMethod = 'venue';
  bool _loading = false;
  String? _error;

  bool get _isLoggedIn => context.read<AuthService>().isLoggedIn;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  int get _priceCents => (widget.service['drop_in_price_cents'] as num?)?.toInt() ?? 0;
  String get _priceStr => '${(_priceCents / 100).toStringAsFixed(2)} €';

  Future<void> _book() async {
    if (!_isLoggedIn && _nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Απαιτείται όνομα');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final auth = context.read<AuthService>();
      final api  = auth.api;
      final dateStr = '${widget.date.year}-${widget.date.month.toString().padLeft(2,'0')}-${widget.date.day.toString().padLeft(2,'0')}';
      final staffId = widget.slot.availableStaff.isNotEmpty ? widget.slot.availableStaff.first.id : null;

      final booking = await api.createDropinBooking(
        serviceId: widget.service['id'] as String,
        date: dateStr,
        time: widget.slot.time,
        paymentMethod: _payMethod,
        staffId: staffId,
        guestName: _isLoggedIn ? null : _nameCtrl.text.trim(),
        guestEmail: _isLoggedIn ? null : (_emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim()),
        guestPhone: _isLoggedIn ? null : (_phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim()),
      );
      widget.onBooked(booking);
    } catch (e) {
      setState(() => _error = e is ApiException ? e.message : '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomPad),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            // Class info
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.service['name'] as String? ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.slot.time} · ${_shortDate(widget.date)}',
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: AppColors.lime, borderRadius: BorderRadius.circular(12)),
                  child: Text(_priceStr, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black)),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Guest form (only if not logged in)
            if (!_isLoggedIn) ...[
              const Text('Στοιχεία', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              _inputField(_nameCtrl, 'Ονοματεπώνυμο *', Icons.person_outline),
              const SizedBox(height: 8),
              _inputField(_phoneCtrl, 'Τηλέφωνο', Icons.phone_outlined),
              const SizedBox(height: 8),
              _inputField(_emailCtrl, 'Email', Icons.email_outlined, keyType: TextInputType.emailAddress),
              const SizedBox(height: 20),
            ],

            // Payment method
            const Text('Τρόπος πληρωμής', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _payOption('venue', Icons.store_outlined, 'Στο χώρο')),
                const SizedBox(width: 8),
                Expanded(child: _payOption('card', Icons.credit_card_rounded, 'Κάρτα')),
              ],
            ),

            if (_payMethod == 'card')
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Text(
                    '💳 Η χρέωση θα γίνει με κάρτα κατά την κράτηση.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
              ),

            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
              ),

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _loading ? null : _book,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.lime,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _loading
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : Text('Κράτηση · $_priceStr', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inputField(TextEditingController ctrl, String hint, IconData icon, {TextInputType? keyType}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyType,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 18),
        filled: true,
        fillColor: AppColors.surfaceLight,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.lime)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Widget _payOption(String value, IconData icon, String label) {
    final selected = _payMethod == value;
    return GestureDetector(
      onTap: () => setState(() => _payMethod = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.lime.withValues(alpha: 0.15) : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? AppColors.lime : AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? AppColors.lime : AppColors.textSecondary, size: 22),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? AppColors.lime : AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  String _shortDate(DateTime d) {
    const months = ['Ιαν','Φεβ','Μαρ','Απρ','Μαΐ','Ιουν','Ιουλ','Αυγ','Σεπ','Οκτ','Νοε','Δεκ'];
    return '${d.day} ${months[d.month - 1]}';
  }
}
