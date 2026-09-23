import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../services/global_auth_service.dart';
import '../services/biometric_auth_service.dart';
import '../config/tenant_config.dart';
import 'discovery_landing_screen.dart';
import 'gym_profile_screen.dart';

const _kBg     = Color(0xFF0A0A0A);
const _kCard   = Color(0xFF16171B);
const _kBorder = Color(0xFF2A2B30);
const _kGray   = Color(0xFF9A9CA3);
const _kLime   = Color(0xFFC6FF3D);
const _kCyan   = Color(0xFF3EE6FF);

class GlobalMemberHomeScreen extends StatefulWidget {
  const GlobalMemberHomeScreen({
    super.key,
    required this.globalAuth,
    required this.onEnterGym,
    required this.onLogout,
  });

  final GlobalAuthService globalAuth;
  final void Function(TenantConfig) onEnterGym;
  final VoidCallback onLogout;

  @override
  State<GlobalMemberHomeScreen> createState() => _GlobalMemberHomeScreenState();
}

class _GlobalMemberHomeScreenState extends State<GlobalMemberHomeScreen> {
  static const _apiBase = 'https://passionate-grace-production-98ad.up.railway.app/api';

  int _tab = 0;
  Map<String, dynamic>? _dashboard;
  bool _loading = true;
  bool _enteringGym = false;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() => _loading = true);
    try {
      await widget.globalAuth.refreshGyms();
      final res = await http.get(
        Uri.parse('$_apiBase/global/me/dashboard'),
        headers: {'Authorization': 'Bearer ${widget.globalAuth.token}'},
      );
      if (res.statusCode == 200 && mounted) {
        setState(() => _dashboard = jsonDecode(res.body) as Map<String, dynamic>);
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _enterGym(GlobalGym gym) async {
    setState(() => _enteringGym = true);
    try {
      final gymToken = await widget.globalAuth.getGymToken(gym.businessId);
      await BiometricAuthService.instance.saveToken(gym.businessId, gymToken);
      final config = await TenantConfig.loadFromApi(
        slug:       gym.slug,
        apiBaseUrl: 'https://passionate-grace-production-98ad.up.railway.app',
      );
      if (!mounted) return;
      widget.onEnterGym(config);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red.shade700));
    } finally {
      if (mounted) setState(() => _enteringGym = false);
    }
  }

  Color _parseColor(String? hex) {
    if (hex == null) return _kLime;
    try { return Color(int.parse(hex.replaceFirst('#', '0xFF'))); }
    catch (_) { return _kLime; }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: IndexedStack(
        index: _tab,
        children: [
          _HomeTab(
            globalAuth: widget.globalAuth,
            dashboard: _dashboard,
            loading: _loading,
            enteringGym: _enteringGym,
            onEnterGym: _enterGym,
            onRefresh: _loadDashboard,
            onTabChange: (t) => setState(() => _tab = t),
            parseColor: _parseColor,
          ),
          _DiscoverTab(globalAuth: widget.globalAuth),
          _ScheduleTab(
            globalAuth: widget.globalAuth,
            gyms: widget.globalAuth.gyms,
            onEnterGym: _enterGym,
          ),
          _MyGymsTab(
            globalAuth: widget.globalAuth,
            enteringGym: _enteringGym,
            onEnterGym: _enterGym,
            onAddGym: () => setState(() => _tab = 1),
            parseColor: _parseColor,
          ),
          _ProfileTab(
            globalAuth: widget.globalAuth,
            onLogout: widget.onLogout,
          ),
        ],
      ),
      bottomNavigationBar: _buildNavBar(),
    );
  }

  Widget _buildNavBar() {
    final items = [
      ('Αρχική',   'assets/icons/discovery_logo_bolt.svg',  false),
      ('Αναζήτηση','assets/icons/discovery_search.svg',     false),
      ('Πρόγραμμα','assets/icons/discovery_clock.svg',      false),
      ('Γυμναστήρια','assets/icons/discovery_crossfit.svg', false),
      ('Προφίλ',   'assets/icons/discovery_more.svg',       false),
    ];
    return Container(
      decoration: const BoxDecoration(
        color: _kCard,
        border: Border(top: BorderSide(color: _kBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: List.generate(items.length, (i) {
              final active = _tab == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _tab = i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SvgPicture.asset(
                        items[i].$2,
                        width: 20, height: 20,
                        colorFilter: ColorFilter.mode(
                          active ? _kLime : _kGray, BlendMode.srcIn),
                      ),
                      const SizedBox(height: 4),
                      Text(items[i].$1,
                        style: GoogleFonts.manrope(
                          fontSize: 10, fontWeight: FontWeight.w600,
                          color: active ? _kLime : _kGray)),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// HOME TAB
// ─────────────────────────────────────────

class _HomeTab extends StatelessWidget {
  const _HomeTab({
    required this.globalAuth,
    required this.dashboard,
    required this.loading,
    required this.enteringGym,
    required this.onEnterGym,
    required this.onRefresh,
    required this.onTabChange,
    required this.parseColor,
  });

  final GlobalAuthService globalAuth;
  final Map<String, dynamic>? dashboard;
  final bool loading;
  final bool enteringGym;
  final Future<void> Function(GlobalGym) onEnterGym;
  final Future<void> Function() onRefresh;
  final void Function(int) onTabChange;
  final Color Function(String?) parseColor;

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Καλημέρα';
    if (h < 18) return 'Καλησπέρα';
    return 'Καλό βράδυ';
  }

  String get _dateStr {
    final now = DateTime.now();
    const days = ['Κυρ','Δευ','Τρί','Τετ','Πέμ','Παρ','Σάβ'];
    const months = ['Ιαν','Φεβ','Μαρ','Απρ','Μαΐ','Ιουν','Ιουλ','Αυγ','Σεπ','Οκτ','Νοε','Δεκ'];
    return '${days[now.weekday % 7]}, ${now.day} ${months[now.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final firstName = globalAuth.user?.fullName.split(' ').first ?? '';
    final gyms = globalAuth.gyms;
    final primaryGym = gyms.isNotEmpty ? gyms.first : null;
    final upcoming = (dashboard?['upcoming_bookings'] as List?)
        ?.cast<Map<String, dynamic>>() ?? [];
    final nextBooking = upcoming.isNotEmpty ? upcoming.first : null;

    return Stack(
      children: [
        RefreshIndicator(
          color: _kLime,
          onRefresh: onRefresh,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 60, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(_dateStr,
                              style: GoogleFonts.manrope(fontSize: 12, color: _kGray)),
                            Text('$_greeting, $firstName 👋',
                              style: GoogleFonts.manrope(
                                fontSize: 24, fontWeight: FontWeight.w700,
                                color: Colors.white, letterSpacing: -0.6)),
                          ]),
                          Row(children: [
                            const Icon(Icons.notifications_outlined, color: Colors.white, size: 22),
                            const SizedBox(width: 14),
                            Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                color: _kCard,
                                shape: BoxShape.circle,
                                border: Border.all(color: _kBorder),
                              ),
                              child: const Icon(Icons.person_outline_rounded, color: _kGray, size: 20),
                            ),
                          ]),
                        ],
                      ),
                      const SizedBox(height: 28),

                      // My Gym card
                      if (primaryGym != null) ...[
                        Text('Το Γυμναστήριό Μου',
                          style: GoogleFonts.manrope(
                            fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                        const SizedBox(height: 12),
                        _GymMemberCard(
                          gym: primaryGym,
                          nextBooking: nextBooking,
                          accentColor: parseColor(primaryGym.primaryColor),
                          onOpenGym: () => onEnterGym(primaryGym),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Next Class
                      if (nextBooking != null) ...[
                        _NextClassCard(booking: nextBooking, parseColor: parseColor),
                        const SizedBox(height: 24),
                      ],

                      // Quick Actions
                      Text('Γρήγορες Ενέργειες',
                        style: GoogleFonts.manrope(
                          fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                      const SizedBox(height: 12),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.4,
                        children: [
                          _QuickAction(
                            icon: Icons.fitness_center_rounded,
                            iconColor: _kLime,
                            iconBg: const Color(0xFF1A2A0A),
                            label: 'Κράτηση\nΜαθήματος',
                            onTap: () => onTabChange(2),
                          ),
                          _QuickAction(
                            icon: Icons.explore_outlined,
                            iconColor: _kCyan,
                            iconBg: const Color(0xFF0A1A2A),
                            label: 'Ανακάλυψε\nΓυμναστήρια',
                            onTap: () => onTabChange(1),
                          ),
                          _QuickAction(
                            icon: Icons.shopping_bag_outlined,
                            iconColor: const Color(0xFFA78BFA),
                            iconBg: const Color(0xFF1A1420),
                            label: 'Αγορά\nΠακέτου',
                            onTap: () {
                              if (primaryGym != null) {
                                Navigator.push(context, MaterialPageRoute(
                                  builder: (_) => GymProfileScreen(
                                    slug: primaryGym.slug,
                                    globalAuth: globalAuth,
                                  ),
                                ));
                              }
                            },
                          ),
                          _QuickAction(
                            icon: Icons.card_membership_outlined,
                            iconColor: const Color(0xFFFBBF24),
                            iconBg: const Color(0xFF261E14),
                            label: 'Τα Γυμναστήριά\nΜου',
                            onTap: () => onTabChange(3),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // This Week
                      if (upcoming.isNotEmpty) ...[
                        _ThisWeekSection(bookings: upcoming),
                        const SizedBox(height: 24),
                      ],

                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (enteringGym)
          const ColoredBox(
            color: Color(0xAA000000),
            child: Center(child: CircularProgressIndicator(color: _kLime)),
          ),
      ],
    );
  }
}

class _GymMemberCard extends StatelessWidget {
  const _GymMemberCard({
    required this.gym,
    required this.nextBooking,
    required this.accentColor,
    required this.onOpenGym,
  });

  final GlobalGym gym;
  final Map<String, dynamic>? nextBooking;
  final Color accentColor;
  final VoidCallback onOpenGym;

  @override
  Widget build(BuildContext context) {
    final nextStr = nextBooking != null
        ? '${(nextBooking!['booking_time'] as String? ?? '').substring(0,5)} · ${nextBooking!['service_name'] ?? ''}'
        : null;

    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gym header row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: gym.logoUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: Image.network(gym.logoUrl!, fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Icon(Icons.fitness_center, color: accentColor, size: 18)))
                    : Icon(Icons.fitness_center, color: accentColor, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(gym.appName,
                        style: GoogleFonts.manrope(
                          fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                      Text(gym.businessType == 'gym' ? 'Γυμναστήριο' : gym.businessType,
                        style: GoogleFonts.manrope(fontSize: 11, color: _kGray)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _kLime.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.check_rounded, color: _kLime, size: 12),
                    const SizedBox(width: 4),
                    Text('Ενεργό',
                      style: GoogleFonts.manrope(
                        fontSize: 11, fontWeight: FontWeight.w700, color: _kLime)),
                  ]),
                ),
              ],
            ),
          ),

          // Divider
          const Divider(color: _kBorder, height: 1),

          // Next booking
          if (nextStr != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Row(children: [
                const Icon(Icons.calendar_today_outlined, size: 14, color: _kLime),
                const SizedBox(width: 6),
                Text('Επόμενη: $nextStr',
                  style: GoogleFonts.manrope(fontSize: 12, color: Colors.white)),
              ]),
            ),

          // Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: onOpenGym,
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _kBorder),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.open_in_new_rounded, size: 14, color: Colors.white),
                      const SizedBox(width: 6),
                      Text('Άνοιξε', style: GoogleFonts.manrope(
                        fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: _kLime.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kLime.withValues(alpha: 0.3)),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.qr_code_2_rounded, color: _kLime, size: 20),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _NextClassCard extends StatelessWidget {
  const _NextClassCard({required this.booking, required this.parseColor});
  final Map<String, dynamic> booking;
  final Color Function(String?) parseColor;

  @override
  Widget build(BuildContext context) {
    final time    = (booking['booking_time'] as String? ?? '').substring(0, 5);
    final service = booking['service_name'] as String? ?? '';
    final gymName = booking['app_name'] as String? ?? booking['business_name'] as String? ?? '';
    final coach   = booking['staff_name'] as String?;

    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBorder),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('ΕΠΟΜΕΝΟ ΜΑΘΗΜΑ',
          style: GoogleFonts.manrope(
            fontSize: 10, fontWeight: FontWeight.w700,
            color: _kCyan, letterSpacing: 1.2)),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(time,
              style: GoogleFonts.manrope(
                fontSize: 40, fontWeight: FontWeight.w700,
                color: Colors.white, letterSpacing: -1)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(service, style: GoogleFonts.manrope(
                  fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                Text(gymName, style: GoogleFonts.manrope(fontSize: 12, color: _kGray)),
              ]),
            ),
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _kCyan.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.local_fire_department_outlined, color: _kCyan, size: 20),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          if (coach != null)
            Row(children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: _kGray.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: const Icon(Icons.person_rounded, color: _kGray, size: 14),
              ),
              const SizedBox(width: 6),
              Text(coach, style: GoogleFonts.manrope(fontSize: 12, color: _kGray)),
            ])
          else
            const SizedBox(),
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: _kLime,
              borderRadius: BorderRadius.circular(9999),
            ),
            alignment: Alignment.center,
            child: Text('Δες κράτηση', style: GoogleFonts.manrope(
              fontSize: 12, fontWeight: FontWeight.w700, color: _kBg)),
          ),
        ]),
      ]),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kBorder),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const Spacer(),
            Text(label, style: GoogleFonts.manrope(
              fontSize: 12, fontWeight: FontWeight.w700,
              color: Colors.white, height: 1.3)),
          ],
        ),
      ),
    );
  }
}

class _ThisWeekSection extends StatelessWidget {
  const _ThisWeekSection({required this.bookings});
  final List<Map<String, dynamic>> bookings;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Αυτή την Εβδομάδα',
          style: GoogleFonts.manrope(
            fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
        const SizedBox(height: 12),
        // Mini week strip
        _WeekStrip(),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kBorder),
          ),
          clipBehavior: Clip.hardEdge,
          child: Column(
            children: [
              ...bookings.take(3).toList().asMap().entries.map((e) {
                final i = e.key;
                final b = e.value;
                final time    = (b['booking_time'] as String? ?? '').substring(0, 5);
                final service = b['service_name'] as String? ?? '';
                final gym     = b['app_name'] as String? ?? '';
                return Container(
                  decoration: BoxDecoration(
                    border: i < 2
                      ? const Border(bottom: BorderSide(color: Color(0xFF26272C)))
                      : null,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(children: [
                    Container(
                      width: 6, height: 6,
                      decoration: const BoxDecoration(color: _kLime, shape: BoxShape.circle)),
                    const SizedBox(width: 10),
                    Text(time, style: GoogleFonts.manrope(
                      fontSize: 13, fontWeight: FontWeight.w700, color: _kLime)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(service, style: GoogleFonts.manrope(
                          fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                        Text(gym, style: GoogleFonts.manrope(fontSize: 11, color: _kGray)),
                      ]),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: _kGray, size: 18),
                  ]),
                );
              }),
              Container(
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFF26272C)))),
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('Δες ολόκληρο το πρόγραμμα', style: GoogleFonts.manrope(
                    fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 14),
                ]),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WeekStrip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    const dayLabels = ['Δ','Τ','Τ','Π','Π','Σ','Κ'];
    return Row(
      children: List.generate(7, (i) {
        final day   = now.subtract(Duration(days: now.weekday - 1 - i));
        final label = dayLabels[(day.weekday - 1) % 7];
        final num   = day.day.toString();
        final today = day.day == now.day && day.month == now.month;
        return Expanded(
          child: Column(children: [
            Text(label, style: GoogleFonts.manrope(fontSize: 10, color: _kGray)),
            const SizedBox(height: 4),
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: today ? _kLime : Colors.transparent,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(num, style: GoogleFonts.manrope(
                fontSize: 13, fontWeight: FontWeight.w700,
                color: today ? _kBg : Colors.white)),
            ),
          ]),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────
// DISCOVER TAB
// ─────────────────────────────────────────

class _DiscoverTab extends StatelessWidget {
  const _DiscoverTab({required this.globalAuth});
  final GlobalAuthService globalAuth;

  @override
  Widget build(BuildContext context) {
    return DiscoveryLandingScreen(
      globalAuth: globalAuth,
      onLoggedIn: () {},
    );
  }
}

// ─────────────────────────────────────────
// SCHEDULE TAB
// ─────────────────────────────────────────

class _ScheduleTab extends StatelessWidget {
  const _ScheduleTab({
    required this.globalAuth,
    required this.gyms,
    required this.onEnterGym,
  });

  final GlobalAuthService globalAuth;
  final List<GlobalGym> gyms;
  final Future<void> Function(GlobalGym) onEnterGym;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.calendar_month_outlined, color: _kGray, size: 56),
            const SizedBox(height: 16),
            Text('Πρόγραμμα Μαθημάτων',
              style: GoogleFonts.manrope(
                fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 8),
            Text('Άνοιξε ένα γυμναστήριο για να δεις το πρόγραμμα.',
              style: GoogleFonts.manrope(fontSize: 13, color: _kGray),
              textAlign: TextAlign.center),
            if (gyms.isNotEmpty) ...[
              const SizedBox(height: 24),
              ...gyms.take(3).map((g) => GestureDetector(
                onTap: () => onEnterGym(g),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 5),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: _kCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _kBorder),
                  ),
                  child: Row(children: [
                    const Icon(Icons.fitness_center_rounded, color: _kGray, size: 18),
                    const SizedBox(width: 10),
                    Text(g.appName, style: GoogleFonts.manrope(
                      fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                    const Spacer(),
                    const Icon(Icons.arrow_forward_ios_rounded, color: _kGray, size: 12),
                  ]),
                ),
              )),
            ],
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// MY GYMS TAB
// ─────────────────────────────────────────

class _MyGymsTab extends StatelessWidget {
  const _MyGymsTab({
    required this.globalAuth,
    required this.enteringGym,
    required this.onEnterGym,
    required this.onAddGym,
    required this.parseColor,
  });

  final GlobalAuthService globalAuth;
  final bool enteringGym;
  final Future<void> Function(GlobalGym) onEnterGym;
  final VoidCallback onAddGym;
  final Color Function(String?) parseColor;

  @override
  Widget build(BuildContext context) {
    final gyms = globalAuth.gyms;
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Τα Γυμναστήριά Μου',
                        style: GoogleFonts.manrope(
                          fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
                      Text('${gyms.length} συνδεδεμένα γυμναστήρια',
                        style: GoogleFonts.manrope(fontSize: 12, color: _kGray)),
                    ]),
                    GestureDetector(
                      onTap: onAddGym,
                      child: Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: _kLime.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _kLime.withValues(alpha: 0.3)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.add_rounded, color: _kLime, size: 16),
                          const SizedBox(width: 4),
                          Text('Προσθήκη', style: GoogleFonts.manrope(
                            fontSize: 12, fontWeight: FontWeight.w700, color: _kLime)),
                        ]),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Gym cards
                ...gyms.map((gym) {
                  final color = parseColor(gym.primaryColor);
                  return _MyGymCard(
                    gym: gym,
                    accentColor: color,
                    onOpen: () => onEnterGym(gym),
                  );
                }),

                // Add gym dashed card
                GestureDetector(
                  onTap: onAddGym,
                  child: Container(
                    margin: const EdgeInsets.only(top: 8),
                    height: 90,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _kBorder, style: BorderStyle.solid),
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: _kCard,
                          shape: BoxShape.circle,
                          border: Border.all(color: _kBorder),
                        ),
                        child: const Icon(Icons.add_rounded, color: Colors.white, size: 16),
                      ),
                      const SizedBox(height: 6),
                      Text('Σύνδεσε νέο γυμναστήριο',
                        style: GoogleFonts.manrope(
                          fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                      Text('Αναζήτηση και εγγραφή σε γυμναστήρια κοντά σου',
                        style: GoogleFonts.manrope(fontSize: 11, color: _kGray)),
                    ]),
                  ),
                ),
              ],
            ),
            if (enteringGym)
              const ColoredBox(
                color: Color(0xAA000000),
                child: Center(child: CircularProgressIndicator(color: _kLime)),
              ),
          ],
        ),
      ),
    );
  }
}

class _MyGymCard extends StatelessWidget {
  const _MyGymCard({
    required this.gym,
    required this.accentColor,
    required this.onOpen,
  });

  final GlobalGym gym;
  final Color accentColor;
  final VoidCallback onOpen;

  String get _statusLabel {
    switch (gym.userStatus) {
      case 'active': return 'Ενεργή Συνδρομή';
      case 'pending': return 'Σε Αναμονή';
      case 'inactive': return 'Ανενεργό';
      default: return gym.userStatus;
    }
  }

  Color get _statusColor {
    switch (gym.userStatus) {
      case 'active': return _kLime;
      case 'pending': return const Color(0xFFF59E0B);
      default: return _kGray;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPending = gym.userStatus == 'pending';
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: gym.logoUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: Image.network(gym.logoUrl!, fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(Icons.fitness_center, color: accentColor)))
                  : Icon(Icons.fitness_center, color: accentColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(gym.appName, style: GoogleFonts.manrope(
                    fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                  Text(gym.businessType, style: GoogleFonts.manrope(fontSize: 11, color: _kGray)),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (!isPending)
                    const Icon(Icons.check_rounded, size: 11, color: _kLime),
                  if (isPending)
                    const Icon(Icons.hourglass_empty_rounded, size: 11, color: Color(0xFFF59E0B)),
                  const SizedBox(width: 3),
                  Text(_statusLabel, style: GoogleFonts.manrope(
                    fontSize: 10, fontWeight: FontWeight.w700, color: _statusColor)),
                ]),
              ),
            ]),
          ),

          // Pending message
          if (isPending) ...[
            const Divider(color: _kBorder, height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Row(children: [
                const Icon(Icons.hourglass_empty_rounded, color: Color(0xFFF59E0B), size: 14),
                const SizedBox(width: 6),
                Text('Αναμονή έγκρισης γυμναστηρίου',
                  style: GoogleFonts.manrope(fontSize: 12, color: const Color(0xFFF59E0B))),
              ]),
            ),
          ],

          // Actions (only when active)
          if (!isPending) ...[
            const Divider(color: _kBorder, height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: onOpen,
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _kBorder),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.open_in_new_rounded, size: 14, color: Colors.white),
                        const SizedBox(width: 6),
                        Text('Άνοιξε το Γυμναστήριο', style: GoogleFonts.manrope(
                          fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: _kLime.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _kLime.withValues(alpha: 0.3)),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.qr_code_2_rounded, color: _kLime, size: 18),
                ),
              ]),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// PROFILE TAB
// ─────────────────────────────────────────

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({required this.globalAuth, required this.onLogout});
  final GlobalAuthService globalAuth;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final user = globalAuth.user;
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
          children: [
            // Avatar
            Center(
              child: Column(children: [
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: _kCard, shape: BoxShape.circle,
                    border: Border.all(color: _kBorder, width: 2)),
                  child: const Icon(Icons.person_rounded, color: _kGray, size: 40),
                ),
                const SizedBox(height: 12),
                Text(user?.fullName ?? '',
                  style: GoogleFonts.manrope(
                    fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                if ((user?.email ?? '').isNotEmpty)
                  Text(user!.email,
                    style: GoogleFonts.manrope(fontSize: 13, color: _kGray)),
              ]),
            ),
            const SizedBox(height: 32),

            // Settings rows
            _SettingRow(icon: Icons.notifications_outlined, label: 'Ειδοποιήσεις'),
            _SettingRow(icon: Icons.language_outlined, label: 'Γλώσσα'),
            _SettingRow(icon: Icons.lock_outline_rounded, label: 'Ασφάλεια & Απόρρητο'),
            _SettingRow(icon: Icons.help_outline_rounded, label: 'Βοήθεια & Υποστήριξη'),
            const SizedBox(height: 16),

            // Logout
            GestureDetector(
              onTap: () async {
                await globalAuth.clear();
                onLogout();
              },
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.red.shade900.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.red.shade900.withValues(alpha: 0.4)),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.logout_rounded, color: Colors.red.shade400, size: 18),
                  const SizedBox(width: 8),
                  Text('Αποσύνδεση', style: GoogleFonts.manrope(
                    fontSize: 14, fontWeight: FontWeight.w700, color: Colors.red.shade400)),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Row(children: [
        Icon(icon, color: _kGray, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label, style: GoogleFonts.manrope(
            fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
        ),
        const Icon(Icons.chevron_right_rounded, color: _kGray, size: 18),
      ]),
    );
  }
}
