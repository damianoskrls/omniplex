import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
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
    debugPrint('[MemberHome._enterGym] businessId=${gym.businessId} slug=${gym.slug} type=${gym.userType}');
    setState(() => _enteringGym = true);
    try {
      final gymToken = gym.isStaff
          ? await widget.globalAuth.getTrainerToken(gym.businessId)
          : await widget.globalAuth.getGymToken(gym.businessId);
      debugPrint('[MemberHome._enterGym] Got gymToken, saving...');
      // Disable biometrics first (setBiometricEnabled clears old token), then save fresh token
      await BiometricAuthService.instance.setBiometricEnabled(gym.businessId, false);
      await BiometricAuthService.instance.saveToken(gym.businessId, gymToken);
      debugPrint('[MemberHome._enterGym] Token saved, loading TenantConfig...');
      final config = await TenantConfig.loadFromApi(
        slug:       gym.slug,
        apiBaseUrl: 'https://passionate-grace-production-98ad.up.railway.app',
      );
      debugPrint('[MemberHome._enterGym] Config loaded: slug=${config.slug} bizId=${config.businessId}');
      if (!mounted) return;
      debugPrint('[MemberHome._enterGym] Calling onEnterGym...');
      widget.onEnterGym(config);
    } catch (e) {
      debugPrint('[MemberHome._enterGym] ERROR: $e');
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: _kCard,
          title: const Text('Σφάλμα', style: TextStyle(color: Colors.white)),
          content: Text(msg, style: const TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK', style: TextStyle(color: _kLime)),
            ),
          ],
        ),
      );
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
            dashboard: _dashboard,
            loading: _loading,
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
                          SvgPicture.asset('assets/omniplex_logo.svg', height: 32),
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
                            onTap: () {
                              final gyms = globalAuth.gyms;
                              if (gyms.isEmpty) {
                                onTabChange(1);
                              } else if (gyms.length == 1) {
                                onEnterGym(gyms.first);
                              } else {
                                showModalBottomSheet<void>(
                                  context: context,
                                  backgroundColor: _kCard,
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                                  ),
                                  builder: (_) => _GymPickerSheet(
                                    gyms: gyms,
                                    onSelect: onEnterGym,
                                    parseColor: parseColor,
                                  ),
                                );
                              }
                            },
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

class _ScheduleTab extends StatefulWidget {
  const _ScheduleTab({
    required this.globalAuth,
    required this.gyms,
    required this.onEnterGym,
    required this.dashboard,
    required this.loading,
  });

  final GlobalAuthService globalAuth;
  final List<GlobalGym> gyms;
  final Future<void> Function(GlobalGym) onEnterGym;
  final Map<String, dynamic>? dashboard;
  final bool loading;

  @override
  State<_ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends State<_ScheduleTab> {
  DateTime _selected = DateTime.now();
  int _weekOffset = 0;

  List<Map<String, dynamic>> get _all =>
      (widget.dashboard?['upcoming_bookings'] as List?)
          ?.cast<Map<String, dynamic>>() ?? [];

  Set<String> get _bookedDates =>
      _all.map((b) => (b['booking_date'] as String? ?? '')).toSet();

  List<Map<String, dynamic>> get _forDay {
    final ds = '${_selected.year.toString().padLeft(4, '0')}-'
        '${_selected.month.toString().padLeft(2, '0')}-'
        '${_selected.day.toString().padLeft(2, '0')}';
    final list = _all.where((b) => b['booking_date'] == ds).toList();
    list.sort((a, b) =>
        (a['booking_time'] as String? ?? '').compareTo(b['booking_time'] as String? ?? ''));
    return list;
  }

  List<DateTime> get _weekDays {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return List.generate(7, (i) => monday.add(Duration(days: i + _weekOffset * 7)));
  }

  String _dayLabel(DateTime d) {
    const n = ['Δευ','Τρί','Τετ','Πέμ','Παρ','Σάβ','Κυρ'];
    return n[d.weekday - 1];
  }

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';

  String _titleForDate(DateTime d) {
    final now = DateTime.now();
    if (d.day == now.day && d.month == now.month && d.year == now.year) return 'Σήμερα';
    final tom = now.add(const Duration(days: 1));
    if (d.day == tom.day && d.month == tom.month && d.year == tom.year) return 'Αύριο';
    const days = ['Δευτέρα','Τρίτη','Τετάρτη','Πέμπτη','Παρασκευή','Σάββατο','Κυριακή'];
    const months = ['Ιαν','Φεβ','Μαρ','Απρ','Μαΐ','Ιουν','Ιουλ','Αυγ','Σεπ','Οκτ','Νοε','Δεκ'];
    return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final days = _weekDays;
    final bookings = _forDay;

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Πρόγραμμα',
                    style: GoogleFonts.manrope(
                      fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
                  Row(children: [
                    _NavBtn(
                      icon: Icons.chevron_left_rounded,
                      onTap: () => setState(() => _weekOffset--),
                    ),
                    const SizedBox(width: 8),
                    _NavBtn(
                      icon: Icons.chevron_right_rounded,
                      onTap: () => setState(() => _weekOffset++),
                    ),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Week strip
            SizedBox(
              height: 76,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                itemCount: days.length,
                itemBuilder: (_, i) {
                  final day = days[i];
                  final isSelected = _dateKey(day) == _dateKey(_selected);
                  final isToday = _dateKey(day) == _dateKey(DateTime.now());
                  final hasBooking = _bookedDates.contains(_dateKey(day));

                  return GestureDetector(
                    onTap: () => setState(() => _selected = day),
                    child: Container(
                      width: 44,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? _kLime
                            : isToday
                                ? _kCard
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                        border: isToday && !isSelected
                            ? Border.all(color: _kLime.withValues(alpha: 0.35))
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_dayLabel(day),
                            style: GoogleFonts.manrope(
                              fontSize: 10, fontWeight: FontWeight.w600,
                              color: isSelected ? _kBg : _kGray)),
                          const SizedBox(height: 4),
                          Text('${day.day}',
                            style: GoogleFonts.manrope(
                              fontSize: 18, fontWeight: FontWeight.w700,
                              color: isSelected ? _kBg : Colors.white)),
                          const SizedBox(height: 3),
                          Container(
                            width: 5, height: 5,
                            decoration: BoxDecoration(
                              color: hasBooking
                                  ? (isSelected
                                      ? _kBg.withValues(alpha: 0.5)
                                      : _kLime)
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            Container(height: 1, color: _kBorder, margin: const EdgeInsets.only(top: 12)),

            // Date label + count
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
              child: Row(children: [
                Text(_titleForDate(_selected),
                  style: GoogleFonts.manrope(
                    fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: bookings.isNotEmpty
                        ? _kLime.withValues(alpha: 0.12)
                        : _kCard,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    bookings.isEmpty ? 'Χωρίς κρατήσεις' : '${bookings.length} κρατήσεις',
                    style: GoogleFonts.manrope(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: bookings.isNotEmpty ? _kLime : _kGray),
                  ),
                ),
              ]),
            ),

            // Content
            Expanded(
              child: widget.loading
                ? const Center(child: CircularProgressIndicator(color: _kLime))
                : bookings.isEmpty
                  ? _NoBookingsDay()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      itemCount: bookings.length,
                      itemBuilder: (_, i) => _ScheduleBookingCard(
                        booking: bookings[i],
                        onTap: () => _showBookingDetail(context, bookings[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBookingDetail(BuildContext context, Map<String, dynamic> booking) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _kCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _BookingDetailSheet(booking: booking),
    );
  }
}

class _NavBtn extends StatelessWidget {
  const _NavBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 34, height: 34,
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
      ),
      child: Icon(icon, color: Colors.white, size: 18),
    ),
  );
}

class _ScheduleBookingCard extends StatelessWidget {
  const _ScheduleBookingCard({required this.booking, this.onTap});
  final Map<String, dynamic> booking;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final time    = (booking['booking_time'] as String? ?? '').substring(0, 5);
    final service = booking['service_name'] as String? ?? '';
    final gym     = booking['app_name'] as String? ?? booking['business_name'] as String? ?? '';
    final staff   = booking['staff_name'] as String?;
    final status  = booking['status'] as String? ?? 'confirmed';
    final isCancel = status == 'cancelled';

    return GestureDetector(
      onTap: onTap,
      child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isCancel ? _kBorder : _kLime.withValues(alpha: 0.18)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        // Time column
        SizedBox(
          width: 52,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(time,
              style: GoogleFonts.manrope(
                fontSize: 20, fontWeight: FontWeight.w700,
                color: isCancel ? _kGray : _kLime)),
          ]),
        ),
        Container(width: 1, height: 42, color: _kBorder, margin: const EdgeInsets.symmetric(horizontal: 14)),
        // Details
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(service,
            style: GoogleFonts.manrope(
              fontSize: 14, fontWeight: FontWeight.w700,
              color: isCancel ? _kGray : Colors.white)),
          const SizedBox(height: 3),
          Row(children: [
            const Icon(Icons.fitness_center_rounded, size: 11, color: _kGray),
            const SizedBox(width: 4),
            Text(gym, style: GoogleFonts.manrope(fontSize: 11, color: _kGray)),
            if (staff != null) ...[
              Text(' · ', style: GoogleFonts.manrope(fontSize: 11, color: _kGray)),
              Text(staff, style: GoogleFonts.manrope(fontSize: 11, color: _kGray)),
            ],
          ]),
        ])),
        if (isCancel)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              color: _kBorder, borderRadius: BorderRadius.circular(8)),
            child: Text('Ακυρώθηκε',
              style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w600, color: _kGray)),
          )
        else if (onTap != null)
          const Icon(Icons.chevron_right_rounded, color: _kGray, size: 18),
      ]),
    ),
    );
  }
}

class _BookingDetailSheet extends StatelessWidget {
  const _BookingDetailSheet({required this.booking});
  final Map<String, dynamic> booking;

  String _fmt(String? date, String? time) {
    if (date == null) return '';
    final parts = date.split('-');
    if (parts.length < 3) return date;
    const months = ['Ιαν','Φεβ','Μαρ','Απρ','Μαΐ','Ιουν','Ιουλ','Αυγ','Σεπ','Οκτ','Νοε','Δεκ'];
    final m = int.tryParse(parts[1]) ?? 1;
    final t = (time ?? '').length >= 5 ? time!.substring(0, 5) : (time ?? '');
    return '${parts[2]} ${months[m - 1]} ${parts[0]}${t.isNotEmpty ? ', $t' : ''}';
  }

  Future<void> _syncGoogle(Map<String, dynamic> b) async {
    final date = (b['booking_date'] as String? ?? '').replaceAll('-', '');
    final time = ((b['booking_time'] as String? ?? '00:00:00')).replaceAll(':', '').substring(0, 6);
    final mins = (b['duration_mins'] as int?) ?? 60;
    final endDt = DateTime.tryParse(
      '${b['booking_date']}T${b['booking_time'] ?? '00:00:00'}');
    String endTime = time;
    if (endDt != null) {
      final e = endDt.add(Duration(minutes: mins));
      endTime = '${e.hour.toString().padLeft(2,'0')}${e.minute.toString().padLeft(2,'0')}00';
    }
    final title = Uri.encodeComponent(
      '${b['service_name'] ?? ''} - ${b['app_name'] ?? b['business_name'] ?? ''}');
    final details = Uri.encodeComponent(b['staff_name'] != null ? 'Εκπαιδευτής: ${b['staff_name']}' : '');
    final start = '${date}T$time';
    final end = '${date}T$endTime';
    final url = 'https://calendar.google.com/calendar/render?action=TEMPLATE&text=$title&dates=$start/$end&details=$details';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _syncIcs(Map<String, dynamic> b) async {
    final date = (b['booking_date'] as String? ?? '').replaceAll('-', '');
    final time = ((b['booking_time'] as String? ?? '00:00:00')).replaceAll(':', '').substring(0, 6);
    final mins = (b['duration_mins'] as int?) ?? 60;
    final endDt = DateTime.tryParse(
      '${b['booking_date']}T${b['booking_time'] ?? '00:00:00'}');
    String endDate = date;
    String endTime = time;
    if (endDt != null) {
      final e = endDt.add(Duration(minutes: mins));
      endDate = '${e.year}${e.month.toString().padLeft(2,'0')}${e.day.toString().padLeft(2,'0')}';
      endTime = '${e.hour.toString().padLeft(2,'0')}${e.minute.toString().padLeft(2,'0')}00';
    }
    final summary = '${b['service_name'] ?? ''} - ${b['app_name'] ?? b['business_name'] ?? ''}';
    final desc = b['staff_name'] != null ? 'Εκπαιδευτής: ${b['staff_name']}' : '';
    final ics = 'BEGIN:VCALENDAR\nVERSION:2.0\nPRODID:-//OmniPlex//EN\nBEGIN:VEVENT\n'
        'DTSTART:${date}T${time}00\nDTEND:${endDate}T${endTime}00\n'
        'SUMMARY:$summary\nDESCRIPTION:$desc\nEND:VEVENT\nEND:VCALENDAR';
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/booking.ics');
    await file.writeAsString(ics);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/calendar')],
      text: summary,
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = booking['service_name'] as String? ?? '';
    final gym = booking['app_name'] as String? ?? booking['business_name'] as String? ?? '';
    final staff = booking['staff_name'] as String?;
    final date = booking['booking_date'] as String?;
    final time = (booking['booking_time'] as String? ?? '').length >= 5
        ? (booking['booking_time'] as String).substring(0, 5)
        : '';
    final duration = booking['duration_mins'] as int?;
    final status = booking['status'] as String? ?? 'confirmed';

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20,
          MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(width: 36, height: 4,
              decoration: BoxDecoration(color: _kBorder, borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 20),
          Text(service,
            style: GoogleFonts.manrope(
              fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 6),
          Text(gym,
            style: GoogleFonts.manrope(fontSize: 14, color: _kLime, fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),
          _DetailRow(Icons.calendar_today_outlined, _fmt(date, time)),
          if (duration != null) _DetailRow(Icons.timer_outlined, '$duration λεπτά'),
          if (staff != null) _DetailRow(Icons.person_outline_rounded, staff),
          _DetailRow(
            status == 'confirmed' ? Icons.check_circle_outline : Icons.schedule_outlined,
            status == 'confirmed' ? 'Επιβεβαιωμένη' : 'Σε αναμονή',
          ),
          const SizedBox(height: 24),
          Text('Sync με ημερολόγιο',
            style: GoogleFonts.manrope(
              fontSize: 13, fontWeight: FontWeight.w700, color: _kGray)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: _CalBtn(
                icon: Icons.calendar_month,
                label: 'Google Calendar',
                onTap: () => _syncGoogle(booking),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _CalBtn(
                icon: Icons.apple,
                label: 'iPhone Calendar',
                onTap: () => _syncIcs(booking),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.icon, this.text);
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(children: [
      Icon(icon, size: 16, color: _kGray),
      const SizedBox(width: 10),
      Text(text, style: GoogleFonts.manrope(fontSize: 14, color: Colors.white)),
    ]),
  );
}

class _CalBtn extends StatelessWidget {
  const _CalBtn({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 16, color: Colors.white),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.manrope(
          fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
      ]),
    ),
  );
}

class _GymPickerSheet extends StatelessWidget {
  const _GymPickerSheet({required this.gyms, required this.onSelect, required this.parseColor});
  final List<GlobalGym> gyms;
  final Future<void> Function(GlobalGym) onSelect;
  final Color Function(String?) parseColor;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(child: Container(width: 36, height: 4,
          decoration: BoxDecoration(color: _kBorder, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),
        Text('Σε ποιο γυμναστήριο;',
          style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
        const SizedBox(height: 14),
        ...gyms.map((gym) => GestureDetector(
          onTap: () {
            Navigator.pop(context);
            onSelect(gym);
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _kBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kBorder),
            ),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: parseColor(gym.primaryColor).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(child: Text(
                  gym.appName.isNotEmpty ? gym.appName[0].toUpperCase() : 'G',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                    color: parseColor(gym.primaryColor)))),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(gym.appName,
                style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white))),
              const Icon(Icons.chevron_right_rounded, color: _kGray, size: 18),
            ]),
          ),
        )),
      ],
    ),
  );
}

class _NoBookingsDay extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 64, height: 64,
        decoration: BoxDecoration(
          color: _kCard, shape: BoxShape.circle,
          border: Border.all(color: _kBorder)),
        child: const Icon(Icons.calendar_today_outlined, color: _kGray, size: 26),
      ),
      const SizedBox(height: 16),
      Text('Καμία κράτηση',
        style: GoogleFonts.manrope(
          fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
      const SizedBox(height: 6),
      Text('Δεν έχεις κρατήσεις αυτή την ημέρα.',
        style: GoogleFonts.manrope(fontSize: 13, color: _kGray)),
    ]),
  );
}

// ─────────────────────────────────────────
// MY GYMS TAB
// ─────────────────────────────────────────

class _MyGymsTab extends StatefulWidget {
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
  State<_MyGymsTab> createState() => _MyGymsTabState();
}

class _MyGymsTabState extends State<_MyGymsTab> {
  static const _apiBase = 'https://passionate-grace-production-98ad.up.railway.app/api';

  List<Map<String, dynamic>> _pendingRequests = [];
  bool _loadingRequests = true;

  @override
  void initState() {
    super.initState();
    _loadPendingRequests();
  }

  Future<void> _loadPendingRequests() async {
    setState(() => _loadingRequests = true);
    try {
      final res = await http.get(
        Uri.parse('$_apiBase/global/join-requests'),
        headers: {'Authorization': 'Bearer ${widget.globalAuth.token}'},
      );
      if (res.statusCode == 200 && mounted) {
        final all = (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
        setState(() => _pendingRequests = all.where((r) => r['status'] == 'pending').toList());
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingRequests = false);
  }

  Future<void> _cancelRequest(String requestId) async {
    final req = _pendingRequests.firstWhere((r) => r['id'] == requestId, orElse: () => {});
    final bizId = req['business_id'] as String?;
    if (bizId == null) return;
    try {
      await http.delete(
        Uri.parse('$_apiBase/global/join-requests/$requestId'),
        headers: {'Authorization': 'Bearer ${widget.globalAuth.token}'},
      );
      if (mounted) setState(() => _pendingRequests.removeWhere((r) => r['id'] == requestId));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Σφάλμα: $e'), backgroundColor: Colors.red.shade700));
    }
  }

  @override
  Widget build(BuildContext context) {
    final gyms = widget.globalAuth.gyms;
    final totalCount = gyms.length + _pendingRequests.length;
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Stack(
          children: [
            RefreshIndicator(
              color: _kLime,
              backgroundColor: _kCard,
              onRefresh: () async {
                await widget.globalAuth.refreshGyms();
                await _loadPendingRequests();
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
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
                        Text('$totalCount γυμναστήρια',
                          style: GoogleFonts.manrope(fontSize: 12, color: _kGray)),
                      ]),
                      GestureDetector(
                        onTap: widget.onAddGym,
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

                  // Active gym cards
                  ...gyms.map((gym) {
                    final color = widget.parseColor(gym.primaryColor);
                    return _MyGymCard(
                      gym: gym,
                      accentColor: color,
                      onOpen: () => widget.onEnterGym(gym),
                    );
                  }),

                  // Pending join requests
                  if (!_loadingRequests && _pendingRequests.isNotEmpty) ...[
                    if (gyms.isNotEmpty) const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('Εκκρεμή αιτήματα',
                        style: GoogleFonts.manrope(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: _kGray, letterSpacing: 0.5)),
                    ),
                    ..._pendingRequests.map((req) => _PendingRequestCard(
                      request: req,
                      onCancel: () => _cancelRequest(req['id'] as String),
                    )),
                  ],

                  // Add gym dashed card
                  GestureDetector(
                    onTap: widget.onAddGym,
                    child: Container(
                      margin: const EdgeInsets.only(top: 8),
                      height: 90,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _kBorder),
                      ),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: _kCard, shape: BoxShape.circle,
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
            ),
            if (widget.enteringGym)
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

class _PendingRequestCard extends StatelessWidget {
  const _PendingRequestCard({required this.request, required this.onCancel});
  final Map<String, dynamic> request;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFA500).withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFFFA500).withValues(alpha: 0.10),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.schedule_rounded, color: Color(0xFFFFA500), size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(request['business_name'] as String? ?? 'Γυμναστήριο',
              style: GoogleFonts.manrope(
                fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 2),
            Text('Εκκρεμεί έγκριση από τον διαχειριστή',
              style: GoogleFonts.manrope(fontSize: 12, color: const Color(0xFFFFA500))),
          ]),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onCancel,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _kBorder,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('Ακύρωση',
              style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600, color: _kGray)),
          ),
        ),
      ]),
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
    if (gym.isStaff) return 'Trainer';
    switch (gym.userStatus) {
      case 'active': return 'Ενεργή Συνδρομή';
      case 'pending': return 'Σε Αναμονή';
      case 'inactive': return 'Ανενεργό';
      default: return gym.userStatus;
    }
  }

  Color get _statusColor {
    if (gym.isStaff) return const Color(0xFF3EE6FF);
    switch (gym.userStatus) {
      case 'active': return _kLime;
      case 'pending': return const Color(0xFFF59E0B);
      default: return _kGray;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPending = !gym.isStaff && gym.userStatus == 'pending';
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
                  if (gym.isStaff)
                    Icon(Icons.sports_rounded, size: 11, color: _statusColor),
                  if (!gym.isStaff && !isPending)
                    const Icon(Icons.check_rounded, size: 11, color: _kLime),
                  if (!gym.isStaff && isPending)
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
