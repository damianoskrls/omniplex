import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/booking.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/preparation_tips_card.dart';
import '../widgets/ui_kit.dart';
import 'completed_bookings_screen.dart';
import 'reschedule_booking_screen.dart';
import 'workout_complete_screen.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  List<Booking> _bookings = [];
  List<WaitlistEntry> _waitlist = [];
  bool _loading = true;
  String? _error;
  final Set<String> _expandedTips = {};

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
      final api = context.read<AuthService>().api;
      final results = await Future.wait([
        api.fetchMyBookings(),
        api.fetchMyWaitlist(),
      ]);
      final bookings = results[0] as List<Booking>;
      final waitlistRaw = results[1] as List<Map<String, dynamic>>;
      setState(() {
        _bookings = bookings;
        _waitlist = waitlistRaw.map(WaitlistEntry.fromJson).toList();
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Booking> _sortedActive(List<Booking> source) {
    final active = source.where((b) => b.isActiveInList).toList();
    active.sort((a, b) {
      if (a.isUpcoming != b.isUpcoming) return a.isUpcoming ? -1 : 1;
      if (a.isUpcoming) return a.startsAt.compareTo(b.startsAt);
      return b.startsAt.compareTo(a.startsAt);
    });
    return active;
  }

  // Pending bookings awaiting admin confirmation — upcoming only (time not yet passed)
  List<Booking> get _pendingApproval {
    final now = DateTime.now();
    final list = _bookings
        .where((b) => b.status == 'pending' && b.startsAt.isAfter(now))
        .toList();
    list.sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return list;
  }

  List<Booking> get _gymBookings =>
      _sortedActive(_bookings.where((b) => !b.isNutritionConsultation && b.status != 'pending').toList());

  List<Booking> get _nutritionBookings =>
      _sortedActive(_bookings.where((b) => b.isNutritionConsultation && b.status != 'pending').toList());

  int get _completedCount => _bookings.where((b) => b.isCompleted).length;

  int get _upcomingCount =>
      _gymBookings.where((b) => b.isUpcoming).length +
      _nutritionBookings.where((b) => b.isUpcoming).length;

  List<Booking> get _pendingAttendance {
    final pending = _bookings.where((b) => b.needsCheckIn).toList();
    pending.sort((a, b) => b.startsAt.compareTo(a.startsAt));
    return pending;
  }

  void _openWorkoutComplete(Booking booking) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkoutCompleteScreen(
          booking: booking,
          api: context.read<AuthService>().api,
        ),
      ),
    ).then((_) => _load());
  }

  bool _isToday(DateTime dt) {
    final now = DateTime.now();
    return dt.year == now.year && dt.month == now.month && dt.day == now.day;
  }

  void _openCompleted() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CompletedBookingsScreen()),
    ).then((_) => _load());
  }

  Future<void> _leaveWaitlist(WaitlistEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Αποχώρηση από αναμονή'),
        content: Text('Να αφαιρεθείς από την αναμονή για ${entry.displayName};'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Όχι')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ναι', style: TextStyle(color: AppColors.orange)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await context.read<AuthService>().api.leaveWaitlist(entry.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Αφαιρέθηκες από τη λίστα αναμονής')),
        );
        _load();
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Widget _waitlistCard(WaitlistEntry entry) {
    final dateFmt = DateFormat('EEE d MMM, HH:mm', 'el_GR');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SurfaceCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 4,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.orange,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PillChip(
                    label: entry.statusLabel,
                    color: entry.isOffered
                        ? AppColors.lime.withValues(alpha: 0.15)
                        : AppColors.orange.withValues(alpha: 0.15),
                    textColor: entry.isOffered ? AppColors.lime : AppColors.orange,
                  ),
                  const SizedBox(height: 8),
                  Text(entry.displayName, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.schedule, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text(dateFmt.format(entry.startsAt), style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Θέση #${entry.position} στη λίστα αναμονής',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                  ),
                  if (entry.isOffered) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Άνοιξε θέση — θα ενημερωθείς μόλις επιβεβαιωθεί η κράτηση.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.lime,
                            fontSize: 13,
                          ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => _leaveWaitlist(entry),
                      child: const Text('Αποχώρηση από αναμονή', style: TextStyle(color: AppColors.orange)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cancel(Booking booking) async {
    final api = context.read<AuthService>().api;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Ακύρωση κράτησης'),
        content: Text('Να ακυρωθεί η κράτηση για ${booking.serviceName};'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Όχι')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ναι', style: TextStyle(color: AppColors.orange)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await api.cancelBooking(booking.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Η κράτηση ακυρώθηκε')),
        );
        _load();
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Widget _sectionHeader({
    required String title,
    required IconData icon,
    required Color color,
    required int count,
  }) {
    if (count == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _bookingCard(Booking booking, {required int index, required bool isFirstUpcoming}) {
    final dateFmt = DateFormat('EEE d MMM, HH:mm', 'el_GR');
    final accent = booking.isNutritionConsultation
        ? AppColors.pink
        : AppColors.cardGradient(index).first;
    final isNext = isFirstUpcoming && booking.isUpcoming;
    final nextLabel = isNext
        ? (_isToday(booking.startsAt) ? 'Σήμερα' : 'Επόμενο')
        : null;
    final isNutrition = booking.isNutritionConsultation;
    final tipsLabel = isNutrition ? 'Οδηγίες πριν τη συνεδρία' : 'Tips προετοιμασίας';
    final tipsTitle = isNutrition ? 'Πριν τη συνεδρία' : 'Έτοιμασου';
    final tipsIcon = isNutrition ? Icons.restaurant_outlined : Icons.lightbulb_outline;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SurfaceCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 4,
              height: 80,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (nextLabel != null) ...[
                    PillChip(
                      label: nextLabel,
                      color: AppColors.lime.withValues(alpha: 0.15),
                      textColor: AppColors.lime,
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(booking.serviceName, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.schedule, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text(dateFmt.format(booking.startsAt), style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                  if (booking.staffName.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          isNutrition ? Icons.medical_services_outlined : Icons.person_outline,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isNutrition ? 'Με ${booking.staffName}' : 'Με ${booking.staffName}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ],
                  if (booking.scheduleRoom != null && booking.scheduleRoom!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.meeting_room_outlined, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(booking.scheduleRoom!, style: Theme.of(context).textTheme.bodyMedium),
                              if (booking.roomShortInfo != null && booking.roomShortInfo!.isNotEmpty)
                                Text(
                                  booking.roomShortInfo!,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (booking.isUpcoming && booking.preparationTips.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          if (_expandedTips.contains(booking.id)) {
                            _expandedTips.remove(booking.id);
                          } else {
                            _expandedTips.add(booking.id);
                          }
                        });
                      },
                      icon: Icon(tipsIcon, size: 16),
                      label: Text(
                        _expandedTips.contains(booking.id) ? 'Κρύψε οδηγίες' : tipsLabel,
                      ),
                    ),
                    if (_expandedTips.contains(booking.id))
                      PreparationTipsCard(
                        tips: booking.preparationTips,
                        title: tipsTitle,
                        icon: tipsIcon,
                      ),
                  ],
                  Row(
                    children: [
                      _StatusChip(status: booking.status, needsCheckIn: booking.needsCheckIn),
                      const Spacer(),
                      if (booking.isInProgress)
                        TextButton(
                          onPressed: () => _openWorkoutComplete(booking),
                          child: const Text('Φωτό & Share'),
                        ),
                      if (booking.needsCheckIn)
                        TextButton(
                          onPressed: () => _openWorkoutComplete(booking),
                          child: const Text('Επιβεβαίωση'),
                        ),
                      if (booking.isUpcoming) ...[
                        TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RescheduleBookingScreen(booking: booking),
                            ),
                          ).then((changed) {
                            if (changed == true) _load();
                          }),
                          child: const Text('Αλλαγή'),
                        ),
                        TextButton(
                          onPressed: () => _cancel(booking),
                          style: TextButton.styleFrom(foregroundColor: AppColors.orange),
                          child: const Text('Ακύρωση'),
                        ),
                      ],
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

  List<Widget> _bookingSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Booking> bookings,
    required bool isFirstSection,
  }) {
    if (bookings.isEmpty) return [];
    final firstUpcomingId = bookings.where((b) => b.isUpcoming).map((b) => b.id).firstOrNull;
    return [
      _sectionHeader(title: title, icon: icon, color: color, count: bookings.length),
      ...List.generate(bookings.length, (index) {
        final booking = bookings[index];
        return _bookingCard(
          booking,
          index: index,
          isFirstUpcoming: isFirstSection && booking.id == firstUpcomingId,
        );
      }),
      const SizedBox(height: 8),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(child: const CircularProgressIndicator(color: AppColors.lime));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _load, child: const Text('Δοκίμασε ξανά')),
          ],
        ),
      );
    }

    final gym = _gymBookings;
    final nutrition = _nutritionBookings;
    final pendingApproval = _pendingApproval;
    final pendingAttendance = _pendingAttendance;
    final hasActive = gym.isNotEmpty || nutrition.isNotEmpty || _waitlist.isNotEmpty || pendingApproval.isNotEmpty;
    final upcoming = _upcomingCount;

    if (!hasActive && _completedCount == 0) {
      return const EmptyState(
        icon: Icons.calendar_today_outlined,
        title: 'Δεν έχεις κρατήσεις ακόμα',
        subtitle: 'Κλείσε το πρώτο σου ραντεβού από την καρτέλα Κράτηση.',
      );
    }

    return RefreshIndicator(
      color: AppColors.lime,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          if (pendingApproval.isNotEmpty) ...[
            _sectionHeader(
              title: 'Αναμονή επιβεβαίωσης',
              icon: Icons.pending_actions_rounded,
              color: AppColors.orange,
              count: pendingApproval.length,
            ),
            ...pendingApproval.asMap().entries.map((e) => _bookingCard(
              e.value,
              index: e.key,
              isFirstUpcoming: false,
            )),
            const SizedBox(height: 8),
          ],
          if (_waitlist.isNotEmpty) ...[
            _sectionHeader(
              title: 'Λίστα αναμονής',
              icon: Icons.hourglass_top_rounded,
              color: AppColors.orange,
              count: _waitlist.length,
            ),
            ..._waitlist.map(_waitlistCard),
            const SizedBox(height: 8),
          ],
          if (pendingAttendance.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: SurfaceCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.orange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.how_to_reg, color: AppColors.orange, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Εκκρεμεί επιβεβαίωση',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                '${pendingAttendance.length} προπόνηση${pendingAttendance.length == 1 ? '' : 'εις'} χωρίς check-in',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...pendingAttendance.take(3).map((booking) {
                      final dateFmt = DateFormat('EEE d MMM, HH:mm', 'el_GR');
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${booking.serviceName} · ${dateFmt.format(booking.startsAt)}',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                            TextButton(
                              onPressed: () => _openWorkoutComplete(booking),
                              child: const Text('Επιβεβαίωση'),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          if (_completedCount > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: GestureDetector(
                onTap: _openCompleted,
                child: SurfaceCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.teal.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.check_circle_outline, color: AppColors.teal, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ολοκληρωμένα',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              '$_completedCount προπονήσεις · στόχοι & KPIs',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),
            ),
          if (upcoming > 0)
            Padding(
              padding: EdgeInsets.only(bottom: hasActive ? 14 : 0),
              child: SurfaceCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.purple.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.upcoming, color: AppColors.purple, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        upcoming == 1
                            ? 'Επόμενο ραντεβού'
                            : '$upcoming επερχόμενα ραντεβού',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (!hasActive)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: EmptyState(
                icon: Icons.event_available_outlined,
                title: 'Δεν έχεις ενεργά ραντεβού',
                subtitle: 'Τα ολοκληρωμένα βρίσκονται παραπάνω.',
              ),
            )
          else ...[
            ..._bookingSection(
              title: 'Γυμναστήριο',
              icon: Icons.fitness_center,
              color: AppColors.teal,
              bookings: gym,
              isFirstSection: gym.isNotEmpty,
            ),
            ..._bookingSection(
              title: 'Διατροφολόγος',
              icon: Icons.restaurant,
              color: AppColors.pink,
              bookings: nutrition,
              isFirstSection: gym.isEmpty && nutrition.isNotEmpty,
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, this.needsCheckIn = false});
  final String status;
  final bool needsCheckIn;

  @override
  Widget build(BuildContext context) {
    final labels = {
      'confirmed': 'Επιβεβαιωμένη',
      'pending': 'Αναμονή επιβεβαίωσης',
      'cancelled': 'Ακυρωμένη',
      'completed': needsCheckIn ? 'Χωρίς check-in' : 'Ολοκληρωμένη',
      'no_show': 'Απόντας',
    };
    final colors = {
      'confirmed': AppColors.lime,
      'pending': AppColors.orange,
      'cancelled': AppColors.textSecondary,
      'completed': needsCheckIn ? AppColors.orange : AppColors.teal,
      'no_show': AppColors.pink,
    };
    final color = colors[status] ?? AppColors.textSecondary;

    return PillChip(
      label: labels[status] ?? status,
      color: color.withValues(alpha: 0.15),
      textColor: color,
    );
  }
}
