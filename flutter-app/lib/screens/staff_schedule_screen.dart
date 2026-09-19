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

class _StaffScheduleScreenState extends State<StaffScheduleScreen>
    with SingleTickerProviderStateMixin {
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _bookings = [];
  List<Map<String, dynamic>> _trials = [];
  bool _loading = true;
  String? _error;
  late final TabController _tabController;
  String? _myStaffId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final auth = context.read<AuthService>();
    _myStaffId = auth.staffId;
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api  = context.read<AuthService>().api;
      final date = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final scheduleData = await api.fetchStaffSchedule(date: date);
      final trialsData   = await api.fetchStaffTrials();
      if (mounted) setState(() {
        _bookings = (scheduleData['bookings'] as List).cast<Map<String, dynamic>>();
        _trials   = trialsData.cast<Map<String, dynamic>>();
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
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

  Future<void> _claimBooking(String bookingId) async {
    try {
      await context.read<AuthService>().api.claimBooking(bookingId);
      _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _claimTrial(Map<String, dynamic> trial) async {
    final notesCtrl = TextEditingController(text: trial['notes'] as String? ?? '');
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _TrialClaimSheet(trial: trial, notesCtrl: notesCtrl, isClaim: true),
    );
    if (confirmed != true) return;
    try {
      await context.read<AuthService>().api.claimTrial(
        trial['id'] as String,
        notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Το δοκιμαστικό ανατέθηκε σε εσάς'), backgroundColor: Color(0xFF16A34A)));
      _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _editTrialNote(Map<String, dynamic> trial) async {
    final notesCtrl = TextEditingController(text: trial['notes'] as String? ?? '');
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _TrialClaimSheet(trial: trial, notesCtrl: notesCtrl, isClaim: false),
    );
    if (confirmed != true) return;
    try {
      await context.read<AuthService>().api.updateTrialNote(
        trial['id'] as String, notesCtrl.text.trim(),
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
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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

        // Tabs
        Container(
          color: AppColors.surface,
          child: TabBar(
            controller: _tabController,
            labelColor: AppColors.lime,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.lime,
            indicatorSize: TabBarIndicatorSize.tab,
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 16),
                    const SizedBox(width: 6),
                    Text('Κρατήσεις${_bookings.isNotEmpty ? ' (${_bookings.length})' : ''}'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.person_search_outlined, size: 16),
                    const SizedBox(width: 6),
                    Text('Δοκιμαστικά${_trials.isNotEmpty ? ' (${_trials.length})' : ''}'),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Tab views
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.lime))
              : _error != null
                  ? Center(child: Text(_error!))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        // ── Bookings tab ──
                        _bookings.isEmpty
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
                                    myStaffId: _myStaffId,
                                    onToggleAttendance: () => _toggleAttendance(_bookings[i]),
                                    onClaim: () => _claimBooking(_bookings[i]['id'] as String),
                                  ),
                                ),
                              ),

                        // ── Trials tab ──
                        _trials.isEmpty
                            ? const EmptyState(
                                icon: Icons.person_search_outlined,
                                title: 'Δεν υπάρχουν δοκιμαστικά',
                                subtitle: 'Τα δοκιμαστικά του γυμναστηρίου εμφανίζονται εδώ.',
                              )
                            : RefreshIndicator(
                                onRefresh: _load,
                                color: AppColors.lime,
                                child: ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                                  itemCount: _trials.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                                  itemBuilder: (_, i) => _TrialCard(
                                    trial: _trials[i],
                                    myStaffId: _myStaffId,
                                    onClaim: () => _claimTrial(_trials[i]),
                                    onEditNote: () => _editTrialNote(_trials[i]),
                                  ),
                                ),
                              ),
                      ],
                    ),
        ),
      ],
    );
  }
}

// ── Booking Card ───────────────────────────────────────────────────────────────

class _BookingCard extends StatelessWidget {
  const _BookingCard({
    required this.booking,
    required this.onToggleAttendance,
    required this.onClaim,
    this.myStaffId,
  });
  final Map<String, dynamic> booking;
  final VoidCallback onToggleAttendance;
  final VoidCallback onClaim;
  final String? myStaffId;

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
    final notes        = booking['notes'] as String?;
    final time         = _timeRange(booking['starts_at'] as String?, booking['ends_at'] as String?);
    final assignedStaffId = booking['staff_id'] as String?;
    final isMine = assignedStaffId != null && myStaffId != null && assignedStaffId == myStaffId;

    Color accent = AppColors.lime;
    if (serviceColor != null && serviceColor.isNotEmpty) {
      try { accent = Color(int.parse(serviceColor.replaceAll('#', '0xFF'))); } catch (_) {}
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
                        Expanded(child: Text(serviceName,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
                        if (isMine)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.lime.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('Δικό μου',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.lime)),
                          ),
                      ],
                    ),
                    Text(time, style: TextStyle(fontSize: 13, color: accent, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
          Row(
            children: [
              // Claim button (only if not assigned to me)
              if (!isMine) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onClaim,
                    icon: const Icon(Icons.add_task, size: 16),
                    label: const Text('Ανάθεση σε μένα'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              // Attendance toggle
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onToggleAttendance,
                  icon: Icon(confirmed ? Icons.check_circle : Icons.radio_button_unchecked, size: 18),
                  label: Text(confirmed
                      ? AppStrings.of(context).staffScheduleConfirmed
                      : AppStrings.of(context).staffScheduleConfirmAttendance),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: confirmed ? AppColors.lime : AppColors.textSecondary,
                    side: BorderSide(color: confirmed ? AppColors.lime : AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Trial Card ─────────────────────────────────────────────────────────────────

class _TrialCard extends StatelessWidget {
  const _TrialCard({
    required this.trial,
    required this.onClaim,
    required this.onEditNote,
    this.myStaffId,
  });
  final Map<String, dynamic> trial;
  final VoidCallback onClaim;
  final VoidCallback onEditNote;
  final String? myStaffId;

  String _fmtDate(String? iso) {
    if (iso == null) return '';
    try {
      final d = DateTime.parse(iso).toLocal();
      return DateFormat('d MMM yyyy, HH:mm').format(d);
    } catch (_) { return iso; }
  }

  @override
  Widget build(BuildContext context) {
    final userName    = trial['user_name'] as String? ?? '';
    final userPhone   = trial['user_phone'] as String?;
    final serviceName = trial['service_name'] as String?;
    final notes       = trial['notes'] as String?;
    final assignedStaffId = trial['staff_id'] as String?;
    final assignedStaffName = trial['staff_name'] as String?;
    final isMine = assignedStaffId != null && myStaffId != null && assignedStaffId == myStaffId;
    final isUnassigned = assignedStaffId == null;

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4, height: 44,
                decoration: BoxDecoration(
                  color: AppColors.purple, borderRadius: BorderRadius.circular(4)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(userName,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.purple.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('Δοκιμαστικό',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.purple)),
                        ),
                      ],
                    ),
                    if (serviceName != null)
                      Text(serviceName,
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(_fmtDate(trial['starts_at'] as String?),
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          if (userPhone != null && userPhone.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.phone_outlined, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(userPhone, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ],

          // Assignment row
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.person_pin_outlined, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: isUnassigned
                    ? const Text('Μη αναθεμένο',
                        style: TextStyle(fontSize: 12, color: AppColors.orange))
                    : Text(
                        isMine ? 'Δικό μου' : (assignedStaffName ?? 'Άλλος γυμναστής'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isMine ? AppColors.lime : AppColors.textSecondary,
                        ),
                      ),
              ),
            ],
          ),

          // Notes
          if (notes != null && notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.notes_outlined, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(child: Text(notes,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),
          Row(
            children: [
              if (isUnassigned || !isMine) ...[
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onClaim,
                    icon: const Icon(Icons.add_task, size: 16),
                    label: const Text('Ανάθεση σε μένα'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEditNote,
                  icon: const Icon(Icons.edit_note_outlined, size: 16),
                  label: const Text('Σχόλιο'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Trial Claim / Note Sheet ───────────────────────────────────────────────────

class _TrialClaimSheet extends StatelessWidget {
  const _TrialClaimSheet({
    required this.trial,
    required this.notesCtrl,
    required this.isClaim,
  });
  final Map<String, dynamic> trial;
  final TextEditingController notesCtrl;
  final bool isClaim;

  @override
  Widget build(BuildContext context) {
    final userName = trial['user_name'] as String? ?? '';
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isClaim ? 'Ανάθεση δοκιμαστικού' : 'Σχόλιο για δοκιμαστικό',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 4),
          Text(userName, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          TextField(
            controller: notesCtrl,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Σχόλιο / Παρατήρηση',
              hintText: 'π.χ. Σκέφτεται να γίνει μέλος, ενδιαφέρεται για το πακέτο X...',
              prefixIcon: Icon(Icons.notes_outlined, color: AppColors.textSecondary),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: isClaim ? AppColors.purple : AppColors.lime,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(isClaim ? 'Ανάθεση σε μένα' : 'Αποθήκευση',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
