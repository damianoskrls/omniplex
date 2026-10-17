import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../config/tenant_config.dart';
import '../services/auth_service.dart';
import '../widgets/omni_design.dart';
import 'staff_clients_screen.dart';
import 'staff_leaves_screen.dart';
import 'staff_messages_screen.dart';
import 'staff_schedule_screen.dart';
import '../l10n/tr.dart';


class StaffHomeScreen extends StatefulWidget {
  const StaffHomeScreen({super.key, this.onSwitchGym, this.onRemoveGym});
  final VoidCallback? onSwitchGym;
  final Future<void> Function()? onRemoveGym;

  @override
  State<StaffHomeScreen> createState() => _StaffHomeScreenState();
}

class _StaffHomeScreenState extends State<StaffHomeScreen> {
  static const _kDark16   = Color(0xFF161616);
  static const _kDark1C   = Color(0xFF1C1C1C);
  static const _kBorder26 = Color(0xFF262626);
  static const _kGray6B   = Color(0xFF6B7280);
  static const _kGray9C   = Color(0xFF9CA3AF);

  int _tab = 0;
  List<Map<String, dynamic>> _todayBookings   = [];
  List<Map<String, dynamic>> _unassignedTrials = [];
  bool _loadingSchedule = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loadingSchedule = true);
    try {
      final api  = context.read<AuthService>().api;
      final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final results = await Future.wait([
        api.fetchStaffSchedule(date: date),
        api.fetchStaffTrials(),
      ]);
      if (mounted) {
        final bookings = ((results[0] as Map<String, dynamic>)['bookings'] as List? ?? []);
        final trials   = results[1] as List;
        setState(() {
          _todayBookings    = bookings.cast<Map<String, dynamic>>();
          _unassignedTrials = trials
              .cast<Map<String, dynamic>>()
              .where((t) => t['staff_id'] == null)
              .toList();
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingSchedule = false);
    }
  }

  // ── derived stats ──────────────────────────────────────────────────────────

  int get _assignedCount =>
      _todayBookings.where((b) => b['status'] != 'cancelled').length;

  int get _trialsCompleted => _todayBookings.where((b) =>
      (b['is_trial'] as int? ?? 0) == 1 && b['status'] == 'completed').length;

  int get _minutesRemaining {
    final now = DateTime.now();
    int mins  = 0;
    for (final b in _todayBookings) {
      if (b['status'] == 'cancelled') continue;
      final start = DateTime.tryParse(b['starts_at'] as String? ?? '');
      final end   = DateTime.tryParse(b['ends_at']   as String? ?? '');
      if (start == null || end == null || !end.isAfter(now)) continue;
      mins += end.difference(start.isAfter(now) ? start : now).inMinutes;
    }
    return mins;
  }

  // ── Scaffold ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final auth   = context.watch<AuthService>();
    final config = context.read<TenantConfig>();
    final user   = auth.user;

    return Scaffold(
      backgroundColor: kBg,
      body: IndexedStack(
        index: _tab,
        children: [
          _buildHomeTab(user, config),
          const StaffScheduleScreen(),
          const StaffMessagesScreen(),
          const StaffLeavesScreen(),
          const StaffClientsScreen(),
          _buildProfileTab(user, config),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── HOME TAB ───────────────────────────────────────────────────────────────

  Widget _buildHomeTab(user, TenantConfig config) {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: kLime,
      backgroundColor: _kDark16,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(user, config)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
            sliver: SliverList(delegate: SliverChildListDelegate([
              const SizedBox(height: 24),
              _buildStatsRow(),
              const SizedBox(height: 28),
              _buildSessionsSection(),
              if (_unassignedTrials.isNotEmpty) ...[
                const SizedBox(height: 28),
                _buildUnassignedTrialsSection(),
              ],
            ])),
          ),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(user, TenantConfig config) {
    final now     = DateTime.now();
    final gymName = config.appName;
    final role    = user?.staffRole?.isNotEmpty == true ? user!.staffRole : 'Trainer';
    final initial = gymName.isNotEmpty ? gymName[0].toUpperCase() : 'G';
    final dateStr = _fmtHeaderDate(now);

    return Container(
      decoration: BoxDecoration(
        color: kBg,
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Gym identity row
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: kLime, borderRadius: BorderRadius.circular(12)),
            child: Center(child: Text(initial, style: GoogleFonts.inter(
              fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr(gymName.toUpperCase()), style: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.w800,
              color: Colors.white, letterSpacing: 0.4)),
            Text(tr('${user?.fullName ?? ''} · $role workspace'),
              style: GoogleFonts.inter(fontSize: 12, color: _kGray9C)),
          ])),
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: _kDark16,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kBorder26),
            ),
            child: const Center(child: Icon(Icons.notifications_outlined, color: Colors.white, size: 20)),
          ),
        ]),
        const SizedBox(height: 20),
        // Big title
        Text(tr('Το πρόγραμμά μου σήμερα'), style: GoogleFonts.inter(
          fontSize: 26, fontWeight: FontWeight.w800,
          color: Colors.white, letterSpacing: -0.6, height: 1.15)),
        const SizedBox(height: 5),
        Text(tr(dateStr), style: GoogleFonts.inter(fontSize: 13, color: _kGray6B)),
      ]),
    );
  }

  String _fmtHeaderDate(DateTime d) {
    final day  = DateFormat('EEEE', 'el_GR').format(d);
    final rest = DateFormat('d MMMM yyyy', 'el_GR').format(d);
    return '$day, $rest · Athens (EEST)';
  }

  // ── Stats row ──────────────────────────────────────────────────────────────

  Widget _buildStatsRow() {
    final mins    = _minutesRemaining;
    final minsStr = mins >= 60
        ? '${(mins / 60).floor()}h${mins % 60 > 0 ? ' ${mins % 60}m' : ''}'
        : '${mins}m';

    final stats = [
      _StatItem(value: _loadingSchedule ? '–' : '$_assignedCount',
          label: tr('Ανατεθειμένες\nσήμερα')),
      _StatItem(value: _loadingSchedule ? '–' : '$_trialsCompleted',
          label: tr('Trial\nολοκληρώθηκε'), highlighted: _trialsCompleted > 0),
      _StatItem(value: _loadingSchedule ? '–' : minsStr,
          label: tr('Ακόμα να\nκοάρεις')),
    ];

    return Row(
      children: stats.asMap().entries.map((e) {
        final s = e.value;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: e.key < stats.length - 1 ? 10 : 0),
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
            decoration: BoxDecoration(
              color: s.highlighted ? const Color(0xFF252A00) : _kDark16,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: s.highlighted ? kLime.withValues(alpha: 0.5) : _kBorder26),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.value, style: GoogleFonts.inter(
                fontSize: 28, fontWeight: FontWeight.w800, height: 1.1,
                color: s.highlighted ? kLime : Colors.white)),
              const SizedBox(height: 4),
              Text(s.label, style: GoogleFonts.inter(
                fontSize: 11, color: _kGray9C, height: 1.3)),
            ]),
          ),
        );
      }).toList(),
    );
  }

  // ── Sessions section ───────────────────────────────────────────────────────

  Widget _buildSessionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(tr('Οι κρατήσεις μου'), style: GoogleFonts.inter(
            fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
          GestureDetector(
            onTap: () => setState(() => _tab = 1),
            child: Text(tr('Εβδομαδιαία ▸'), style: GoogleFonts.inter(
              fontSize: 12, fontWeight: FontWeight.w600, color: kLime)),
          ),
        ]),
        const SizedBox(height: 14),
        if (_loadingSchedule)
          const Center(child: Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(color: kLime, strokeWidth: 2)))
        else if (_todayBookings.isEmpty)
          _buildEmptySchedule()
        else
          ..._todayBookings.map(_buildSessionCard),
      ],
    );
  }

  Widget _buildEmptySchedule() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: _kDark16,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder26),
      ),
      child: Center(child: Column(children: [
        Icon(Icons.event_available_outlined, color: _kGray6B, size: 32),
        const SizedBox(height: 8),
        Text(tr('Δεν υπάρχουν κρατήσεις σήμερα'),
          style: GoogleFonts.inter(fontSize: 13, color: _kGray6B)),
      ])),
    );
  }

  Widget _buildSessionCard(Map<String, dynamic> b) {
    final now      = DateTime.now();
    final startsAt = DateTime.tryParse(b['starts_at'] as String? ?? '');
    final endsAt   = DateTime.tryParse(b['ends_at']   as String? ?? '');
    if (startsAt == null) return const SizedBox.shrink();

    final isTrial    = (b['is_trial'] as int? ?? 0) == 1;
    final status     = (b['status'] as String? ?? '').toLowerCase();
    final isCancelled= status == 'cancelled';
    final isDone     = status == 'completed' || (!isCancelled && endsAt != null && endsAt.isBefore(now));
    final isActive   = !isDone && !isCancelled && startsAt.isBefore(now) && (endsAt?.isAfter(now) ?? false);

    final startStr   = DateFormat('HH:mm').format(startsAt);
    final endStr     = endsAt != null ? DateFormat('HH:mm').format(endsAt) : '';
    final client     = b['client_name'] as String? ?? '';
    final service    = b['service_name'] as String? ?? tr('Συνεδρία');
    final location   = b['room_name'] as String? ?? b['location_name'] as String? ?? '';
    final capacity   = b['capacity'] as int?;
    final enrolled   = b['enrolled_count'] as int? ?? b['athlete_count'] as int?;

    final title = isTrial && client.isNotEmpty ? '1:1 · $client' : service;
    final detailParts = <String>[];
    if (enrolled != null && capacity != null) detailParts.add('$enrolled / $capacity athletes');
    if (isTrial && service.isNotEmpty) detailParts.add(tr('Trial · ${tr(service)}'));
    if (location.isNotEmpty) detailParts.add(tr(location));

    return Opacity(
      opacity: isCancelled ? 0.45 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isActive ? _kDark1C : _kDark16,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? kLime.withValues(alpha: 0.35) : _kBorder26),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Time column
          Container(
            width: 58,
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: _kBorder26))),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(startStr, style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w700,
                color: isActive ? kLime : Colors.white)),
              if (endStr.isNotEmpty)
                Text(endStr, style: GoogleFonts.inter(fontSize: 11, color: _kGray6B)),
            ]),
          ),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 14, 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(tr(title), style: GoogleFonts.inter(
                    fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white))),
                  if (isTrial)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: kLime.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: kLime.withValues(alpha: 0.4)),
                      ),
                      child: Text(tr('TRIAL'), style: GoogleFonts.inter(
                        fontSize: 9, fontWeight: FontWeight.w800,
                        color: kLime, letterSpacing: 0.5)),
                    ),
                ]),
                if (detailParts.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(detailParts.join(' · '),
                    style: GoogleFonts.inter(fontSize: 12, color: _kGray9C)),
                ],
                const SizedBox(height: 8),
                _buildStatusRow(isDone, isActive, isTrial, isCancelled),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildStatusRow(bool isDone, bool isActive, bool isTrial, bool isCancelled) {
    Color  dot;
    String label;
    String? action;

    if (isCancelled) {
      dot = Colors.redAccent; label = tr('Ακυρώθηκε'); action = null;
    } else if (isDone) {
      dot = kLime; label = tr('Ολοκληρώθηκε');
      action = isTrial ? tr('Προσθήκη αναφοράς ↗') : tr('Εμφάνιση ↗');
    } else if (isActive) {
      dot = kLime; label = tr('Σε εξέλιξη'); action = tr('Άνοιγμα ↗');
    } else {
      dot = kCyan; label = tr('Επερχόμενο'); action = tr('Λίστα ↗');
    }

    return Row(children: [
      Container(width: 7, height: 7,
        decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(label, style: GoogleFonts.inter(fontSize: 12, color: _kGray9C)),
      if (action != null) ...[
        Text(' · ', style: GoogleFonts.inter(fontSize: 12, color: _kGray6B)),
        Text(action, style: GoogleFonts.inter(
          fontSize: 12, fontWeight: FontWeight.w600, color: kLime)),
      ],
    ]);
  }

  // ── Unassigned trials ──────────────────────────────────────────────────────

  Widget _buildUnassignedTrialsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(tr('Trial χρειάζεται προπονητή'), style: GoogleFonts.inter(
            fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
          GestureDetector(
            onTap: () => setState(() => _tab = 1),
            child: Text(tr('Όλα τα trials ↗'), style: GoogleFonts.inter(
              fontSize: 12, fontWeight: FontWeight.w600, color: kLime)),
          ),
        ]),
        const SizedBox(height: 12),
        ..._unassignedTrials.take(3).map(_buildUnassignedTrialCard),
      ],
    );
  }

  Widget _buildUnassignedTrialCard(Map<String, dynamic> t) {
    final api        = context.read<AuthService>().api;
    final bookingId  = t['id']?.toString() ?? '';
    final clientName = t['client_name'] as String? ?? tr('Αθλητής');
    final service    = t['service_name'] as String? ?? tr('Συνεδρία');
    final location   = t['room_name'] as String? ?? t['location_name'] as String? ?? '';
    final startsAt   = DateTime.tryParse(t['starts_at'] as String? ?? '');
    final endsAt     = DateTime.tryParse(t['ends_at']   as String? ?? '');
    final isToday    = startsAt != null &&
        startsAt.day == DateTime.now().day && startsAt.month == DateTime.now().month;
    String dateLabel = '';
    if (startsAt != null) {
      final timeStr = endsAt != null
          ? '${DateFormat('HH:mm').format(startsAt)}–${DateFormat('HH:mm').format(endsAt)}'
          : DateFormat('HH:mm').format(startsAt);
      dateLabel = isToday ? tr('Σήμερα · $timeStr')
          : DateFormat('d MMM · HH:mm', 'el_GR').format(startsAt);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _kDark16,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder26),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
              ),
              child: Text(tr('ΑΝΑΘΕΤΕΟ'), style: GoogleFonts.inter(
                fontSize: 9, fontWeight: FontWeight.w800,
                color: Colors.orange, letterSpacing: 0.5)),
            ),
            if (dateLabel.isNotEmpty) ...[
              const SizedBox(width: 10),
              Text(dateLabel, style: GoogleFonts.inter(fontSize: 12, color: _kGray9C)),
            ],
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
          child: Text(tr(clientName), style: GoogleFonts.inter(
            fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
          child: Text(
            [tr(service), if (location.isNotEmpty) tr(location)].join(' · '),
            style: GoogleFonts.inter(fontSize: 12, color: _kGray9C)),
        ),
        Container(height: 1, color: _kBorder26),
        GestureDetector(
          onTap: () async {
            try {
              await api.claimTrial(bookingId);
              if (mounted) {
                setState(() => _unassignedTrials
                    .removeWhere((x) => x['id']?.toString() == bookingId));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(tr('Αναλήφθηκε το trial!')),
                  backgroundColor: kLime.withValues(alpha: 0.85)));
              }
            } catch (_) {}
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: kLime,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(15)),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.person_add_rounded, color: Colors.black, size: 18),
              const SizedBox(width: 8),
              Text(tr('Ανάθεση σε εμένα'), style: GoogleFonts.inter(
                fontSize: 14, fontWeight: FontWeight.w800, color: Colors.black)),
            ]),
          ),
        ),
      ]),
    );
  }

  // ── PROFILE TAB ────────────────────────────────────────────────────────────

  Widget _buildProfileTab(user, TenantConfig config) {
    final auth = context.read<AuthService>();
    return Scaffold(
      backgroundColor: kBg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 72, 24, 100),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr('ΠΡΟΦΙΛ'), style: GoogleFonts.inter(
            fontSize: 14, fontWeight: FontWeight.w700, color: kCyan, letterSpacing: 1.4)),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _kDark16,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _kBorder26),
            ),
            child: Row(children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF2A3A2A),
                  border: Border.all(color: kLime.withValues(alpha: 0.4)),
                ),
                child: const Icon(Icons.person_rounded, color: kLime, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr(user?.fullName ?? ''), style: GoogleFonts.inter(
                  fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 4),
                Text(
                  tr('${user?.staffRole?.isNotEmpty == true ? user!.staffRole : 'Trainer'} · ${config.appName}'),
                  style: GoogleFonts.inter(fontSize: 12, color: _kGray9C),
                ),
                if ((user?.email ?? '').isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(tr(user!.email), style: GoogleFonts.inter(fontSize: 12, color: _kGray6B)),
                ],
              ])),
            ]),
          ),
          if ((user?.bio ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _kDark16,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _kBorder26),
              ),
              child: Text(tr(user!.bio!.trim()), style: GoogleFonts.inter(
                fontSize: 13, color: Colors.white70, height: 1.4)),
            ),
          ],
          const SizedBox(height: 32),
          if (widget.onSwitchGym != null)
            _profileAction(
              icon: Icons.swap_horiz_rounded,
              label: tr('Αλλαγή γυμναστηρίου'),
              color: kCyan, onTap: widget.onSwitchGym!),
          if (widget.onRemoveGym != null) ...[
            const SizedBox(height: 12),
            _profileAction(
              icon: Icons.remove_circle_outline_rounded,
              label: tr('Αφαίρεση ως trainer'),
              color: Colors.redAccent,
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: const Color(0xFF161616),
                    title: Text(tr('Αφαίρεση γυμναστηρίου'),
                      style: const TextStyle(color: Colors.white)),
                    content: Text(
                      tr('Θα αφαιρεθείς ως trainer από το ${config.appName}.'),
                      style: const TextStyle(color: Colors.white70)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false),
                        child: Text(tr('Άκυρο'))),
                      TextButton(onPressed: () => Navigator.pop(ctx, true),
                        child: Text(tr('Αφαίρεση'),
                          style: const TextStyle(color: Colors.redAccent))),
                    ],
                  ),
                );
                if (confirmed != true) return;
                await widget.onRemoveGym!();
              },
            ),
          ],
          const SizedBox(height: 12),
          _profileAction(
            icon: Icons.logout_rounded,
            label: tr('Αποσύνδεση από γυμναστήριο'),
            color: Colors.redAccent,
            onTap: () async { await auth.logout(); }),
        ]),
      ),
    );
  }

  Widget _profileAction({required IconData icon, required String label,
      required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _kDark16,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kBorder26),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Text(tr(label), style: GoogleFonts.inter(
            fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
          const Spacer(),
          Icon(Icons.chevron_right_rounded, color: _kGray6B, size: 20),
        ]),
      ),
    );
  }

  // ── BOTTOM NAV ─────────────────────────────────────────────────────────────

  Widget _buildBottomNav() {
    final items = [
      (Icons.home_filled,             tr('ΑΡΧΙΚΗ')),
      (Icons.calendar_today,          tr('ΠΡΟΓΡΑΜΜΑ')),
      (Icons.send_outlined,           tr('ΜΗΝΥΜΑΤΑ')),
      (Icons.flight_takeoff_outlined, tr('ΑΔΕΙΑ')),
      (Icons.people_outline_rounded,  tr('ΠΕΛΑΤΕΣ')),
      (Icons.person_outline_rounded,  tr('ΠΡΟΦΙΛ')),
    ];

    return Container(
      decoration: BoxDecoration(
        color: kBg.withValues(alpha: 0.97),
        border: const Border(top: BorderSide(color: Color(0xFF262626))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: items.asMap().entries.map((e) {
              final active = _tab == e.key;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _tab = e.key),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(e.value.$1, color: active ? kLime : _kGray6B, size: 20),
                    const SizedBox(height: 4),
                    Text(e.value.$2, style: GoogleFonts.inter(
                      fontSize: 8, fontWeight: FontWeight.w700,
                      color: active ? kLime : _kGray6B, letterSpacing: 0.9),
                      textAlign: TextAlign.center),
                  ]),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// ── Value objects ──────────────────────────────────────────────────────────────

class _StatItem {
  const _StatItem({required this.value, required this.label, this.highlighted = false});
  final String value;
  final String label;
  final bool highlighted;
}
