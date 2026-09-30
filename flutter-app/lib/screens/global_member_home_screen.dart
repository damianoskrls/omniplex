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
import '../services/language_service.dart';
import '../services/push_service.dart';
import '../config/tenant_config.dart';
import 'discovery_landing_screen.dart';
import 'gym_entry_splash.dart';
import 'gym_profile_screen.dart';

const _kBg     = Color(0xFF0A0A0A);
const _kCard   = Color(0xFF16171B);
const _kBorder = Color(0xFF2A2B30);
const _kGray   = Color(0xFF9A9CA3);
const _kLime   = Color(0xFFC6FF3D);
const _kCyan   = Color(0xFF3EE6FF);
const _kAccent = Color(0xFF7B3EAD); // brand gradient mid-point for solid uses

const _kBrandGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFF4452D8),
    Color(0xFF5D49C5),
    Color(0xFF7B3EAD),
    Color(0xFFA4308D),
    Color(0xFFC52473),
  ],
);

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
  int _gymListVersion = 0;
  Map<String, dynamic>? _dashboard;
  bool _loading = true;
  bool _enteringGym = false;
  int _unreadNotifications = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
    _loadNotificationCount();
    PushService.instance.onForegroundData = (data) {
      final type = data['type']?.toString() ?? '';
      if (type != 'join_approved' && type != 'join_rejected') return;
      _loadDashboard();
      if (mounted) setState(() => _gymListVersion++);
    };
  }

  @override
  void dispose() {
    PushService.instance.onForegroundData = null;
    super.dispose();
  }

  void _openTab(int t) {
    setState(() {
      _tab = t;
      if (t == 3) _gymListVersion++;
    });
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

  Future<void> _loadNotificationCount() async {
    try {
      final res = await http.get(
        Uri.parse('$_apiBase/global/me/notifications'),
        headers: {'Authorization': 'Bearer ${widget.globalAuth.token}'},
      );
      if (res.statusCode == 200 && mounted) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() => _unreadNotifications = (body['unread_count'] as num?)?.toInt() ?? 0);
      }
    } catch (_) {}
  }

  Future<void> _openNotifications() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => _GlobalNotificationsPage(token: widget.globalAuth.token ?? ''),
      ),
    );
    _loadNotificationCount();
  }

  void _openBooking(Map<String, dynamic> booking) {
    final bizId = booking['business_id']?.toString();
    GlobalGym? gym;
    if (bizId != null) {
      for (final candidate in widget.globalAuth.gyms) {
        if (candidate.businessId == bizId) {
          gym = candidate;
          break;
        }
      }
    }
    showGlobalBookingSheet(
      context,
      booking,
      onOpenGym: gym == null ? null : () => _enterGym(gym!),
    );
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
      await showGymEntrySplash(
        context,
        name: gym.appName,
        slug: gym.slug,
        logoUrl: gym.logoUrl,
      );
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
              child: const Text('OK', style: TextStyle(color: _kAccent)),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _enteringGym = false);
    }
  }

  Color _parseColor(String? hex) {
    if (hex == null) return _kAccent;
    try { return Color(int.parse(hex.replaceFirst('#', '0xFF'))); }
    catch (_) { return _kAccent; }
  }

  @override
  Widget build(BuildContext context) {
    final firstName = widget.globalAuth.user?.fullName.trim().split(' ').first ?? '';
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _OmniHeader(
              letter: firstName.isNotEmpty ? firstName[0].toUpperCase() : '?',
              unread: _unreadNotifications,
              onNotifications: _openNotifications,
              onProfile: () => _openTab(4),
            ),
            Expanded(
              child: IndexedStack(
        index: _tab,
        children: [
          _HomeTab(
            globalAuth: widget.globalAuth,
            dashboard: _dashboard,
            loading: _loading,
            enteringGym: _enteringGym,
            onEnterGym: _enterGym,
            onRefresh: _loadDashboard,
            onTabChange: _openTab,
            onOpenBooking: _openBooking,
            parseColor: _parseColor,
          ),
          _DiscoverTab(globalAuth: widget.globalAuth),
          _ScheduleTab(
            globalAuth: widget.globalAuth,
            gyms: widget.globalAuth.gyms,
            onEnterGym: _enterGym,
            dashboard: _dashboard,
            loading: _loading,
            onRefresh: _loadDashboard,
          ),
          _MyGymsTab(
            listVersion: _gymListVersion,
            globalAuth: widget.globalAuth,
            enteringGym: _enteringGym,
            onEnterGym: _enterGym,
            onAddGym: () => setState(() => _tab = 1),
            onRemoveGym: (gym) async {
              try {
                await widget.globalAuth.removeGym(gym.businessId, role: gym.userType);
                await _loadDashboard();
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Αποτυχία αφαίρεσης: $e'), backgroundColor: Colors.red.shade700),
                );
              }
            },
            parseColor: _parseColor,
          ),
          _ProfileTab(
            globalAuth: widget.globalAuth,
            onLogout: widget.onLogout,
            onNotifications: _openNotifications,
          ),
        ],
              ),
            ),
          ],
        ),
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
                  onTap: () => _openTab(i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SvgPicture.asset(
                        items[i].$2,
                        width: 20, height: 20,
                        colorFilter: ColorFilter.mode(
                          active ? _kAccent : _kGray, BlendMode.srcIn),
                      ),
                      const SizedBox(height: 4),
                      Text(items[i].$1,
                        style: GoogleFonts.manrope(
                          fontSize: 10, fontWeight: FontWeight.w600,
                          color: active ? _kAccent : _kGray)),
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
    required this.onOpenBooking,
    required this.parseColor,
  });

  final GlobalAuthService globalAuth;
  final Map<String, dynamic>? dashboard;
  final bool loading;
  final bool enteringGym;
  final Future<void> Function(GlobalGym) onEnterGym;
  final Future<void> Function() onRefresh;
  final void Function(int) onTabChange;
  final void Function(Map<String, dynamic>) onOpenBooking;
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
    // Prefer member gym for the home card; fall back to staff gym if no member gyms
    final memberGyms = gyms.where((g) => !g.isStaff).toList();
    final primaryGym = memberGyms.isNotEmpty ? memberGyms.first : gyms.isNotEmpty ? gyms.first : null;
    final upcoming = (dashboard?['upcoming_bookings'] as List?)
        ?.cast<Map<String, dynamic>>() ?? [];
    final nextBooking = upcoming.isNotEmpty ? upcoming.first : null;

    return Stack(
      children: [
        RefreshIndicator(
          color: _kAccent,
          onRefresh: onRefresh,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),

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
                          onBookingTap: nextBooking == null ? null : () => onOpenBooking(nextBooking),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Next Class
                      if (nextBooking != null) ...[
                        _NextClassCard(
                          booking: nextBooking,
                          parseColor: parseColor,
                          onTap: () => onOpenBooking(nextBooking),
                        ),
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
                            iconColor: _kAccent,
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
                        _ThisWeekSection(
                          bookings: upcoming,
                          onOpenBooking: onOpenBooking,
                          onSeeAll: () => onTabChange(2),
                        ),
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
            child: Center(child: CircularProgressIndicator(color: _kAccent)),
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
    this.onBookingTap,
  });

  final GlobalGym gym;
  final Map<String, dynamic>? nextBooking;
  final Color accentColor;
  final VoidCallback onOpenGym;
  final VoidCallback? onBookingTap;

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
                    color: _kAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.check_rounded, color: _kAccent, size: 12),
                    const SizedBox(width: 4),
                    Text('Ενεργό',
                      style: GoogleFonts.manrope(
                        fontSize: 11, fontWeight: FontWeight.w700, color: _kAccent)),
                  ]),
                ),
              ],
            ),
          ),

          // Divider
          const Divider(color: _kBorder, height: 1),

          // Next booking
          if (nextStr != null)
            GestureDetector(
              onTap: onBookingTap,
              child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Row(children: [
                const Icon(Icons.calendar_today_outlined, size: 14, color: _kAccent),
                const SizedBox(width: 6),
                Text('Επόμενη: $nextStr',
                  style: GoogleFonts.manrope(fontSize: 12, color: Colors.white)),
              ]),
            ),
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
                  color: _kAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kAccent.withValues(alpha: 0.3)),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.qr_code_2_rounded, color: _kAccent, size: 20),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _NextClassCard extends StatelessWidget {
  const _NextClassCard({required this.booking, required this.parseColor, required this.onTap});
  final Map<String, dynamic> booking;
  final Color Function(String?) parseColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final time    = (booking['booking_time'] as String? ?? '').substring(0, 5);
    final service = booking['service_name'] as String? ?? '';
    final gymName = booking['app_name'] as String? ?? booking['business_name'] as String? ?? '';
    final coach   = booking['staff_name'] as String?;

    return GestureDetector(
      onTap: onTap,
      child: Container(
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
              gradient: _kBrandGradient,
              borderRadius: BorderRadius.circular(9999),
            ),
            alignment: Alignment.center,
            child: Text('Δες κράτηση', style: GoogleFonts.manrope(
              fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ]),
      ]),
    ),
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
  const _ThisWeekSection({
    required this.bookings,
    required this.onOpenBooking,
    required this.onSeeAll,
  });
  final List<Map<String, dynamic>> bookings;
  final void Function(Map<String, dynamic>) onOpenBooking;
  final VoidCallback onSeeAll;

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
                return GestureDetector(
                  onTap: () => onOpenBooking(b),
                  child: Container(
                  decoration: BoxDecoration(
                    border: i < 2
                      ? const Border(bottom: BorderSide(color: Color(0xFF26272C)))
                      : null,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(children: [
                    Container(
                      width: 6, height: 6,
                      decoration: const BoxDecoration(color: _kAccent, shape: BoxShape.circle)),
                    const SizedBox(width: 10),
                    Text(time, style: GoogleFonts.manrope(
                      fontSize: 13, fontWeight: FontWeight.w700, color: _kAccent)),
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
                ),
                );
              }),
              GestureDetector(
                onTap: onSeeAll,
                child: Container(
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
                color: today ? _kAccent : Colors.transparent,
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
      hideHeader: true,
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
    required this.onRefresh,
  });

  final GlobalAuthService globalAuth;
  final List<GlobalGym> gyms;
  final Future<void> Function(GlobalGym) onEnterGym;
  final Map<String, dynamic>? dashboard;
  final bool loading;
  final Future<void> Function() onRefresh;

  @override
  State<_ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends State<_ScheduleTab> {
  DateTime _selected = DateTime.now();
  int _weekOffset = 0;

  @override
  void initState() {
    super.initState();
    if (widget.dashboard != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _autoSelectFirstBooking();
      });
    }
  }

  @override
  void didUpdateWidget(_ScheduleTab old) {
    super.didUpdateWidget(old);
    if (old.dashboard != widget.dashboard && widget.dashboard != null) {
      _autoSelectFirstBooking();
    }
  }

  void _autoSelectFirstBooking() {
    final all = (widget.dashboard?['upcoming_bookings'] as List?)
        ?.cast<Map<String, dynamic>>() ?? [];
    if (all.isEmpty) return;
    final todayKey = _dateKey(DateTime.now());
    final todayHasBooking = all.any((b) => (b['booking_date'] as String? ?? '') == todayKey);
    if (!todayHasBooking) {
      final firstDate = DateTime.tryParse(all.first['booking_date'] as String? ?? '');
      if (firstDate != null) {
        final now = DateTime.now();
        final monday = now.subtract(Duration(days: now.weekday - 1));
        final daysFromMonday = firstDate.difference(monday).inDays;
        final weekOffset = daysFromMonday ~/ 7;
        if (mounted) setState(() { _selected = firstDate; _weekOffset = weekOffset; });
      }
    }
  }

  List<Map<String, dynamic>> get _all =>
      (widget.dashboard?['upcoming_bookings'] as List?)
          ?.cast<Map<String, dynamic>>() ?? [];

  Set<String> get _bookedDates =>
      _all.map((b) => (b['booking_date'] as String? ?? '')).toSet();

  List<Map<String, dynamic>> get _forDay {
    final ds = '${_selected.year.toString().padLeft(4, '0')}-'
        '${_selected.month.toString().padLeft(2, '0')}-'
        '${_selected.day.toString().padLeft(2, '0')}';
    final list = _all.where((b) => b['booking_date'] == ds).map((b) {
      // Look up display name from the known gyms list (has correct app_name)
      final bizId = b['business_id']?.toString();
      GlobalGym? matched;
      if (bizId != null) {
        try { matched = widget.gyms.firstWhere((g) => g.businessId == bizId); }
        catch (_) {}
      }
      if (matched != null) return {...b, 'app_name': matched.appName};
      return b;
    }).toList();
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
                      icon: Icons.calendar_month_outlined,
                      onTap: _syncGoogleCalendar,
                    ),
                    const SizedBox(width: 8),
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
                        gradient: isSelected ? _kBrandGradient : null,
                        color: isSelected
                            ? null
                            : isToday
                                ? _kCard
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                        border: isToday && !isSelected
                            ? Border.all(color: _kAccent.withValues(alpha: 0.5))
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
                                      ? Colors.white.withValues(alpha: 0.6)
                                      : _kAccent)
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
                        ? _kAccent.withValues(alpha: 0.15)
                        : _kCard,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    bookings.isEmpty ? 'Χωρίς κρατήσεις' : '${bookings.length} κρατήσεις',
                    style: GoogleFonts.manrope(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: bookings.isNotEmpty ? _kAccent : _kGray),
                  ),
                ),
              ]),
            ),

            // Content
            Expanded(
              child: widget.loading
                ? const Center(child: CircularProgressIndicator(color: _kAccent))
                : RefreshIndicator(
                    color: _kAccent,
                    backgroundColor: _kCard,
                    onRefresh: widget.onRefresh,
                    child: bookings.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [_NoBookingsDay()],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                          itemCount: bookings.length,
                          itemBuilder: (_, i) => _ScheduleBookingCard(
                            booking: bookings[i],
                            onTap: () => _showBookingDetail(context, bookings[i]),
                          ),
                        ),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _syncGoogleCalendar() async {
    final bookings = _all.where((b) {
      final status = (b['status'] as String?) ?? 'confirmed';
      return status != 'cancelled';
    }).toList();
    if (bookings.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Δεν υπάρχουν ραντεβού για συγχρονισμό')),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCard,
        title: const Text('Google Calendar', style: TextStyle(color: Colors.white)),
        content: Text(
          'Να ετοιμαστούν ${bookings.length} ραντεβού για το Google Calendar σου; Θα ανοίξει η κοινοποίηση για να τα προσθέσεις.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Άκυρο', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Συγχρονισμός', style: TextStyle(color: _kLime)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final ics = _bookingsToIcs(bookings);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/omniplex-programma.ics');
      await file.writeAsString(ics);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/calendar', name: 'omniplex-programma.ics')],
        subject: 'Πρόγραμμα OmniPlex',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Αποτυχία συγχρονισμού: $e')),
      );
    }
  }

  void _showBookingDetail(BuildContext context, Map<String, dynamic> booking) {
    final bizId = booking['business_id']?.toString();
    GlobalGym? gym;
    if (bizId != null) {
      for (final candidate in widget.gyms) {
        if (candidate.businessId == bizId) {
          gym = candidate;
          break;
        }
      }
    }
    showGlobalBookingSheet(
      context,
      booking,
      onOpenGym: gym == null ? null : () => widget.onEnterGym(gym!),
    );
  }
}

void showGlobalBookingSheet(
  BuildContext context,
  Map<String, dynamic> booking, {
  VoidCallback? onOpenGym,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: _kCard,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _BookingDetailSheet(booking: booking, onOpenGym: onOpenGym),
  );
}

String _bookingsToIcs(List<Map<String, dynamic>> bookings) {
  final stamp = _icsUtc(DateTime.now().toUtc());
  final buf = StringBuffer()
    ..writeln('BEGIN:VCALENDAR')
    ..writeln('VERSION:2.0')
    ..writeln('PRODID:-//OmniPlex//Schedule//EL')
    ..writeln('CALSCALE:GREGORIAN')
    ..writeln('METHOD:PUBLISH');
  for (final b in bookings) {
    final start = _parseBookingStart(b);
    if (start == null) continue;
    final mins = (b['duration_mins'] as num?)?.toInt() ?? 60;
    final end = start.add(Duration(minutes: mins < 1 ? 60 : mins));
    final service = (b['service_name'] as String?)?.trim();
    final gym = ((b['app_name'] as String?) ?? (b['business_name'] as String?) ?? '').trim();
    final isTrainer = b['role'] == 'staff';
    final who = ((isTrainer ? b['client_name'] : b['staff_name']) as String?)?.trim();
    final title = [
      if (service != null && service.isNotEmpty) service else 'Ραντεβού',
      if (gym.isNotEmpty) gym,
    ].join(' — ');
    final details = [
      if (who != null && who.isNotEmpty) (isTrainer ? 'Πελάτης: $who' : 'Trainer: $who'),
      if (gym.isNotEmpty) gym,
    ].join('\n');
    final uid = (b['id'] ?? '${b['booking_date']}_${b['booking_time']}').toString();
    buf
      ..writeln('BEGIN:VEVENT')
      ..writeln('UID:${_icsEscape(uid)}@omniplex')
      ..writeln('DTSTAMP:$stamp')
      ..writeln('DTSTART:${_icsLocal(start)}')
      ..writeln('DTEND:${_icsLocal(end)}')
      ..writeln('SUMMARY:${_icsEscape(title)}')
      ..writeln('DESCRIPTION:${_icsEscape(details)}')
      ..writeln('END:VEVENT');
  }
  buf.writeln('END:VCALENDAR');
  return buf.toString().replaceAll('\n', '\r\n');
}

DateTime? _parseBookingStart(Map<String, dynamic> booking) {
  final date = (booking['booking_date'] as String?) ?? '';
  final parts = date.split('-');
  if (parts.length != 3) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;
  final time = (booking['booking_time'] as String?) ?? '00:00:00';
  final tp = time.split(':');
  final hour = int.tryParse(tp.isNotEmpty ? tp[0] : '') ?? 0;
  final minute = int.tryParse(tp.length > 1 ? tp[1] : '') ?? 0;
  return DateTime(year, month, day, hour, minute);
}

String _icsLocal(DateTime dt) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${dt.year}${two(dt.month)}${two(dt.day)}T${two(dt.hour)}${two(dt.minute)}${two(dt.second)}';
}

String _icsUtc(DateTime dt) => '${_icsLocal(dt)}Z';

String _icsEscape(String value) => value
    .replaceAll('\\', '\\\\')
    .replaceAll('\r\n', '\\n')
    .replaceAll('\n', '\\n')
    .replaceAll(',', '\\,')
    .replaceAll(';', '\\;');

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
    final rawTime  = booking['booking_time'] as String? ?? '';
    final time     = rawTime.length >= 5 ? rawTime.substring(0, 5) : rawTime;
    final service  = booking['service_name'] as String? ?? '';
    final gym      = booking['app_name'] as String? ?? booking['business_name'] as String? ?? '';
    final isTrainer = booking['role'] == 'staff';
    final who      = isTrainer
        ? (booking['client_name'] as String?)
        : (booking['staff_name'] as String?);
    final status   = booking['status'] as String? ?? 'confirmed';
    final imgUrl   = booking['service_image_url'] as String?;
    final isCancel = status == 'cancelled';

    return GestureDetector(
      onTap: onTap,
      child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isCancel ? _kBorder : _kAccent.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        // Service image or time column
        if (imgUrl != null && imgUrl.isNotEmpty)
          Container(
            width: 52, height: 52,
            margin: const EdgeInsets.only(right: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: _kAccent.withValues(alpha: 0.12),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.network(imgUrl, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(Icons.fitness_center_rounded, color: _kAccent, size: 22)),
          )
        else ...[
          SizedBox(
            width: 52,
            child: Text(time,
              style: GoogleFonts.manrope(
                fontSize: 20, fontWeight: FontWeight.w700,
                color: isCancel ? _kGray : _kAccent)),
          ),
          Container(width: 1, height: 42, color: _kBorder, margin: const EdgeInsets.symmetric(horizontal: 14)),
        ],
        // Details
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (imgUrl != null && imgUrl.isNotEmpty)
            Text(time,
              style: GoogleFonts.manrope(
                fontSize: 11, fontWeight: FontWeight.w600,
                color: isCancel ? _kGray : _kAccent)),
          Text(service,
            style: GoogleFonts.manrope(
              fontSize: 14, fontWeight: FontWeight.w700,
              color: isCancel ? _kGray : Colors.white)),
          const SizedBox(height: 3),
          Text(isTrainer ? 'Ως trainer' : 'Ως ασκούμενος',
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isTrainer ? const Color(0xFF3EE6FF) : _kAccent)),
          const SizedBox(height: 2),
          Row(children: [
            const Icon(Icons.fitness_center_rounded, size: 11, color: _kGray),
            const SizedBox(width: 4),
            Flexible(child: Text(gym, overflow: TextOverflow.ellipsis,
              style: GoogleFonts.manrope(fontSize: 11, color: _kGray))),
            if (who != null && who.isNotEmpty) ...[
              Text(' · ', style: GoogleFonts.manrope(fontSize: 11, color: _kGray)),
              Flexible(child: Text(isTrainer ? 'Πελάτης: $who' : who, overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(fontSize: 11, color: _kGray))),
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
  const _BookingDetailSheet({required this.booking, this.onOpenGym});
  final Map<String, dynamic> booking;
  final VoidCallback? onOpenGym;

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
            style: GoogleFonts.manrope(fontSize: 14, color: _kAccent, fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),
          _DetailRow(Icons.calendar_today_outlined, _fmt(date, time)),
          if (duration != null) _DetailRow(Icons.timer_outlined, '$duration λεπτά'),
          if (staff != null) _DetailRow(Icons.person_outline_rounded, staff),
          _DetailRow(
            status == 'confirmed' ? Icons.check_circle_outline : Icons.schedule_outlined,
            status == 'confirmed' ? 'Επιβεβαιωμένη' : 'Σε αναμονή',
          ),
          if (onOpenGym != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  onOpenGym!();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Άνοιξε το γυμναστήριο', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
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
    required this.listVersion,
    required this.globalAuth,
    required this.enteringGym,
    required this.onEnterGym,
    required this.onAddGym,
    required this.onRemoveGym,
    required this.parseColor,
  });

  final int listVersion;
  final GlobalAuthService globalAuth;
  final bool enteringGym;
  final Future<void> Function(GlobalGym) onEnterGym;
  final VoidCallback onAddGym;
  final Future<void> Function(GlobalGym) onRemoveGym;
  final Color Function(String?) parseColor;

  @override
  State<_MyGymsTab> createState() => _MyGymsTabState();
}

class _MyGymsTabState extends State<_MyGymsTab> {
  static const _apiBase = 'https://passionate-grace-production-98ad.up.railway.app/api';

  List<Map<String, dynamic>> _pendingRequests = [];

  @override
  void initState() {
    super.initState();
    _loadPendingRequests();
  }

  @override
  void didUpdateWidget(covariant _MyGymsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.listVersion != oldWidget.listVersion) {
      widget.globalAuth.refreshGyms();
      _loadPendingRequests();
    }
  }

  Future<void> _loadPendingRequests() async {
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
    final trainerGyms = gyms.where((g) => g.isStaff).toList();
    final memberGyms  = gyms.where((g) => !g.isStaff).toList();
    final staffPending = _pendingRequests.where((r) => r['role'] == 'staff').toList();
    final memberPending = _pendingRequests.where((r) => r['role'] != 'staff').toList();
    final totalCount  = gyms.length + _pendingRequests.length;

    Widget _sectionLabel(String label) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(label,
        style: GoogleFonts.manrope(
          fontSize: 12, fontWeight: FontWeight.w700,
          color: _kGray, letterSpacing: 0.5)),
    );

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Stack(
          children: [
            RefreshIndicator(
              color: _kAccent,
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
                            color: _kAccent.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _kAccent.withValues(alpha: 0.3)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.add_rounded, color: _kAccent, size: 16),
                            const SizedBox(width: 4),
                            Text('Προσθήκη', style: GoogleFonts.manrope(
                              fontSize: 12, fontWeight: FontWeight.w700, color: _kAccent)),
                          ]),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  if (trainerGyms.isNotEmpty || staffPending.isNotEmpty) ...[
                    _sectionLabel('Ως Trainer · ${trainerGyms.length + staffPending.length}'),
                    ...trainerGyms.map((gym) => _MyGymCard(
                      gym: gym,
                      accentColor: widget.parseColor(gym.primaryColor),
                      onOpen: () => widget.onEnterGym(gym),
                      onRemove: () => widget.onRemoveGym(gym),
                    )),
                    ...staffPending.map((req) => _PendingRequestCard(
                      request: req,
                      onCancel: () => _cancelRequest(req['id'] as String),
                    )),
                    const SizedBox(height: 8),
                  ],

                  if (memberGyms.isNotEmpty || memberPending.isNotEmpty) ...[
                    _sectionLabel('Ως Ασκούμενος · ${memberGyms.length + memberPending.length}'),
                    ...memberGyms.map((gym) => _MyGymCard(
                      gym: gym,
                      accentColor: widget.parseColor(gym.primaryColor),
                      onOpen: () => widget.onEnterGym(gym),
                      onRemove: () => widget.onRemoveGym(gym),
                    )),
                    ...memberPending.map((req) => _PendingRequestCard(
                      request: req,
                      onCancel: () => _cancelRequest(req['id'] as String),
                    )),
                    const SizedBox(height: 8),
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
                child: Center(child: CircularProgressIndicator(color: _kAccent)),
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
            Text(request['app_name'] as String? ?? request['business_name'] as String? ?? 'Γυμναστήριο',
              style: GoogleFonts.manrope(
                fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 2),
            Text(
              [
                request['role'] == 'staff'
                    ? 'Ως ${request['specialty'] ?? 'προσωπικό'}'
                    : 'Ως ασκούμενος',
                if ((request['location_name'] as String?)?.isNotEmpty == true) request['location_name'],
                'εκκρεμεί έγκριση',
              ].join(' · '),
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
    required this.onRemove,
  });

  final GlobalGym gym;
  final Color accentColor;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  String get _statusLabel {
    if (gym.staffKind == 'nutritionist') return 'Διατροφολόγος';
    if (gym.staffKind == 'physiotherapist') return 'Φυσιοθεραπευτής';
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
      case 'active': return _kAccent;
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
                    const Icon(Icons.check_rounded, size: 11, color: _kAccent),
                  if (!gym.isStaff && isPending)
                    const Icon(Icons.hourglass_empty_rounded, size: 11, color: Color(0xFFF59E0B)),
                  const SizedBox(width: 3),
                  Text(_statusLabel, style: GoogleFonts.manrope(
                    fontSize: 10, fontWeight: FontWeight.w700, color: _statusColor)),
                ]),
              ),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, color: _kGray, size: 18),
                color: const Color(0xFF1C1C2E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: EdgeInsets.zero,
                onSelected: (value) {
                  if (value == 'remove') {
                    showDialog<void>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: const Color(0xFF1C1C2E),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: Text('Αφαίρεση γυμναστηρίου',
                          style: GoogleFonts.manrope(fontWeight: FontWeight.w700, color: Colors.white)),
                        content: Text(
                          gym.isStaff
                            ? 'Θα αφαιρεθείς ως trainer από το "${gym.appName}". Η σύνδεσή σου ως ασκούμενος, αν υπάρχει, μένει.'
                            : 'Θα αφαιρεθείς ως ασκούμενος από το "${gym.appName}". Η σύνδεσή σου ως trainer, αν υπάρχει, μένει.',
                          style: GoogleFonts.manrope(color: _kGray, fontSize: 14)),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text('Άκυρο', style: GoogleFonts.manrope(color: _kGray)),
                          ),
                          TextButton(
                            onPressed: () { Navigator.pop(ctx); onRemove(); },
                            child: Text('Αφαίρεση',
                              style: GoogleFonts.manrope(color: Colors.redAccent, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    );
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'remove',
                    child: Row(children: [
                      const Icon(Icons.remove_circle_outline_rounded, color: Colors.redAccent, size: 16),
                      const SizedBox(width: 8),
                      Text('Αφαίρεση', style: GoogleFonts.manrope(color: Colors.redAccent, fontSize: 13)),
                    ]),
                  ),
                ],
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
                    color: _kAccent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _kAccent.withValues(alpha: 0.3)),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.qr_code_2_rounded, color: _kAccent, size: 18),
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
  const _ProfileTab({
    required this.globalAuth,
    required this.onLogout,
    required this.onNotifications,
  });
  final GlobalAuthService globalAuth;
  final VoidCallback onLogout;
  final VoidCallback onNotifications;

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
            _SettingRow(icon: Icons.notifications_outlined, label: 'Ειδοποιήσεις', onTap: onNotifications),
            ListenableBuilder(
              listenable: LanguageService.instance,
              builder: (context, _) => _SettingRow(
                icon: Icons.language_outlined,
                label: LanguageService.instance.isGreek ? 'Γλώσσα · Ελληνικά' : 'Language · English',
                onTap: () => LanguageService.instance.toggle(),
              ),
            ),
            _SettingRow(
              icon: Icons.lock_outline_rounded,
              label: 'Ασφάλεια & Απόρρητο',
              onTap: () {
                showDialog<void>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: _kCard,
                    title: const Text('Λογαριασμός', style: TextStyle(color: Colors.white)),
                    content: Text(
                      user?.email.isNotEmpty == true
                          ? 'Συνδεδεμένος ως ${user!.email}.'
                          : 'Δεν υπάρχει email σε αυτόν τον λογαριασμό.',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
                    ],
                  ),
                );
              },
            ),
            _SettingRow(
              icon: Icons.help_outline_rounded,
              label: 'Βοήθεια & Υποστήριξη',
              onTap: () {
                launchUrl(Uri.parse('mailto:support@omniplex.app?subject=OmniPlex'));
              },
            ),
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
  const _SettingRow({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
    ),
    );
  }
}

class _OmniHeader extends StatelessWidget {
  const _OmniHeader({
    required this.letter,
    required this.unread,
    required this.onNotifications,
    required this.onProfile,
  });

  final String letter;
  final int unread;
  final VoidCallback onNotifications;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SvgPicture.asset('assets/omniplex_logo.svg', height: 32),
          Row(children: [
            GestureDetector(
              onTap: onNotifications,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.notifications_outlined, color: Colors.white, size: 22),
                  if (unread > 0)
                    Positioned(
                      right: -4, top: -4,
                      child: Container(
                        width: 8, height: 8,
                        decoration: const BoxDecoration(color: _kLime, shape: BoxShape.circle),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            GestureDetector(
              onTap: onProfile,
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: _kCard,
                  shape: BoxShape.circle,
                  border: Border.all(color: _kBorder),
                ),
                alignment: Alignment.center,
                child: Text(letter, style: GoogleFonts.manrope(
                  fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _GlobalNotificationsPage extends StatefulWidget {
  const _GlobalNotificationsPage({required this.token});
  final String token;

  @override
  State<_GlobalNotificationsPage> createState() => _GlobalNotificationsPageState();
}

class _GlobalNotificationsPageState extends State<_GlobalNotificationsPage> {
  static const _apiBase = 'https://passionate-grace-production-98ad.up.railway.app/api';
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await http.get(
        Uri.parse('$_apiBase/global/me/notifications'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (res.statusCode == 200 && mounted) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() {
          _items = ((body['notifications'] as List?) ?? []).cast<Map<String, dynamic>>();
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _markRead(Map<String, dynamic> item) async {
    if (item['is_read'] == 1 || item['is_read'] == true) return;
    final id = item['id']?.toString();
    if (id == null) return;
    try {
      await http.patch(
        Uri.parse('$_apiBase/global/me/notifications/$id/read'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (!mounted) return;
      setState(() => item['is_read'] = 1);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        foregroundColor: Colors.white,
        title: Text('Ειδοποιήσεις', style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kAccent))
          : _items.isEmpty
              ? Center(child: Text('Δεν υπάρχουν ειδοποιήσεις',
                  style: GoogleFonts.manrope(color: _kGray)))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  itemCount: _items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final item = _items[i];
                    final unread = item['is_read'] != 1 && item['is_read'] != true;
                    return GestureDetector(
                      onTap: () => _markRead(item),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _kCard,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: unread ? _kAccent.withValues(alpha: 0.45) : _kBorder),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(item['title'] as String? ?? 'Ειδοποίηση',
                            style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                          if ((item['body'] as String?)?.isNotEmpty == true) ...[
                            const SizedBox(height: 4),
                            Text(item['body'] as String, style: GoogleFonts.manrope(fontSize: 13, color: _kGray)),
                          ],
                          if ((item['gym_name'] as String?)?.isNotEmpty == true) ...[
                            const SizedBox(height: 6),
                            Text(item['gym_name'] as String,
                              style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w600, color: _kAccent)),
                          ],
                        ]),
                      ),
                    );
                  },
                ),
    );
  }
}
