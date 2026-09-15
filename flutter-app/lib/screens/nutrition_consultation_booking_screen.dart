import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/booking.dart';
import '../models/service.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/ui_kit.dart';

class NutritionConsultationBookingScreen extends StatefulWidget {
  const NutritionConsultationBookingScreen({
    super.key,
    required this.service,
    required this.credits,
    this.pendingBooking,
    this.upcomingBooking,
    this.nutritionists = const [],
    this.needsNutritionistChoice = false,
  });

  final BookService service;
  final Map<String, dynamic> credits;
  final Map<String, dynamic>? pendingBooking;
  final Map<String, dynamic>? upcomingBooking;
  final List<Map<String, dynamic>> nutritionists;
  final bool needsNutritionistChoice;

  @override
  State<NutritionConsultationBookingScreen> createState() => _NutritionConsultationBookingScreenState();
}

class _NutritionConsultationBookingScreenState extends State<NutritionConsultationBookingScreen> {
  DateTime _selectedDate = DateTime.now();
  String? _selectedTime;
  List<TimeSlot> _slots = [];
  bool _loading = false;
  bool _refreshing = true;
  bool _submitting = false;
  String? _message;

  String? _selectedNutritionistId;
  Map<String, dynamic>? _pendingBooking;
  Map<String, dynamic>? _upcomingBooking;

  ApiService get _api => context.read<AuthService>().api;

  String get _dateStr => DateFormat('yyyy-MM-dd').format(_selectedDate);

  bool get _nutritionistReady =>
      !widget.needsNutritionistChoice || _selectedNutritionistId != null;

  bool get _hasActiveBooking => _pendingBooking != null || _upcomingBooking != null;

  @override
  void initState() {
    super.initState();
    _pendingBooking = widget.pendingBooking;
    _upcomingBooking = widget.upcomingBooking;
    if (!widget.needsNutritionistChoice && widget.nutritionists.length == 1) {
      _selectedNutritionistId = widget.nutritionists.first['id'] as String?;
    }
    _refreshConsultation();
  }

  Future<void> _refreshConsultation() async {
    setState(() => _refreshing = true);
    try {
      final consult = await _api.fetchNutritionConsultation();
      if (!mounted) return;
      setState(() {
        _pendingBooking = consult.pendingBooking;
        _upcomingBooking = consult.upcomingBooking;
      });
      if (consult.pendingBooking == null &&
          consult.upcomingBooking == null &&
          _nutritionistReady) {
        await _loadSlots();
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _message = e.message);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _loadSlots() async {
    if (!_nutritionistReady || _hasActiveBooking) return;
    setState(() {
      _loading = true;
      _selectedTime = null;
    });
    try {
      final result = await _api.fetchNutritionConsultationSlots(
        date: _dateStr,
        nutritionistId: _selectedNutritionistId,
      );
      setState(() {
        _slots = result.slots.where((s) => !s.isFull && s.availableStaff.isNotEmpty).toList();
        _message = result.message;
      });
    } on ApiException catch (e) {
      setState(() => _message = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _book() async {
    if (_selectedTime == null) return;
    setState(() => _submitting = true);
    try {
      await _api.bookNutritionConsultation(
        date: _dateStr,
        time: _selectedTime!,
        nutritionistId: _selectedNutritionistId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Το αίτημα καταχωρήθηκε — αναμένει επιβεβαίωση από τον διατροφολόγο')),
      );
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _formatBookingTime(Map<String, dynamic> booking) {
    return DateFormat('EEEE d MMMM yyyy, HH:mm', 'el_GR')
        .format(DateTime.parse(booking['starts_at'] as String).toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.credits['remaining'];
    final total = widget.credits['total'];
    final pending = _pendingBooking;
    final upcoming = _upcomingBooking;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Κράτηση διατροφολόγου'),
        backgroundColor: AppColors.bg,
      ),
      body: _refreshing
          ? const Center(child: CircularProgressIndicator(color: AppColors.lime))
          : ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.service.name, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                if (pending == null && upcoming == null)
                  Text(
                    widget.service.isUnlimited
                        ? 'Απεριόριστες επισκέψεις'
                        : 'Διαθέσιμες επισκέψεις: $remaining / $total',
                    style: Theme.of(context).textTheme.bodyMedium,
                  )
                else if (pending != null)
                  Text(
                    'Έχεις ενεργό αίτημα κράτησης — δεν είναι ακόμα επιβεβαιωμένο.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  )
                else
                  Text(
                    'Η κράτησή σου έχει επιβεβαιωθεί.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                const SizedBox(height: 6),
                Text(
                  pending != null
                      ? 'Μόλις επιβεβαιωθεί, θα εμφανιστεί στις κρατήσεις του διατροφολόγου.'
                      : upcoming != null
                          ? 'Θα σε περιμένει ο διατροφολόγος την ημέρα και ώρα που έχεις επιλέξει.'
                          : 'Η κράτηση θα είναι σε αναμονή μέχρι την επιβεβαίωση του διατροφολόγου.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          if (pending != null) ...[
            const SizedBox(height: 16),
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Αίτημα σε αναμονή', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Text(
                    _formatBookingTime(pending),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Κατάσταση: Αναμονή επιβεβαίωσης',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
          if (upcoming != null) ...[
            const SizedBox(height: 16),
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Επιβεβαιωμένο ραντεβού', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Text(
                    _formatBookingTime(upcoming),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Κατάσταση: Επιβεβαιωμένο',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.lime),
                  ),
                ],
              ),
            ),
          ],
          if (!_hasActiveBooking) ...[
          if (widget.needsNutritionistChoice) ...[
            const SizedBox(height: 16),
            Text('Διατροφολόγος', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            ...widget.nutritionists.map((n) {
              final id = n['id'] as String;
              final label = n['label'] as String? ?? n['full_name'] as String? ?? '';
              final selected = _selectedNutritionistId == id;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ChoiceChip(
                  label: Text(label),
                  selected: selected,
                  onSelected: (_) {
                    setState(() {
                      _selectedNutritionistId = id;
                      _selectedTime = null;
                    });
                    _loadSlots();
                  },
                ),
              );
            }),
            if (!_nutritionistReady)
              Text(
                'Επίλεξε με ποιον διατροφολόγο θέλεις ραντεβού.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              ),
          ],
          if (_nutritionistReady) ...[
          const SizedBox(height: 16),
          Text('Ημερομηνία', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 14,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final date = DateTime.now().add(Duration(days: i));
                final selected = date.year == _selectedDate.year
                    && date.month == _selectedDate.month
                    && date.day == _selectedDate.day;
                return ChoiceChip(
                  label: Text(DateFormat('E d/M', 'el_GR').format(date)),
                  selected: selected,
                  onSelected: (_) {
                    setState(() => _selectedDate = date);
                    _loadSlots();
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Text('Ώρα', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          if (_loading) const Center(child: CircularProgressIndicator(color: AppColors.lime)),
          if (!_loading && _slots.isEmpty)
            Text(_message ?? 'Δεν υπάρχουν διαθέσιμες ώρες', style: Theme.of(context).textTheme.bodyMedium),
          if (!_loading)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _slots.map((slot) {
                final active = _selectedTime == slot.time;
                return ChoiceChip(
                  label: Text(slot.time),
                  selected: active,
                  onSelected: (_) => setState(() => _selectedTime = slot.time),
                );
              }).toList(),
            ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _selectedTime == null || _submitting || !_nutritionistReady ? null : _book,
            child: Text(_submitting ? 'Αποστολή...' : 'Αίτημα κράτησης'),
          ),
          ],
          ],
        ],
      ),
    );
  }
}
