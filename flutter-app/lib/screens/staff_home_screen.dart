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

class StaffHomeScreen extends StatefulWidget {
  const StaffHomeScreen({super.key, this.onSwitchGym, this.onRemoveGym});
  final VoidCallback? onSwitchGym;
  final Future<void> Function()? onRemoveGym;

  @override
  State<StaffHomeScreen> createState() => _StaffHomeScreenState();
}

class _StaffHomeScreenState extends State<StaffHomeScreen> {
  static const _kGray6B = Color(0xFF6B7280);
  static const _kGray9C = Color(0xFF9CA3AF);
  static const _kDark16 = Color(0xFF161616);
  static const _kDark1C = Color(0xFF1C1C1C);
  static const _kBorder26 = Color(0xFF262626);

  int _tab = 0;
  List<Map<String, dynamic>> _todayBookings = [];
  bool _loadingSchedule = true;

  @override
  void initState() {
    super.initState();
    _loadTodaySchedule();
  }

  Future<void> _loadTodaySchedule() async {
    setState(() => _loadingSchedule = true);
    try {
      final api = context.read<AuthService>().api;
      final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final result = await api.fetchStaffSchedule(date: date);
      if (mounted) {
        setState(() {
          _todayBookings = (result['bookings'] as List).cast<Map<String, dynamic>>();
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingSchedule = false);
    }
  }

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
    final now = DateTime.now();
    final greeting = now.hour < 12 ? 'Καλημέρα' : now.hour < 18 ? 'Καλό απόγευμα' : 'Καλό βράδυ';
    final gymName  = config.appName.toUpperCase();

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _loadTodaySchedule,
          color: kLime,
          backgroundColor: _kDark16,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(greeting, user?.fullName ?? '', gymName),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      _buildSummaryCard(now),
                      const SizedBox(height: 32),
                      _buildQuickActionsSection(),
                      const SizedBox(height: 32),
                      _buildScheduleSection(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(String greeting, String name, String gymName) {
    return Container(
      decoration: BoxDecoration(
        color: kBg.withValues(alpha: 0.90),
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      padding: const EdgeInsets.fromLTRB(24, 56, 24, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(greeting, style: GoogleFonts.manrope(fontSize: 14, color: _kGray9C)),
              const SizedBox(height: 3),
              Text(name, style: GoogleFonts.spaceGrotesk(
                fontSize: 24, fontWeight: FontWeight.w700,
                color: Colors.white, letterSpacing: -0.6)),
              const SizedBox(height: 3),
              GestureDetector(
                onTap: widget.onSwitchGym,
                child: Row(
                  children: [
                    Text(gymName, style: GoogleFonts.manrope(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: kCyan, letterSpacing: 1.1)),
                    if (widget.onSwitchGym != null) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.swap_horiz_rounded, color: kCyan, size: 14),
                    ],
                  ],
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: () {
              // future: open notifications
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: _kDark16,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _kBorder26),
                  ),
                  child: const Center(child: Icon(Icons.notifications_outlined, color: Colors.white, size: 20)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(DateTime now) {
    final dateStr  = DateFormat('EEEE d MMMM', 'el_GR').format(now);
    final pending  = _todayBookings.where((b) => b['status'] != 'cancelled').length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment(-0.85, -1),
          end: Alignment(0.85, 1),
          colors: [Color(0x66262626), Color(0x99161616)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border(
          left: const BorderSide(color: kLime, width: 4),
          top: BorderSide(color: kLime.withValues(alpha: 0.50)),
          right: BorderSide(color: kLime.withValues(alpha: 0.50)),
          bottom: BorderSide(color: kLime.withValues(alpha: 0.50)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              color: const Color(0xFF1A2A1A),
            ),
            child: const Icon(Icons.fitness_center_rounded, color: kLime, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ΣΗΜΕΡΑ', style: GoogleFonts.manrope(
                  fontSize: 10, fontWeight: FontWeight.w700,
                  color: _kGray6B, letterSpacing: -0.5)),
                Text(dateStr, style: GoogleFonts.manrope(
                  fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 4),
                Row(children: [
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: kLime, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text('ΕΝΕΡΓΟΣ', style: GoogleFonts.manrope(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: kLime, letterSpacing: 1.0)),
                ]),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('ΚΡΑΤΗΣΕΙΣ', style: GoogleFonts.manrope(
                fontSize: 10, fontWeight: FontWeight.w700,
                color: _kGray6B, letterSpacing: -0.5)),
              const SizedBox(height: 4),
              _loadingSchedule
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: kCyan))
                  : Text('$pending', style: GoogleFonts.spaceGrotesk(
                      fontSize: 28, fontWeight: FontWeight.w800, color: kCyan)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsSection() {
    final actions = [
      _QuickAction(Icons.calendar_today_outlined, 'ΠΡΟΓΡΑΜΜΑ', null, () => setState(() => _tab = 1)),
      _QuickAction(Icons.send_outlined, 'ΜΗΝΥΜΑΤΑ', kCyan, () => setState(() => _tab = 2)),
      _QuickAction(Icons.flight_takeoff_outlined, 'ΑΔΕΙΑ', null, () => setState(() => _tab = 3)),
      _QuickAction(Icons.people_outline_rounded, 'ΠΕΛΑΤΕΣ', null, () => setState(() => _tab = 4)),
      _QuickAction(Icons.person_outline_rounded, 'ΠΡΟΦΙΛ', null, () => setState(() => _tab = 5)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ΓΡΗΓΟΡΕΣ ΕΝΕΡΓΕΙΕΣ', style: GoogleFonts.spaceGrotesk(
          fontSize: 14, fontWeight: FontWeight.w700, color: kCyan, letterSpacing: 1.4)),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: actions.map((a) => Expanded(
            child: GestureDetector(
              onTap: a.onTap,
              child: Column(children: [
                Stack(clipBehavior: Clip.none, children: [
                  Container(
                    height: 54,
                    decoration: BoxDecoration(
                      color: _kDark16,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _kBorder26),
                    ),
                    child: Center(child: Icon(a.icon, color: Colors.white, size: 18)),
                  ),
                  if (a.badge != null)
                    Positioned(
                      top: 8, right: 8,
                      child: Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(color: a.badge, shape: BoxShape.circle),
                      ),
                    ),
                ]),
                const SizedBox(height: 8),
                Text(a.label, style: GoogleFonts.manrope(
                  fontSize: 8, fontWeight: FontWeight.w700,
                  color: _kGray9C, letterSpacing: -0.2),
                  textAlign: TextAlign.center),
              ]),
            ),
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildScheduleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("ΠΡΟΓΡΑΜΜΑ ΣΗΜΕΡΑ", style: GoogleFonts.spaceGrotesk(
              fontSize: 14, fontWeight: FontWeight.w700, color: kCyan, letterSpacing: 1.4)),
            Text(
              DateFormat('EEE, d MMM', 'el_GR').format(DateTime.now()).toUpperCase(),
              style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w700,
                color: _kGray6B, letterSpacing: 1.0)),
          ],
        ),
        const SizedBox(height: 16),
        if (_loadingSchedule)
          const Center(child: Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(color: kLime, strokeWidth: 2),
          ))
        else if (_todayBookings.isEmpty)
          _buildEmptySchedule()
        else
          ..._buildBookingTimeline(),
      ],
    );
  }

  Widget _buildEmptySchedule() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _kDark16,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder26),
      ),
      child: Center(
        child: Column(children: [
          Icon(Icons.event_available_outlined, color: _kGray6B, size: 32),
          const SizedBox(height: 8),
          Text('Δεν υπάρχουν κρατήσεις σήμερα',
            style: GoogleFonts.manrope(fontSize: 13, color: _kGray6B)),
        ]),
      ),
    );
  }

  List<Widget> _buildBookingTimeline() {
    final now = DateTime.now();
    final items = <Widget>[];
    for (int i = 0; i < _todayBookings.length; i++) {
      final b = _todayBookings[i];
      final startsAt = DateTime.tryParse(b['starts_at'] as String? ?? '');
      final endsAt   = DateTime.tryParse(b['ends_at']   as String? ?? '');
      if (startsAt == null) continue;

      final isActive = startsAt.isBefore(now) && (endsAt?.isAfter(now) ?? false);
      final isDone   = endsAt != null && endsAt.isBefore(now);
      final isLast   = i == _todayBookings.length - 1;
      final time     = DateFormat('HH:mm').format(startsAt);
      final dur      = endsAt != null
          ? '${endsAt.difference(startsAt).inMinutes} ΛΕΠ'
          : b['duration_mins'] != null ? '${b['duration_mins']} ΛΕΠ' : '';
      final client   = b['client_name'] as String? ?? '';
      final service  = b['service_name'] as String? ?? '';
      final isTrial  = (b['is_trial'] as int?) == 1;

      items.add(_buildTimelineItem(
        time: time, sub: dur,
        title: service,
        detail: isTrial ? 'Trial • $client' : client.isNotEmpty ? client : 'Ομαδικό',
        isActive: isActive, isDone: isDone, isLast: isLast,
        isTrial: isTrial,
      ));
    }
    return items;
  }

  Widget _buildTimelineItem({
    required String time, required String sub,
    required String title, required String detail,
    required bool isActive, required bool isDone,
    bool isLast = false, bool isTrial = false,
  }) {
    return Opacity(
      opacity: isDone ? 0.55 : 1.0,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            child: Column(children: [
              Container(
                width: isActive ? 20 : 16, height: isActive ? 20 : 16,
                decoration: BoxDecoration(
                  color: isActive ? kLime : _kBorder26,
                  shape: BoxShape.circle,
                  border: isActive ? Border.all(color: kBg, width: 4) : Border.all(color: kBg, width: 2),
                  boxShadow: isActive ? [BoxShadow(color: kLime.withValues(alpha: 0.50), blurRadius: 10)] : null,
                ),
              ),
              if (!isLast)
                Container(width: 2, height: 80, color: isActive ? kLime.withValues(alpha: 0.30) : _kBorder26),
            ]),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isActive ? _kDark1C : _kDark16,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isActive ? kLime.withValues(alpha: 0.30) : _kBorder26),
                ),
                child: Row(children: [
                  SizedBox(
                    width: 50,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(time, style: GoogleFonts.manrope(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: isActive ? kLime : Colors.white)),
                        Text(sub, style: GoogleFonts.manrope(
                          fontSize: 9, fontWeight: FontWeight.w700,
                          color: isActive ? kLime : _kGray6B, letterSpacing: 0.27)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                            child: Text(title, style: GoogleFonts.manrope(
                              fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                          ),
                          if (isTrial)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: kCyan.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: kCyan.withValues(alpha: 0.4)),
                              ),
                              child: Text('TRIAL', style: GoogleFonts.manrope(
                                fontSize: 8, fontWeight: FontWeight.w800,
                                color: kCyan, letterSpacing: 0.5)),
                            ),
                        ]),
                        Text(detail, style: GoogleFonts.manrope(fontSize: 10, color: _kGray9C)),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── PROFILE TAB ────────────────────────────────────────────────────────────

  Widget _buildProfileTab(user, TenantConfig config) {
    final auth = context.read<AuthService>();
    return Scaffold(
      backgroundColor: kBg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 72, 24, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ΠΡΟΦΙΛ', style: GoogleFonts.spaceGrotesk(
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
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user?.fullName ?? '', style: GoogleFonts.spaceGrotesk(
                      fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(
                      '${user?.staffRole?.isNotEmpty == true ? user!.staffRole : 'Trainer'} · ${config.appName}',
                      style: GoogleFonts.manrope(fontSize: 12, color: _kGray9C),
                    ),
                    if ((user?.email ?? '').isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(user!.email, style: GoogleFonts.manrope(fontSize: 12, color: _kGray6B)),
                    ],
                  ],
                )),
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
                child: Text(user!.bio!.trim(), style: GoogleFonts.manrope(
                  fontSize: 13, color: Colors.white70, height: 1.4)),
              ),
            ],
            const SizedBox(height: 32),
            if (widget.onSwitchGym != null)
              _profileAction(
                icon: Icons.swap_horiz_rounded,
                label: 'Αλλαγή γυμναστηρίου',
                color: kCyan,
                onTap: widget.onSwitchGym!,
              ),
            if (widget.onRemoveGym != null) ...[
              const SizedBox(height: 12),
              _profileAction(
                icon: Icons.remove_circle_outline_rounded,
                label: 'Αφαίρεση ως trainer',
                color: Colors.redAccent,
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: const Color(0xFF161616),
                      title: const Text('Αφαίρεση γυμναστηρίου',
                        style: TextStyle(color: Colors.white)),
                      content: Text(
                        'Θα αφαιρεθείς ως trainer από το ${config.appName}. Η σύνδεσή σου ως ασκούμενος, αν υπάρχει, μένει.',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Άκυρο'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Αφαίρεση', style: TextStyle(color: Colors.redAccent)),
                        ),
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
              label: 'Αποσύνδεση από γυμναστήριο',
              color: Colors.redAccent,
              onTap: () async {
                await auth.logout();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileAction({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
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
          Text(label, style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
          const Spacer(),
          Icon(Icons.chevron_right_rounded, color: _kGray6B, size: 20),
        ]),
      ),
    );
  }

  // ── BOTTOM NAV ─────────────────────────────────────────────────────────────

  Widget _buildBottomNav() {
    final items = [
      (Icons.home_filled, 'ΑΡΧΙΚΗ'),
      (Icons.calendar_today, 'ΠΡΟΓΡΑΜΜΑ'),
      (Icons.send_outlined, 'ΜΗΝΥΜΑΤΑ'),
      (Icons.flight_takeoff_outlined, 'ΑΔΕΙΑ'),
      (Icons.people_outline_rounded, 'ΠΕΛΑΤΕΣ'),
      (Icons.person_outline_rounded, 'ΠΡΟΦΙΛ'),
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(e.value.$1, color: active ? kLime : _kGray6B, size: 20),
                      const SizedBox(height: 4),
                      Text(e.value.$2, style: GoogleFonts.manrope(
                        fontSize: 8, fontWeight: FontWeight.w700,
                        color: active ? kLime : _kGray6B, letterSpacing: 0.9),
                        textAlign: TextAlign.center),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// ── Helper ─────────────────────────────────────────────────────────────────────
class _QuickAction {
  const _QuickAction(this.icon, this.label, this.badge, this.onTap);
  final IconData icon;
  final String label;
  final Color? badge;
  final VoidCallback onTap;
}
