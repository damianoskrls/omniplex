import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../config/tenant_config.dart';
import '../l10n/app_strings.dart';
import '../models/booking.dart';
import '../models/opening_hours.dart';
import '../models/service.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/language_service.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../widgets/ui_kit.dart';

const _minLeadMinutes = 15;

class RescheduleBookingScreen extends StatefulWidget {
  const RescheduleBookingScreen({super.key, required this.booking});

  final Booking booking;

  @override
  State<RescheduleBookingScreen> createState() => _RescheduleBookingScreenState();
}

class _RescheduleBookingScreenState extends State<RescheduleBookingScreen> {
  late DateTime _selectedDate;
  String? _selectedTime;
  StaffMember? _selectedStaff;
  List<TimeSlot> _slots = [];
  bool _hideStaffSelection = true;
  bool _loadingSlots = false;
  bool _submitting = false;
  String? _error;
  String? _slotsMessage;
  String? _dayStatus;
  OpeningHoursConfig? _openingHours;

  ApiService get _api => context.read<AuthService>().api;
  TenantConfig get _config => context.read<TenantConfig>();

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime(
      widget.booking.startsAt.year,
      widget.booking.startsAt.month,
      widget.booking.startsAt.day,
    );
    _selectedTime = DateFormat('HH:mm').format(widget.booking.startsAt);
    _initReschedule();
  }

  Future<void> _initReschedule() async {
    await _loadServiceMeta();
    final hours = await _api.fetchOpeningHours();
    if (!mounted) return;
    setState(() => _openingHours = hours);
    if (hours != null && !hours.isDateOpen(_selectedDate)) {
      final next = hours.nextOpenDate(from: DateTime.now());
      if (next != null) setState(() => _selectedDate = next);
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

  Future<void> _loadServiceMeta() async {
    try {
      final services = await _api.fetchServices();
      BookService? svc;
      for (final s in services) {
        if (s.id == widget.booking.serviceId) {
          svc = s;
          break;
        }
      }
      if (svc != null && mounted) {
        setState(() => _hideStaffSelection = svc!.hideStaffSelection);
      }
    } catch (_) {}
  }

  String get _dateStr => DateFormat('yyyy-MM-dd').format(_selectedDate);

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
    return slotStart.isAfter(DateTime.now().add(const Duration(minutes: _minLeadMinutes)));
  }

  List<TimeSlot> _filterPastSlots(List<TimeSlot> slots, String dateStr) {
    return slots.where((s) => _isSlotBookable(dateStr, s.time)).toList();
  }

  TimeSlot? get _selectedSlot {
    if (_selectedTime == null) return null;
    try {
      return _slots.firstWhere((s) => s.time == _selectedTime);
    } catch (_) {
      return null;
    }
  }

  List<StaffMember> get _staffForTime {
    final seen = <String>{};
    return (_selectedSlot?.availableStaff ?? [])
        .where((s) => seen.add(s.id))
        .toList();
  }

  bool get _needsStaffChoice => !_hideStaffSelection && _staffForTime.length > 1;

  Future<void> _loadSlots() async {
    setState(() {
      _loadingSlots = true;
      _error = null;
      _slotsMessage = null;
      _dayStatus = null;
    });
    try {
      final result = await _api.fetchSlots(
        serviceId: widget.booking.serviceId,
        date: _dateStr,
        excludeBookingId: widget.booking.id,
        locationId: widget.booking.locationId,
      );
      final filtered = _filterPastSlots(result.slots, _dateStr);
      setState(() {
        _slots = filtered;
        _dayStatus = result.dayStatus;
        _slotsMessage = result.message ??
            (filtered.isEmpty ? AppStrings.of(context).rescheduleNoSlotsMsg : null);
        if (_selectedTime != null &&
            !filtered.any((s) => s.time == _selectedTime && s.isBookable)) {
          _selectedTime = null;
          _selectedStaff = null;
        } else if (_selectedTime != null) {
          _autoSelectStaff();
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

  void _autoSelectStaff() {
    if (_hideStaffSelection || _selectedTime == null) return;
    final staff = _staffForTime;
    if (staff.length == 1) {
      _selectedStaff = staff.first;
    } else if (widget.booking.staffId != null) {
      _selectedStaff = staff.cast<StaffMember?>().firstWhere(
        (s) => s?.id == widget.booking.staffId,
        orElse: () => null,
      );
    }
  }

  void _selectTime(TimeSlot slot) {
    if (!slot.isBookable) return;
    setState(() {
      _selectedTime = slot.time;
      _selectedStaff = null;
      _autoSelectStaff();
    });
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

  Future<void> _save() async {
    if (_selectedTime == null) return;
    if (_needsStaffChoice && _selectedStaff == null) {
      setState(() => _error = 'Επίλεξε ${_config.label('staff_noun', 'γυμναστή')}');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final result = await _api.rescheduleBooking(
        bookingId: widget.booking.id,
        date: _dateStr,
        time: _selectedTime!,
        staffId: _hideStaffSelection ? null : _selectedStaff?.id,
      );

      final startsAt = DateTime.parse(result['starts_at'] as String).toLocal();
      final endsAt = DateTime.parse(result['ends_at'] as String).toLocal();

      await NotificationService.instance.scheduleBookingReminders(
        notificationId: widget.booking.id.hashCode.abs() % 50000,
        bookingId: widget.booking.id,
        serviceName: widget.booking.serviceName,
        startsAt: startsAt,
        endsAt: endsAt,
        preparationTips: widget.booking.preparationTips,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] as String? ?? 'Η κράτηση ενημερώθηκε')),
      );
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = LanguageService.instance.isGreek ? 'el_GR' : 'en_US';
    final dateFmt = DateFormat('EEE d MMM, HH:mm', locale);
    final staffNoun = _config.label('staff_noun', 'Γυμναστής');
    final s = AppStrings.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(s.rescheduleTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.booking.serviceName, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(
                  s.rescheduleCurrentDate(dateFmt.format(widget.booking.startsAt)),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(s.rescheduleNewDate, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          SurfaceCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.calendar_today, color: AppColors.purple),
              title: Text(DateFormat('EEEE d MMM yyyy', locale).format(_selectedDate)),
              trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
              onTap: _pickDate,
            ),
          ),
          const SizedBox(height: 24),
          Text(s.rescheduleNewTime, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          if (_loadingSlots)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: const CircularProgressIndicator(color: AppColors.lime),
              ),
            )
          else if (_slots.isEmpty)
            SurfaceCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _dayStatus == 'closed' ? Icons.storefront_outlined : Icons.event_busy_outlined,
                    color: _dayStatus == 'closed' ? AppColors.orange : AppColors.textSecondary,
                    size: 28,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_dayStatus == 'closed') ...[
                          Text(
                            s.rescheduleClosedDay,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.orange,
                                ),
                          ),
                          const SizedBox(height: 4),
                        ],
                        Text(
                          _slotsMessage ?? _error ?? s.rescheduleNoSlots,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _slots.where((s) => s.isBookable).map((slot) {
                final selected = _selectedTime == slot.time;
                return ChoiceChip(
                  label: Text(slot.time),
                  selected: selected,
                  onSelected: (_) => _selectTime(slot),
                  selectedColor: AppColors.lime.withValues(alpha: 0.25),
                  labelStyle: TextStyle(
                    color: selected ? AppColors.lime : AppColors.textPrimary,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                );
              }).toList(),
            ),
          if (_selectedTime != null && _staffForTime.isNotEmpty && !_hideStaffSelection) ...[
            const SizedBox(height: 24),
            Text(
              _needsStaffChoice ? 'Επίλεξε $staffNoun' : staffNoun,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            ..._staffForTime.map((staff) {
              final selected = _selectedStaff?.id == staff.id;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SurfaceCard(
                  child: ListTile(
                    title: Text(staff.fullName),
                    trailing: Icon(
                      selected ? Icons.check_circle : Icons.circle_outlined,
                      color: selected ? AppColors.lime : AppColors.border,
                    ),
                    onTap: _needsStaffChoice
                        ? () => setState(() => _selectedStaff = staff)
                        : null,
                  ),
                ),
              );
            }),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: AppColors.orange)),
          ],
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting || _selectedTime == null ? null : _save,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bg),
                    )
                  : Text(s.rescheduleSave),
            ),
          ),
        ],
      ),
    );
  }
}
