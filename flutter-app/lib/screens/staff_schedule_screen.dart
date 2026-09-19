import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../l10n/app_strings.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/language_service.dart';
import '../theme/app_colors.dart';
import '../widgets/ui_kit.dart';

class StaffScheduleScreen extends StatefulWidget {
  const StaffScheduleScreen({super.key});

  @override
  State<StaffScheduleScreen> createState() => _StaffScheduleScreenState();
}

class _StaffScheduleScreenState extends State<StaffScheduleScreen> {
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _bookings = [];
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
      final api  = context.read<AuthService>().api;
      final date = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final data = await api.fetchStaffSchedule(date: date);
      setState(() => _bookings = (data['bookings'] as List).cast<Map<String, dynamic>>());
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _prevDay() { setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 1))); _load(); }
  void _nextDay() { setState(() => _selectedDate = _selectedDate.add(const Duration(days: 1))); _load(); }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 180)),
      lastDate: DateTime.now().add(const Duration(days: 180)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(primary: AppColors.lime, surface: AppColors.surface),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
      _load();
    }
  }

  Future<void> _toggleAttendance(Map<String, dynamic> booking) async {
    final current = booking['attendance_confirmed'] == 1 || booking['attendance_confirmed'] == true;
    try {
      await context.read<AuthService>().api.markAttendance(
        booking['id'] as String, confirmed: !current,
      );
      _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  bool _isToday(DateTime d) {
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  @override
  Widget build(BuildContext context) {
    final locale = LanguageService.instance.isGreek ? 'el_GR' : 'en_US';
    final dayLabel = _isToday(_selectedDate)
        ? AppStrings.of(context).staffScheduleToday
        : DateFormat('EEEE, d MMM', locale).format(_selectedDate);

    return Column(
      children: [
        // Date navigation
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          color: AppColors.surface,
          child: Row(
            children: [
              IconButton(
                onPressed: _prevDay,
                icon: const Icon(Icons.chevron_left, color: AppColors.lime),
                padding: EdgeInsets.zero, constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: _pickDate,
                  child: Column(
                    children: [
                      Text(dayLabel,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary)),
                      Text(DateFormat('d MMMM yyyy', locale).format(_selectedDate),
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _nextDay,
                icon: const Icon(Icons.chevron_right, color: AppColors.lime),
                padding: EdgeInsets.zero, constraints: const BoxConstraints(),
              ),
              if (!_isToday(_selectedDate))
                TextButton(
                  onPressed: () { setState(() => _selectedDate = DateTime.now()); _load(); },
                  style: TextButton.styleFrom(foregroundColor: AppColors.lime, padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  child: Text(AppStrings.of(context).staffScheduleToday, style: const TextStyle(fontSize: 12)),
                ),
            ],
          ),
        ),

        // Bookings list
        Expanded(
          child: _loading
              ? Center(child: const CircularProgressIndicator(color: AppColors.lime))
              : _error != null
                  ? Center(child: Text(_error!))
                  : _bookings.isEmpty
                      ? EmptyState(
                          icon: Icons.calendar_today_outlined,
                          title: AppStrings.of(context).staffScheduleNoBookings,
                          subtitle: _isToday(_selectedDate)
                              ? AppStrings.of(context).staffScheduleNoneToday
                              : AppStrings.of(context).staffScheduleNoneDay,
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          color: AppColors.lime,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                            itemCount: _bookings.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (_, i) => _BookingCard(
                              booking: _bookings[i],
                              onToggleAttendance: () => _toggleAttendance(_bookings[i]),
                            ),
                          ),
                        ),
        ),
      ],
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking, required this.onToggleAttendance});
  final Map<String, dynamic> booking;
  final VoidCallback onToggleAttendance;

  String _timeRange(String? startsAt, String? endsAt) {
    if (startsAt == null) return '';
    try {
      final s = DateTime.parse(startsAt).toLocal();
      final fmt = DateFormat('HH:mm');
      if (endsAt == null) return fmt.format(s);
      final e = DateTime.parse(endsAt).toLocal();
      return '${fmt.format(s)} – ${fmt.format(e)}';
    } catch (_) { return startsAt; }
  }

  @override
  Widget build(BuildContext context) {
    final serviceName  = booking['service_name'] as String? ?? '';
    final serviceColor = booking['service_color'] as String?;
    final clientName   = booking['client_name'] as String? ?? '';
    final clientPhone  = booking['client_phone'] as String?;
    final locationName = booking['location_name'] as String?;
    final roomName     = booking['room_name'] as String?;
    final confirmed    = booking['attendance_confirmed'] == 1 || booking['attendance_confirmed'] == true;
    final isTrial      = booking['is_trial'] == 1 || booking['is_trial'] == true;
    final notes        = booking['notes'] as String?;
    final time         = _timeRange(booking['starts_at'] as String?, booking['ends_at'] as String?);

    Color accent = AppColors.lime;
    if (serviceColor != null && serviceColor.isNotEmpty) {
      try {
        accent = Color(int.parse(serviceColor.replaceAll('#', '0xFF')));
      } catch (_) {}
    }

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4, height: 44,
                decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(4)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(serviceName,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        ),
                        if (isTrial)
                          PillChip(label: AppStrings.of(context).staffScheduleTrial,
                              color: AppColors.purple.withValues(alpha: 0.15), textColor: AppColors.purple),
                      ],
                    ),
                    Text(time, style: TextStyle(fontSize: 13, color: accent, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Client
          Row(
            children: [
              const Icon(Icons.person_outline, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(child: Text(clientName, style: const TextStyle(fontWeight: FontWeight.w600))),
              if (clientPhone != null && clientPhone.isNotEmpty)
                Text(clientPhone, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
          if (locationName != null || roomName != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.place_outlined, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Text([locationName, roomName].whereType<String>().join(' · '),
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ],
            ),
          ],
          if (notes != null && notes.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.notes_outlined, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(child: Text(notes, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
              ],
            ),
          ],
          const SizedBox(height: 12),
          // Attendance toggle
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onToggleAttendance,
              icon: Icon(confirmed ? Icons.check_circle : Icons.radio_button_unchecked, size: 18),
              label: Text(confirmed ? AppStrings.of(context).staffScheduleConfirmed : AppStrings.of(context).staffScheduleConfirmAttendance),
              style: OutlinedButton.styleFrom(
                foregroundColor: confirmed ? AppColors.lime : AppColors.textSecondary,
                side: BorderSide(color: confirmed ? AppColors.lime : AppColors.border),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
