import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../config/tenant_config.dart';
import '../models/booking.dart';
import '../models/location.dart';
import '../models/opening_hours.dart';
import '../models/service.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import 'booking_success_screen.dart';
import '../widgets/slot_visual.dart';
import '../widgets/staff_avatar.dart';
import '../widgets/staff_detail_sheet.dart';
import '../widgets/preparation_tips_card.dart';
import '../widgets/ui_kit.dart';
import '../services/notification_service.dart';

class BookingFlowScreen extends StatefulWidget {
  const BookingFlowScreen({super.key, required this.service});

  final BookService service;

  @override
  State<BookingFlowScreen> createState() => _BookingFlowScreenState();
}

enum _BulkPeriod { specificMonth, nextFourWeeks }

const _minLeadMinutes = 15;

class _BookingFlowScreenState extends State<BookingFlowScreen> {
  DateTime _selectedDate = DateTime.now();
  String? _selectedTime;
  StaffMember? _selectedStaff;
  List<TimeSlot> _slots = [];
  bool _featureWaitlist = false;
  bool _loadingSlots = false;
  bool _submitting = false;
  String? _error;
  String? _slotsMessage;
  String? _dayStatus;
  OpeningHoursConfig? _openingHours;
  bool _bulkMode = false;
  final Set<int> _selectedWeekdays = {};
  _BulkPeriod _bulkPeriod = _BulkPeriod.specificMonth;
  bool _staffPickerExpanded = true;
  DateTime _bulkMonth = DateTime(DateTime.now().year, DateTime.now().month);
  double _bookingPanelDrag = 0;
  List<GymLocation> _locations = [];
  bool _multiLocation = false;
  GymLocation? _selectedLocation;
  bool _loadingLocations = true;

  static const _weekdayLabels = {
    1: 'Δε',
    2: 'Τρ',
    3: 'Τε',
    4: 'Πε',
    5: 'Πα',
    6: 'Σα',
    7: 'Κυ',
  };

  static const _weekdayFull = {
    1: 'Δευτέρα',
    2: 'Τρίτη',
    3: 'Τετάρτη',
    4: 'Πέμπτη',
    5: 'Παρασκευή',
    6: 'Σάββατο',
    7: 'Κυριακή',
  };

  ApiService get _api => context.read<AuthService>().api;
  TenantConfig get _config => context.read<TenantConfig>();

  bool get _needsLocationChoice => _multiLocation && _locations.length > 1;
  bool get _locationReady => !_needsLocationChoice || _selectedLocation != null;
  String? get _locationId => _selectedLocation?.id;

  @override
  void initState() {
    super.initState();
    _initBookingFlow();
  }

  Future<void> _initBookingFlow() async {
    try {
      final locResult = await _api.fetchLocations(serviceId: widget.service.id);
      if (!mounted) return;
      setState(() {
        _locations = locResult.locations;
        _multiLocation = locResult.multiLocation;
        _loadingLocations = false;
        if (_locations.length == 1) {
          _selectedLocation = _locations.first;
        }
      });
    } catch (_) {
      if (mounted) setState(() => _loadingLocations = false);
    }

    if (!_locationReady) return;

    final hours = await _api.fetchOpeningHours(locationId: _locationId);
    if (!mounted) return;
    setState(() => _openingHours = hours);
    if (hours != null && !hours.isDateOpen(_selectedDate)) {
      final next = hours.nextOpenDate(from: DateTime.now());
      if (next != null) {
        setState(() => _selectedDate = next);
      }
    }
    await _loadSlots();
  }

  Future<void> _selectLocation(GymLocation location) async {
    setState(() {
      _selectedLocation = location;
      _selectedDate = DateTime.now();
      _selectedTime = null;
      _selectedStaff = null;
      _slots = [];
      _error = null;
      _slotsMessage = null;
    });

    final hours = await _api.fetchOpeningHours(locationId: location.id);
    if (!mounted) return;
    setState(() => _openingHours = hours);
    if (hours != null && !hours.isDateOpen(_selectedDate)) {
      final next = hours.nextOpenDate(from: DateTime.now());
      if (next != null) {
        setState(() => _selectedDate = next);
      }
    }
    await _loadSlots();
  }

  bool _isDateSelectable(DateTime date) {
    final today = DateTime.now();
    final day = DateTime(date.year, date.month, date.day);
    final first = DateTime(today.year, today.month, today.day);
    final last = first.add(const Duration(days: 60));
    if (day.isBefore(first) || day.isAfter(last)) return false;
    if (_openingHours == null) return true;
    return _openingHours!.isDateOpen(day);
  }

  String get _dateStr => DateFormat('yyyy-MM-dd').format(_selectedDate);

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  bool _isSlotBookable(String dateStr, String time) {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (dateStr != todayStr) return true;

    final parts = time.split(':');
    final slotStart = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
    final cutoff = DateTime.now().add(const Duration(minutes: _minLeadMinutes));
    return slotStart.isAfter(cutoff);
  }

  List<TimeSlot> _filterPastSlots(List<TimeSlot> slots, String dateStr) {
    return slots.where((s) => _isSlotBookable(dateStr, s.time)).toList();
  }

  DateTime? get _bulkSlotDate {
    if (_selectedWeekdays.isEmpty) return null;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    DateTime start;
    DateTime end;
    if (_bulkPeriod == _BulkPeriod.nextFourWeeks) {
      start = today;
      end = today.add(const Duration(days: 28));
    } else {
      start = DateTime(_bulkMonth.year, _bulkMonth.month, 1);
      end = DateTime(_bulkMonth.year, _bulkMonth.month + 1, 0);
      if (start.isBefore(today)) start = today;
    }

    var current = start;
    while (!current.isAfter(end)) {
      if (_selectedWeekdays.contains(current.weekday)) {
        return DateTime(current.year, current.month, current.day);
      }
      current = current.add(const Duration(days: 1));
    }
    return null;
  }

  List<Map<String, String>> _generateBulkSlots() {
    if (_selectedTime == null || _selectedWeekdays.isEmpty) return [];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    DateTime from;
    DateTime to;
    if (_bulkPeriod == _BulkPeriod.nextFourWeeks) {
      from = today;
      to = today.add(const Duration(days: 28));
    } else {
      from = DateTime(_bulkMonth.year, _bulkMonth.month, 1);
      to = DateTime(_bulkMonth.year, _bulkMonth.month + 1, 0);
      if (from.isBefore(today)) from = today;
    }

    final slots = <Map<String, String>>[];
    var current = from;
    final parts = _selectedTime!.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

    while (!current.isAfter(to)) {
      if (_selectedWeekdays.contains(current.weekday)) {
        final slotStart = DateTime(current.year, current.month, current.day, hour, minute);
        final cutoff = now.add(const Duration(minutes: _minLeadMinutes));
        if (slotStart.isAfter(cutoff)) {
          slots.add({
            'date': DateFormat('yyyy-MM-dd').format(current),
            'time': _selectedTime!,
          });
        }
      }
      current = current.add(const Duration(days: 1));
    }
    return slots;
  }

  void _setBulkMode(bool bulk) {
    setState(() {
      _bulkMode = bulk;
      _selectedTime = null;
      _selectedStaff = null;
      if (bulk && _selectedWeekdays.isEmpty) {
        _selectedWeekdays.add(_selectedDate.weekday);
      }
    });
    if (bulk) {
      final ref = _bulkSlotDate;
      if (ref != null) {
        _loadSlots(forDate: ref);
      }
    } else {
      _loadSlots();
    }
  }

  void _toggleWeekday(int day) {
    if (_openingHours != null && !_openingHours!.isWeekdayOpen(day)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Το γυμναστήριο είναι κλειστό κάθε ${_weekdayFull[day] ?? 'αυτή την ημέρα'}.'),
        ),
      );
      return;
    }
    setState(() {
      if (_selectedWeekdays.contains(day)) {
        _selectedWeekdays.remove(day);
      } else {
        _selectedWeekdays.add(day);
      }
      _selectedTime = null;
      _selectedStaff = null;
    });
    final ref = _bulkSlotDate;
    if (ref != null) {
      _loadSlots(forDate: ref);
    } else {
      setState(() => _slots = []);
    }
  }

  Future<void> _loadSlots({DateTime? forDate}) async {
    if (!_locationReady) return;
    final date = forDate ?? _selectedDate;
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    setState(() {
      _loadingSlots = true;
      _selectedTime = null;
      _selectedStaff = null;
      _staffPickerExpanded = true;
      _error = null;
      _slotsMessage = null;
      _dayStatus = null;
    });
    try {
      final result = await _api.fetchSlots(
        serviceId: widget.service.id,
        date: dateStr,
        locationId: _locationId,
      );
      final filtered = _filterPastSlots(result.slots, dateStr);
      setState(() {
        _slots = filtered;
        _featureWaitlist = result.featureWaitlist;
        _dayStatus = result.dayStatus;
        _slotsMessage = result.message ??
            (filtered.isEmpty
                ? (_isToday(date)
                    ? 'Δεν υπάρχουν διαθέσιμες ώρες για σήμερα — δοκίμασε αργότερα ή άλλη ημέρα.'
                    : 'Δεν υπάρχουν διαθέσιμες ώρες')
                : null);
        if (_selectedTime != null && !_isSlotBookable(dateStr, _selectedTime!)) {
          _selectedTime = null;
          _selectedStaff = null;
        }
      });
    } on ApiException catch (e) {
      setState(() {
        _slots = [];
        _slotsMessage = e.message;
        _error = e.message;
      });
    } finally {
      if (mounted) setState(() => _loadingSlots = false);
    }
  }

  Future<void> _pickBulkMonth() async {
    final now = DateTime.now();
    final options = List.generate(12, (i) => DateTime(now.year, now.month + i));
    final monthFmt = DateFormat('MMMM yyyy', 'el_GR');

    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text('Επίλεξε μήνα', style: Theme.of(ctx).textTheme.titleMedium),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (_, i) {
                    final month = options[i];
                    final selected = month.year == _bulkMonth.year && month.month == _bulkMonth.month;
                    return ListTile(
                      title: Text(
                        monthFmt.format(month),
                        style: TextStyle(
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected ? AppColors.lime : AppColors.textPrimary,
                        ),
                      ),
                      trailing: selected ? const Icon(Icons.check, color: AppColors.lime) : null,
                      onTap: () => Navigator.pop(ctx, month),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (picked == null) return;
    setState(() {
      _bulkMonth = DateTime(picked.year, picked.month);
      _bulkPeriod = _BulkPeriod.specificMonth;
      _selectedTime = null;
      _selectedStaff = null;
    });
    final ref = _bulkSlotDate;
    if (ref != null) {
      await _loadSlots(forDate: ref);
    } else {
      setState(() => _slots = []);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final first = DateTime(now.year, now.month, now.day);
    var initial = _selectedDate;
    if (!_isDateSelectable(initial)) {
      initial = _openingHours?.nextOpenDate(from: first) ?? first;
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: first.add(const Duration(days: 60)),
      selectableDayPredicate: _isDateSelectable,
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      await _loadSlots();
    }
  }

  Widget _emptySlotsCard() {
    final isClosed = _dayStatus == 'closed';
    final message = _slotsMessage ??
        (_isToday(_selectedDate)
            ? 'Δεν υπάρχουν διαθέσιμες ώρες για σήμερα — δοκίμασε αργότερα ή άλλη ημέρα.'
            : 'Δεν υπάρχουν διαθέσιμες ώρες');

    return SurfaceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isClosed ? Icons.storefront_outlined : Icons.event_busy_outlined,
            color: isClosed ? AppColors.orange : AppColors.textSecondary,
            size: 28,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isClosed)
                  Text(
                    'Κλειστό',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.orange,
                        ),
                  ),
                if (isClosed) const SizedBox(height: 4),
                Text(message, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<StaffMember> _uniqueStaff(List<StaffMember> staff) {
    final seen = <String>{};
    return staff.where((s) => seen.add(s.id)).toList();
  }

  TimeSlot? get _selectedSlot {
    if (_selectedTime == null) return null;
    try {
      return _slots.firstWhere((s) => s.time == _selectedTime);
    } catch (_) {
      return null;
    }
  }

  List<StaffMember> get _staffForSelectedTime {
    return _uniqueStaff(_selectedSlot?.availableStaff ?? []);
  }

  bool get _selectedIsWaitlist =>
      _selectedSlot != null && _selectedSlot!.isFull && _selectedSlot!.waitlistAvailable;

  bool get _canSelectStaff => !widget.service.hideStaffSelection;

  bool get _needsStaffChoice => _canSelectStaff && _staffForSelectedTime.length > 1;

  void _autoSelectStaffIfSingle() {
    if (!_canSelectStaff || _selectedTime == null) return;
    final staff = _staffForSelectedTime;
    if (staff.length == 1) {
      _selectedStaff = staff.first;
      _staffPickerExpanded = false;
    }
  }

  void _selectStaff(StaffMember staff) {
    setState(() {
      _selectedStaff = staff;
      _staffPickerExpanded = false;
      if (_error != null && _error!.contains('Επίλεξε')) _error = null;
    });
  }

  void _openStaffPicker() {
    setState(() => _staffPickerExpanded = true);
  }

  TimeSlot? _nextAvailableSlotAfter(String time) {
    final sorted = [..._slots]..sort((a, b) => a.time.compareTo(b.time));
    for (final slot in sorted) {
      if (slot.time.compareTo(time) > 0 && slot.isBookable) return slot;
    }
    return null;
  }

  void _applySlotSelection(TimeSlot slot) {
    setState(() {
      _selectedTime = slot.time;
      final staff = _uniqueStaff(slot.availableStaff);
      _staffPickerExpanded = true;
      _selectedStaff = (!_canSelectStaff || staff.length == 1)
          ? (staff.isNotEmpty ? staff.first : null)
          : null;
      if (staff.length == 1) _staffPickerExpanded = false;
      _error = null;
    });
  }

  Future<void> _handleWaitlistSelection(TimeSlot slot) async {
    final next = _nextAvailableSlotAfter(slot.time);

    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Πλήρης ώρα'),
        content: Text(
          next != null
              ? 'Η ώρα ${slot.time} είναι πλήρης.\n\nΗ επόμενη διαθέσιμη είναι στις ${next.time}. Θέλεις να κλείσεις εκεί ή να περιμένεις στη λίστα αναμονής αν αλλάξει κάτι;'
              : 'Η ώρα ${slot.time} είναι πλήρης και δεν υπάρχει άλλη διαθέσιμη ώρα αυτή την ημέρα.\n\nΘέλεις να μπεις στη λίστα αναμονής και να σε ενημερώσουμε αν ανοίξει θέση;',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'cancel'), child: const Text('Ακύρωση')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'waitlist'),
            child: const Text('Περίμενε στη λίστα', style: TextStyle(color: AppColors.orange)),
          ),
          if (next != null)
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'book'),
              child: Text('Κλείσε ${next.time}', style: const TextStyle(color: AppColors.lime)),
            ),
        ],
      ),
    );

    if (!mounted || choice == null || choice == 'cancel') return;

    if (choice == 'book' && next != null) {
      _applySlotSelection(next);
    } else if (choice == 'waitlist') {
      _applySlotSelection(slot);
    }
  }

  Future<void> _showSlotConflictDialog(TimeSlot slot) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.event_busy, color: AppColors.orange, size: 36),
        title: Text(slot.userConflictTitle ?? 'Μη διαθέσιμο'),
        content: Text(slot.userConflictDetail(widget.service.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _onSlotTap(TimeSlot slot) async {
    if (slot.userHasBooking) {
      await _showSlotConflictDialog(slot);
      return;
    }
    final isWaitlist = slot.isFull && slot.waitlistAvailable;
    if (_bulkMode && isWaitlist) return;
    if (!slot.isBookable && !isWaitlist) return;

    if (isWaitlist && _featureWaitlist) {
      await _handleWaitlistSelection(slot);
      return;
    }

    _applySlotSelection(slot);
  }

  void _openStaffDetail(StaffMember staff) {
    final canSelect = !widget.service.hideStaffSelection;
    showStaffDetailSheet(
      context,
      staff: staff,
      config: _config,
      canSelect: canSelect,
      isSelected: _selectedStaff?.id == staff.id,
      onSelect: canSelect && _needsStaffChoice ? () => _selectStaff(staff) : null,
    );
  }

  Future<void> _joinWaitlist() async {
    if (_selectedTime == null) return;
    _autoSelectStaffIfSingle();

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final r = await _api.joinWaitlist(
        serviceId: widget.service.id,
        date: _dateStr,
        time: _selectedTime!,
        staffId: _selectedStaff?.id,
        locationId: _locationId,
      );
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Λίστα αναμονής'),
          content: Text(
            '${r['message'] as String? ?? 'Μπήκες στη λίστα αναμονής.'}\n\n'
            'Θα το δεις στα Ραντεβού μου με ένδειξη «Σε αναμονή».',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
          ],
        ),
      );
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _confirm() async {
    if (_selectedTime == null) return;
    if (_selectedIsWaitlist) {
      await _joinWaitlist();
      return;
    }
    _autoSelectStaffIfSingle();
    if (_needsStaffChoice && _selectedStaff == null) {
      setState(() => _error = 'Επίλεξε ${_config.label('staff_noun', 'γυμναστή')}');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final result = await _api.createBooking(
        serviceId: widget.service.id,
        date: _dateStr,
        time: _selectedTime!,
        staffId: _selectedStaff?.id,
        locationId: _locationId,
        useCredit: true,
      );
      final bookingId = result['booking_id'] as String? ?? '';
      final prepTips = (result['preparation_tips'] as List? ?? [])
          .map((e) => e.toString())
          .toList();
      final endsAt = DateTime.parse(result['ends_at'] as String).toLocal();
      final startsAt = DateTime.parse(result['starts_at'] as String).toLocal();

      if (bookingId.isNotEmpty) {
        await NotificationService.instance.scheduleBookingReminders(
          notificationId: bookingId.hashCode.abs() % 50000,
          bookingId: bookingId,
          serviceName: widget.service.name,
          startsAt: startsAt,
          endsAt: endsAt,
          preparationTips: prepTips.isNotEmpty
              ? prepTips
              : (_selectedSlot?.preparationTips ?? []),
        );
      }

      if (mounted) {
        await Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            fullscreenDialog: true,
            opaque: true,
            pageBuilder: (_, _, _) => BookingSuccessScreen(
              serviceName: widget.service.name,
              date: _selectedDate,
              time: _selectedTime!,
              staffName: _selectedStaff?.fullName,
              preparationTips: prepTips.isNotEmpty
                  ? prepTips
                  : (_selectedSlot?.preparationTips ?? []),
            ),
            transitionsBuilder: (_, animation, _, child) {
              return FadeTransition(
                opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.96, end: 1).animate(
                    CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
                  ),
                  child: child,
                ),
              );
            },
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
      }
    } on ApiException catch (e) {
      if (e.message.contains('λίστα αναμονής') && _featureWaitlist && _selectedTime != null) {
        final next = _nextAvailableSlotAfter(_selectedTime!);
        final join = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text('Πλήρες'),
            content: Text(
              next != null
                  ? '${e.message}\n\nΗ επόμενη διαθέσιμη ώρα είναι στις ${next.time}.'
                  : e.message,
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, 'no'), child: const Text('Όχι')),
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'waitlist'),
                child: const Text('Λίστα αναμονής', style: TextStyle(color: AppColors.orange)),
              ),
              if (next != null)
                TextButton(
                  onPressed: () => Navigator.pop(ctx, 'book'),
                  child: Text('Κλείσε ${next.time}', style: const TextStyle(color: AppColors.lime)),
                ),
            ],
          ),
        );
        if (!mounted) return;
        if (join == 'waitlist') {
          await _joinWaitlist();
        } else if (join == 'book' && next != null) {
          _applySlotSelection(next);
          await _confirm();
        }
      } else {
        setState(() => _error = e.message);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _scheduleRemindersForCreated(List<dynamic> created) async {
    for (final raw in created) {
      final map = raw as Map<String, dynamic>;
      final bookingId = map['booking_id'] as String? ?? '';
      if (bookingId.isEmpty) continue;
      final startsAt = DateTime.parse(map['starts_at'] as String).toLocal();
      final endsAt = DateTime.parse(map['ends_at'] as String).toLocal();
      final prepTips = (map['preparation_tips'] as List? ?? [])
          .map((e) => e.toString())
          .toList();
      await NotificationService.instance.scheduleBookingReminders(
        notificationId: bookingId.hashCode.abs() % 50000,
        bookingId: bookingId,
        serviceName: widget.service.name,
        startsAt: startsAt,
        endsAt: endsAt,
        preparationTips: prepTips,
      );
    }
  }

  Future<List<Map<String, String>>?> _promptAlternatives(List<dynamic> failed) async {
    final withAlt = failed
        .where((f) => (f as Map<String, dynamic>)['alternative'] != null)
        .toList();
    if (withAlt.isEmpty) return null;

    final dateFmt = DateFormat('EEE d MMM', 'el_GR');
    final selectedKeys = <String>{};

    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              title: const Text('Εναλλακτικές ώρες'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Μερικές ημέρες δεν ήταν διαθέσιμες. Θέλεις να κλείσεις τις προτεινόμενες εναλλακτικές;',
                    ),
                    const SizedBox(height: 16),
                    ...withAlt.map((raw) {
                      final f = raw as Map<String, dynamic>;
                      final date = DateTime.parse('${f['date']}T12:00:00');
                      final alt = f['alternative'] as Map<String, dynamic>;
                      final altTime = alt['time'] as String;
                      final key = '${f['date']}|$altTime';

                      return CheckboxListTile(
                        value: selectedKeys.contains(key),
                        activeColor: AppColors.lime,
                        title: Text(
                          '${dateFmt.format(date)} ${f['time']} → $altTime',
                          style: const TextStyle(fontSize: 14),
                        ),
                        subtitle: Text(
                          f['reason'] as String? ?? '',
                          style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(fontSize: 12),
                        ),
                        onChanged: (v) {
                          setDialogState(() {
                            if (v == true) {
                              selectedKeys.add(key);
                            } else {
                              selectedKeys.remove(key);
                            }
                          });
                        },
                      );
                    }),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Όχι'),
                ),
                TextButton(
                  onPressed: selectedKeys.isEmpty ? null : () => Navigator.pop(ctx, true),
                  child: const Text('Κλείσε επιλεγμένες'),
                ),
              ],
            );
          },
        );
      },
    );

    if (proceed != true || selectedKeys.isEmpty) return null;

    return withAlt
        .map((raw) {
          final f = raw as Map<String, dynamic>;
          final alt = f['alternative'] as Map<String, dynamic>;
          final altTime = alt['time'] as String;
          final key = '${f['date']}|$altTime';
          if (!selectedKeys.contains(key)) return null;
          return {'date': f['date'] as String, 'time': altTime};
        })
        .whereType<Map<String, String>>()
        .toList();
  }

  Future<void> _showBulkSummary(Map<String, dynamic> result) async {
    final summary = result['summary'] as Map<String, dynamic>? ?? {};
    final created = summary['created_count'] as int? ?? 0;
    final failed = summary['failed_count'] as int? ?? 0;
    final message = result['message'] as String? ?? '';

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Ολοκληρώθηκε'),
        content: Text(
          failed > 0
              ? '$message\n\nΟι υπόλοιπες ημέρες κλείστηκαν κανονικά.'
              : message.isNotEmpty
                  ? message
                  : 'Κλείστηκαν $created ραντεβού.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmBulk() async {
    if (_selectedTime == null || _selectedWeekdays.isEmpty) return;
    _autoSelectStaffIfSingle();
    if (_needsStaffChoice && _selectedStaff == null) {
      setState(() => _error = 'Επίλεξε ${_config.label('staff_noun', 'γυμναστή')}');
      return;
    }

    final slots = _generateBulkSlots();
    if (slots.isEmpty) {
      setState(() => _error = 'Δεν βρέθηκαν μελλοντικές ημέρες για κράτηση');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Επαναλαμβανόμενη κράτηση'),
        content: Text(
          'Θα κλειστούν ${slots.length} ραντεβού στις ${_selectedTime!}. Συνέχεια;',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Όχι')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ναι')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      var result = await _api.createBulkBookings(
        serviceId: widget.service.id,
        slots: slots,
        staffId: _selectedStaff?.id,
        locationId: _locationId,
      );

      await _scheduleRemindersForCreated(result['created'] as List? ?? []);

      final failed = result['failed'] as List? ?? [];
      if (failed.isNotEmpty && mounted) {
        final alternatives = await _promptAlternatives(failed);
        if (alternatives != null && alternatives.isNotEmpty) {
          final altResult = await _api.createBulkBookings(
            serviceId: widget.service.id,
            slots: alternatives,
            staffId: _selectedStaff?.id,
            locationId: _locationId,
          );
          await _scheduleRemindersForCreated(altResult['created'] as List? ?? []);
          final altFailed = altResult['failed'] as List? ?? [];
          result = {
            ...result,
            'created': [
              ...(result['created'] as List? ?? []),
              ...(altResult['created'] as List? ?? []),
            ],
            'failed': altFailed,
            'summary': {
              'total': slots.length,
              'created_count':
                  ((result['created'] as List? ?? []).length) +
                  ((altResult['created'] as List? ?? []).length),
              'failed_count': altFailed.length,
            },
            'message': altFailed.isEmpty
                ? 'Όλες οι διαθέσιμες κρατήσεις ολοκληρώθηκαν.'
                : 'Μερικές εναλλακτικές δεν ήταν διαθέσιμες.',
          };
        }
      }

      if (!mounted) return;
      await _showBulkSummary(result);
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _slotCard(TimeSlot slot, bool selected) {
    final isUserConflict = slot.userHasBooking;
    final isWaitlist = !isUserConflict && slot.isFull && slot.waitlistAvailable;
    final mode = widget.service.slotLabelMode;
    final title = slot.displayTitle(mode);
    final subtitle = slot.displaySubtitle(mode);
    final showTimeProminent = mode != 'time_only' || (slot.label == null && slot.roomName == null);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => _onSlotTap(slot),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? (isWaitlist ? AppColors.orange.withValues(alpha: 0.12) : AppColors.lime.withValues(alpha: 0.12))
                : (isUserConflict
                    ? AppColors.surface.withValues(alpha: 0.45)
                    : (isWaitlist ? AppColors.surface.withValues(alpha: 0.6) : AppColors.surface)),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? (isWaitlist ? AppColors.orange : AppColors.lime)
                  : (isUserConflict
                      ? AppColors.border
                      : (isWaitlist ? AppColors.orange.withValues(alpha: 0.4) : AppColors.border)),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              SlotVisual(config: _config, imageUrl: slot.roomPhotoUrl ?? slot.imageUrl, iconKey: slot.iconKey),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showTimeProminent && title != slot.time)
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: selected ? AppColors.lime : AppColors.textPrimary,
                        ),
                      )
                    else
                      Text(
                        slot.time,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: selected ? AppColors.lime : AppColors.textPrimary,
                        ),
                      ),
                    if (showTimeProminent && title != slot.time) ...[
                      const SizedBox(height: 2),
                      Text(slot.time, style: Theme.of(context).textTheme.bodyMedium),
                    ],
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                    ],
                    if (mode == 'room' && slot.roomName != null && title == slot.roomName && slot.label != null) ...[
                      const SizedBox(height: 4),
                      Text(slot.label!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12)),
                    ],
                    if (slot.capacityLabel != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        slot.capacityLabel!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontSize: 12,
                              color: isWaitlist ? AppColors.orange : AppColors.lime,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                    if (isWaitlist) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Λίστα αναμονής',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontSize: 12,
                              color: AppColors.orange,
                            ),
                      ),
                    ],
                    if (isUserConflict && slot.userConflictLabel != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        slot.userConflictLabel!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontSize: 12,
                              color: AppColors.orange,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                isUserConflict
                    ? Icons.block
                    : (selected ? Icons.check_circle : Icons.circle_outlined),
                color: isUserConflict
                    ? AppColors.textSecondary
                    : (selected
                        ? (isWaitlist ? AppColors.orange : AppColors.lime)
                        : AppColors.border),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _selectedStaffSummary({VoidCallback? onChange}) {
    final staff = _selectedStaff ?? _staffForSelectedTime.firstOrNull;
    if (staff == null) return const SizedBox.shrink();

    return InkWell(
      onTap: () => _openStaffDetail(staff),
      borderRadius: BorderRadius.circular(20),
      child: SurfaceCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            StaffAvatar(staff: staff, config: _config, radius: 26),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _config.label('staff_noun', 'Γυμναστής'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(staff.fullName, style: Theme.of(context).textTheme.titleMedium),
                  if (staff.role != null) ...[
                    const SizedBox(height: 4),
                    PillChip(
                      label: staff.role!,
                      color: AppColors.purple.withValues(alpha: 0.15),
                      textColor: AppColors.purple,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    'Πάτα για προφίλ και φωτογραφία',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.check_circle, color: AppColors.lime, size: 26),
            if (onChange != null) ...[
              const SizedBox(width: 4),
              TextButton(onPressed: onChange, child: const Text('Αλλαγή')),
            ],
          ],
        ),
      ),
    );
  }

  Widget _staffPicker(List<StaffMember> staff) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.purple.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.people_outline, color: AppColors.purple, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Επίλεξε ${_config.label('staff_noun', 'γυμναστή')}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    'Πάτα για προφίλ · το ✓ για γρήγορη επιλογή',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 192,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: staff.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final member = staff[i];
              final selected = _selectedStaff?.id == member.id;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 148,
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.lime.withValues(alpha: 0.1)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected ? AppColors.lime : AppColors.border,
                    width: 2,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => _openStaffDetail(member),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  children: [
                                    StaffAvatar(staff: member, config: _config, radius: 30),
                                    const SizedBox(height: 8),
                                    Text(
                                      member.fullName,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        height: 1.2,
                                      ),
                                    ),
                                    if (member.role != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        member.role!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          fontSize: 11,
                                          height: 1.2,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 28),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Material(
                        color: selected
                            ? AppColors.lime.withValues(alpha: 0.18)
                            : AppColors.bg.withValues(alpha: 0.9),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => _selectStaff(member),
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Icon(
                              selected ? Icons.check_circle : Icons.add_circle_outline,
                              color: selected ? AppColors.lime : AppColors.textSecondary,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _staffSection(List<StaffMember> staffForTime, bool needsChoice) {
    if (needsChoice) {
      if (_selectedStaff != null && !_staffPickerExpanded) {
        return _selectedStaffSummary(onChange: _openStaffPicker);
      }
      return _staffPicker(staffForTime);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ο/Η ${_config.label('staff_noun', 'γυμναστής')} σου',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 10),
        _selectedStaffSummary(),
      ],
    );
  }

  void _clearSelectedTime() {
    setState(() {
      _selectedTime = null;
      _selectedStaff = null;
      _staffPickerExpanded = true;
      _error = null;
      _bookingPanelDrag = 0;
    });
  }

  void _onBookingPanelDragUpdate(DragUpdateDetails details) {
    if (details.delta.dy <= 0 && _bookingPanelDrag <= 0) return;
    setState(() {
      _bookingPanelDrag = (_bookingPanelDrag + details.delta.dy).clamp(0, 280);
    });
  }

  void _onBookingPanelDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (_bookingPanelDrag > 72 || velocity > 450) {
      _clearSelectedTime();
      return;
    }
    setState(() => _bookingPanelDrag = 0);
  }

  Widget _buildStickyBookingPanel({
    required List<StaffMember> staffForTime,
    required bool needsChoice,
  }) {
    final dragProgress = (_bookingPanelDrag / 180).clamp(0.0, 1.0);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragUpdate: _onBookingPanelDragUpdate,
      onVerticalDragEnd: _onBookingPanelDragEnd,
      child: Transform.translate(
        offset: Offset(0, _bookingPanelDrag),
        child: Opacity(
          opacity: 1 - dragProgress * 0.35,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              border: const Border(top: BorderSide(color: AppColors.border)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4 * (1 - dragProgress * 0.5)),
                  blurRadius: 28,
                  offset: const Offset(0, -10),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.lime.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.lime.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.schedule, size: 16, color: AppColors.lime),
                        const SizedBox(width: 6),
                        Text(
                          _selectedTime!,
                          style: const TextStyle(
                            color: AppColors.lime,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _clearSelectedTime,
                    child: const Text('Αλλαγή ώρας'),
                  ),
                ],
              ),
              if (_selectedIsWaitlist) ...[
                const SizedBox(height: 12),
                Text(
                  'Θα μπεις στη λίστα αναμονής για τις $_selectedTime.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ] else if (staffForTime.isNotEmpty) ...[
                const SizedBox(height: 16),
                _staffSection(staffForTime, needsChoice),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.orange)),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting || _selectedTime == null
                      ? null
                      : (_bulkMode ? _confirmBulk : _confirm),
                  child: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bg),
                        )
                      : Text(
                          _bulkMode
                              ? 'Κλείσε όλες (${_generateBulkSlots().length})'
                              : _selectedIsWaitlist
                                  ? 'Λίστα αναμονής'
                                  : _config.label('book_cta', 'Κράτηση'),
                        ),
                ),
              ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final staffForTime = _staffForSelectedTime;
    final needsChoice = _needsStaffChoice;
    final colors = AppColors.cardGradient(widget.service.name.hashCode);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.service.name),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              children: [
          ServiceImage(config: _config, imageUrl: widget.service.imageUrl, height: 160, borderRadius: 24),
          const SizedBox(height: 14),
          GradientCard(
            colors: colors,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.service.name,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                if (widget.service.description != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.service.description!,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.85), height: 1.4),
                  ),
                ],
                const SizedBox(height: 12),
                PillChip(label: '${widget.service.durationMins} λεπτά'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Session count banner
          if (widget.service.hasMembership)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: widget.service.canBook
                    ? AppColors.lime.withValues(alpha: 0.10)
                    : Colors.orange.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    widget.service.isUnlimited ? Icons.all_inclusive : Icons.confirmation_number_outlined,
                    size: 18,
                    color: widget.service.canBook ? AppColors.lime : Colors.orange,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.service.isUnlimited
                          ? 'Απεριόριστες συνεδρίες διαθέσιμες'
                          : widget.service.canBook
                              ? '${widget.service.creditsRemaining} διαθέσιμες συνεδρίες αυτόν τον μήνα'
                              : 'Δεν υπάρχουν διαθέσιμες συνεδρίες',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: widget.service.canBook ? AppColors.lime : Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          if (_loadingLocations)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(color: AppColors.lime),
              ),
            )
          else if (_needsLocationChoice) ...[
            Text('Τοποθεσία', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            ..._locations.map((loc) {
              final selected = _selectedLocation?.id == loc.id;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SurfaceCard(
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.lime.withValues(alpha: 0.15)
                            : AppColors.purple.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.location_on_outlined,
                        color: selected ? AppColors.lime : AppColors.purple,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      loc.name,
                      style: TextStyle(
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? AppColors.lime : AppColors.textPrimary,
                      ),
                    ),
                    subtitle: loc.displayLine.isNotEmpty ? Text(loc.displayLine) : null,
                    trailing: selected
                        ? const Icon(Icons.check_circle, color: AppColors.lime)
                        : const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                    onTap: () => _selectLocation(loc),
                  ),
                ),
              );
            }),
            if (!_locationReady) ...[
              const SizedBox(height: 8),
              Text(
                'Επίλεξε πρώτα το γυμναστήριο για να δεις διαθέσιμες ημέρες και ώρες.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
          if (_locationReady) ...[
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Μία ημέρα'), icon: Icon(Icons.today, size: 18)),
              ButtonSegment(
                value: true,
                label: Text('Επανάληψη'),
                icon: Icon(Icons.event_repeat, size: 18),
              ),
            ],
            selected: {_bulkMode},
            onSelectionChanged: (s) => _setBulkMode(s.first),
            style: ButtonStyle(
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return AppColors.bg;
                return AppColors.textPrimary;
              }),
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return AppColors.lime;
                return AppColors.surface;
              }),
            ),
          ),
          const SizedBox(height: 20),
          if (!_bulkMode) ...[
            Text('Ημερομηνία', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            SurfaceCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.purple.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.calendar_today, color: AppColors.purple, size: 20),
                ),
                title: Text(DateFormat('EEEE d MMM yyyy', 'el_GR').format(_selectedDate)),
                trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                onTap: _pickDate,
              ),
            ),
          ] else ...[
            Text('Ημέρες εβδομάδας', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _weekdayLabels.entries.map((e) {
                final selected = _selectedWeekdays.contains(e.key);
                final gymClosed = _openingHours != null && !_openingHours!.isWeekdayOpen(e.key);
                return FilterChip(
                  label: Text(e.value),
                  selected: selected,
                  onSelected: gymClosed ? null : (_) => _toggleWeekday(e.key),
                  selectedColor: AppColors.lime.withValues(alpha: 0.2),
                  checkmarkColor: AppColors.lime,
                  disabledColor: AppColors.surface,
                  labelStyle: TextStyle(
                    color: gymClosed
                        ? AppColors.textSecondary.withValues(alpha: 0.5)
                        : (selected ? AppColors.lime : AppColors.textPrimary),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text('Περίοδος', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Συγκεκριμένος μήνας'),
                  selected: _bulkPeriod == _BulkPeriod.specificMonth,
                  onSelected: (_) {
                    setState(() {
                      _bulkPeriod = _BulkPeriod.specificMonth;
                      _selectedTime = null;
                      _selectedStaff = null;
                    });
                    final ref = _bulkSlotDate;
                    if (ref != null) {
                      _loadSlots(forDate: ref);
                    }
                  },
                  selectedColor: AppColors.purple.withValues(alpha: 0.2),
                ),
                ChoiceChip(
                  label: const Text('Επόμενες 4 εβδ.'),
                  selected: _bulkPeriod == _BulkPeriod.nextFourWeeks,
                  onSelected: (_) {
                    setState(() {
                      _bulkPeriod = _BulkPeriod.nextFourWeeks;
                      _selectedTime = null;
                      _selectedStaff = null;
                    });
                    final ref = _bulkSlotDate;
                    if (ref != null) {
                      _loadSlots(forDate: ref);
                    } else {
                      setState(() => _slots = []);
                    }
                  },
                  selectedColor: AppColors.purple.withValues(alpha: 0.2),
                ),
              ],
            ),
            if (_bulkPeriod == _BulkPeriod.specificMonth) ...[
              const SizedBox(height: 10),
              SurfaceCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.purple.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.date_range, color: AppColors.purple, size: 20),
                  ),
                  title: Text(DateFormat('MMMM yyyy', 'el_GR').format(_bulkMonth)),
                  subtitle: const Text('Πάτα για αλλαγή μήνα'),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                  onTap: _pickBulkMonth,
                ),
              ),
            ],
            if (_selectedTime != null && _selectedWeekdays.isNotEmpty) ...[
              const SizedBox(height: 12),
              SurfaceCard(
                child: Text(
                  _bulkPeriod == _BulkPeriod.specificMonth
                      ? 'Θα κλειστούν ${_generateBulkSlots().length} ραντεβού τον ${DateFormat('MMMM yyyy', 'el_GR').format(_bulkMonth)} στις $_selectedTime'
                      : 'Θα κλειστούν ${_generateBulkSlots().length} ραντεβού στις $_selectedTime (επόμενες 4 εβδ.)',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ],
          const SizedBox(height: 24),
          Text('Διαθέσιμες ώρες', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          if (_loadingSlots)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(color: AppColors.lime),
              ),
            )
          else if (_slots.isEmpty)
            _emptySlotsCard()
          else
            Column(
              children: _slots.map((slot) => _slotCard(slot, _selectedTime == slot.time)).toList(),
            ),
          if (_selectedTime != null &&
              _selectedSlot != null &&
              _selectedSlot!.preparationTips.isNotEmpty &&
              !_selectedIsWaitlist) ...[
            const SizedBox(height: 20),
            PreparationTipsCard(tips: _selectedSlot!.preparationTips),
          ],
          if (_selectedTime != null && _selectedIsWaitlist) ...[
            const SizedBox(height: 20),
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Θα σε ενημερώσουμε αν ανοίξει θέση στη λίστα αναμονής.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (_nextAvailableSlotAfter(_selectedTime!) != null) ...[
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () {
                        final next = _nextAvailableSlotAfter(_selectedTime!);
                        if (next != null) _applySlotSelection(next);
                      },
                      child: Text(
                        'Ή κλείσε την επόμενη διαθέσιμη (${_nextAvailableSlotAfter(_selectedTime!)!.time})',
                        style: const TextStyle(color: AppColors.lime),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          ],
              ],
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              );
            },
            child: _selectedTime != null
                ? KeyedSubtree(
                    key: ValueKey('booking-panel-$_selectedTime'),
                    child: _buildStickyBookingPanel(
                      staffForTime: staffForTime,
                      needsChoice: needsChoice,
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('booking-panel-hidden')),
          ),
        ],
      ),
    );
  }
}
