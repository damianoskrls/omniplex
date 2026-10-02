import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/global_auth_service.dart';
import '../services/biometric_auth_service.dart';
import '../services/language_service.dart';
import '../services/notification_service.dart';
import '../services/push_service.dart';
import '../services/user_notification_sync.dart';
import '../config/tenant_config.dart';
import 'discovery_landing_screen.dart';
import 'electronic_documents_screen.dart';
import 'gym_entry_splash.dart';
import 'gym_profile_screen.dart';
import 'phone_otp_login_screen.dart';

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
    this.startOnDiscover = false,
  });

  final GlobalAuthService globalAuth;
  final void Function(TenantConfig) onEnterGym;
  final VoidCallback onLogout;
  final bool startOnDiscover;

  @override
  State<GlobalMemberHomeScreen> createState() => _GlobalMemberHomeScreenState();
}

class _GlobalMemberHomeScreenState extends State<GlobalMemberHomeScreen> {
  static const _apiBase = 'https://passionate-grace-production-98ad.up.railway.app/api';

  late int _tab = widget.startOnDiscover ? 1 : 0;
  int _gymListVersion = 0;
  Map<String, dynamic>? _dashboard;
  bool _loading = true;
  bool _enteringGym = false;
  int _unreadNotifications = 0;
  Timer? _notifTimer;

  @override
  void initState() {
    super.initState();
    widget.globalAuth.addListener(_onAuthChanged);
    if (widget.globalAuth.isLoggedIn) {
      _loadDashboard();
      _watchNotifications();
    } else {
      _loading = false;
    }
    PushService.instance.onForegroundData = (data) {
      _loadNotificationCount();
      final type = data['type']?.toString() ?? '';
      if (type != 'join_approved' && type != 'join_rejected') return;
      _loadDashboard();
      if (mounted) setState(() => _gymListVersion++);
    };
  }

  void _onAuthChanged() {
    if (!mounted) return;
    if (widget.globalAuth.isLoggedIn) {
      _loadDashboard();
      if (_notifTimer == null) _watchNotifications();
    }
    setState(() {});
  }

  void _openLogin() {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => PhoneOtpLoginScreen(
        globalAuth: widget.globalAuth,
        onLoggedIn: () {
          Navigator.of(context).popUntil((route) => route.isFirst);
        },
      ),
    ));
  }

  void _onJoinRequestSent() {
    _loadDashboard();
    _openTab(3);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Το αίτημα είναι σε αναμονή στα Gyms σου.')),
    );
  }

  void _onGymAdded() {
    _loadDashboard();
    _openTab(3);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Το γυμναστήριο προστέθηκε στα Gyms σου, με τα στοιχεία που έχει ο διαχειριστής.')),
    );
  }

  Future<void> _onPurchaseComplete({
    required String message,
    required String businessId,
    required String tabKey,
  }) async {
    GlobalGym? gym;
    for (final candidate in widget.globalAuth.gyms) {
      if (candidate.businessId == businessId && !candidate.isStaff) {
        gym = candidate;
        break;
      }
    }
    if (gym == null) {
      await widget.globalAuth.refreshGyms();
      for (final candidate in widget.globalAuth.gyms) {
        if (candidate.businessId == businessId && !candidate.isStaff) {
          gym = candidate;
          break;
        }
      }
    }
    if (!mounted) return;
    if (gym == null) {
      _openTab(3);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    GymLaunch.tabKey = tabKey;
    GymLaunch.message = message;
    unawaited(widget.globalAuth.refreshGyms());
    unawaited(_loadDashboard());
    await _enterGym(gym);
  }

  String? _packageLine(String businessId) {
    final rows = _dashboard?['memberships'];
    if (rows is! List) return null;
    for (final raw in rows) {
      if (raw is! Map || raw['business_id']?.toString() != businessId) continue;
      final name = (raw['plan_name'] ?? 'Πακέτο').toString();
      final total = raw['total_sessions'];
      final used = raw['used_sessions'];
      if (total is num && total > 0 && total < 9000) {
        final left = (total - (used is num ? used : 0)).clamp(0, total).toInt();
        return '$name · $left συνεδρίες';
      }
      return name;
    }
    return null;
  }

  @override
  void dispose() {
    widget.globalAuth.removeListener(_onAuthChanged);
    _notifTimer?.cancel();
    PushService.instance.onForegroundData = null;
    super.dispose();
  }

  Future<void> _watchNotifications() async {
    await _loadNotificationCount(announce: true);
    _notifTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      _loadNotificationCount(announce: true);
    });
  }

  void _openTab(int t) {
    if (!widget.globalAuth.isLoggedIn && (t == 2 || t == 4)) {
      _openLogin();
      return;
    }
    setState(() {
      _tab = t;
      if (t == 3) _gymListVersion++;
    });
  }

  Future<void> _loadDashboard() async {
    if (!widget.globalAuth.isLoggedIn) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    if (_dashboard == null) setState(() => _loading = true);
    try {
      final results = await Future.wait([
        widget.globalAuth.refreshGyms(),
        http.get(
          Uri.parse('$_apiBase/global/me/dashboard'),
          headers: {'Authorization': 'Bearer ${widget.globalAuth.token}'},
        ),
      ]);
      final res = results[1] as http.Response;
      if (res.statusCode == 200 && mounted) {
        setState(() => _dashboard = jsonDecode(res.body) as Map<String, dynamic>);
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadNotificationCount({bool announce = false}) async {
    try {
      final res = await http.get(
        Uri.parse('$_apiBase/global/me/notifications'),
        headers: {'Authorization': 'Bearer ${widget.globalAuth.token}'},
      );
      if (res.statusCode != 200 || !mounted) return;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final items = ((body['notifications'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      setState(() => _unreadNotifications = (body['unread_count'] as num?)?.toInt() ?? 0);
      if (!announce) return;
      await UserNotificationSync.instance.ensureShownIds();
      var popped = 0;
      for (final item in items) {
        final id = item['id']?.toString() ?? '';
        final unread = item['is_read'] != 1 && item['is_read'] != true;
        if (id.isEmpty || !unread || popped >= 3) continue;
        if (!UserNotificationSync.instance.take(id)) continue;
        popped += 1;
        final type = item['type']?.toString() ?? '';
        final payload = type == 'message'
            ? UserNotificationSync.instance.messagePayload(item)
            : 'notif:$id';
        await NotificationService.instance.showInstant(
          title: item['title'] as String? ?? 'Ειδοποίηση',
          body: item['body'] as String? ?? '',
          payload: payload,
        );
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
          ? await widget.globalAuth.getTrainerToken(gym.businessId, asKind: gym.staffKind)
          : await widget.globalAuth.getGymToken(gym.businessId);
      debugPrint('[MemberHome._enterGym] Got gymToken, saving...');
      // Disable biometrics first (setBiometricEnabled clears old token), then save fresh token
      await BiometricAuthService.instance.setBiometricEnabled(gym.businessId, false);
      await BiometricAuthService.instance.saveToken(gym.businessId, gymToken);
      debugPrint('[MemberHome._enterGym] Token saved, loading TenantConfig...');
      final config = await _configForGym(gym);
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

  Future<TenantConfig> _configForGym(GlobalGym gym) {
    const api = 'https://passionate-grace-production-98ad.up.railway.app';
    return TenantConfig.openFast(
      businessId: gym.businessId,
      slug: gym.slug,
      appName: gym.appName,
      apiBaseUrl: api,
      primaryColor: gym.primaryColor,
      logoUrl: gym.logoUrl,
    );
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
              guest: !widget.globalAuth.isLoggedIn,
              onLogin: _openLogin,
              onNotifications: widget.globalAuth.isLoggedIn ? _openNotifications : _openLogin,
              onProfile: widget.globalAuth.isLoggedIn ? () => _openTab(4) : _openLogin,
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
            packageLine: _packageLine,
            onPurchaseComplete: _onPurchaseComplete,
          ),
          _DiscoverTab(
            globalAuth: widget.globalAuth,
            onRequestSent: _onJoinRequestSent,
            onGymAdded: _onGymAdded,
            onPurchaseComplete: _onPurchaseComplete,
          ),
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
            packageLine: _packageLine,
            onPurchaseComplete: _onPurchaseComplete,
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
    final bottom = MediaQuery.paddingOf(context).bottom;
    return ColoredBox(
      color: _kBg,
      child: SizedBox(
        height: 76 + bottom,
        child: Stack(
          children: [
            Positioned(
              left: 0, right: 0, bottom: 0,
              height: 58 + bottom,
              child: ColoredBox(
                color: const Color(0xFF141416),
                child: Padding(
                  padding: EdgeInsets.only(bottom: bottom),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _navItem(0, 'Home', 'assets/icons/nav_omni_home.png'),
                      _navItem(1, 'Αναζήτηση', 'assets/icons/nav_omni_search.png'),
                      const SizedBox(width: 70),
                      _navItem(3, 'Gyms', 'assets/icons/nav_omni_gyms.png'),
                      _navItem(4, 'Προφίλ', 'assets/icons/nav_omni_profile.png'),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 2, left: 0, right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () => _openTab(2),
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: _kBrandGradient,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFC52473).withValues(alpha: 0.38),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: SvgPicture.asset(
                      'assets/icons/nav_calendar.svg',
                      width: 26,
                      height: 26,
                      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navItem(int index, String label, String asset) {
    final active = _tab == index;
    final iconColor = active ? const Color(0xFFC52473) : const Color(0xFF717479);
    return Expanded(
      child: GestureDetector(
        onTap: () => _openTab(index),
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.fromLTRB(10, 5, 10, 4),
            decoration: BoxDecoration(
              color: active ? const Color(0xFF2A2B31) : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ColorFiltered(
                  colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
                  child: Image.asset(
                    asset,
                    width: 22,
                    height: 22,
                    filterQuality: FilterQuality.medium,
                    gaplessPlayback: true,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: active ? Colors.white : const Color(0xFF717479),
                  ),
                ),
              ],
            ),
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
    required this.packageLine,
    required this.onPurchaseComplete,
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
  final String? Function(String businessId) packageLine;
  final PurchaseComplete onPurchaseComplete;

  Map<String, dynamic>? _soonestBooking(List<Map<String, dynamic>> rows) {
    final now = DateTime.now();
    Map<String, dynamic>? next;
    DateTime? nextAt;
    Map<String, dynamic>? latest;
    DateTime? latestAt;
    for (final row in rows) {
      final at = DateTime.tryParse(
        '${row['booking_date'] ?? ''}T${row['booking_time'] ?? '00:00:00'}',
      );
      if (at == null) continue;
      if (!at.isBefore(now) && (nextAt == null || at.isBefore(nextAt))) {
        next = row;
        nextAt = at;
      }
      if (latestAt == null || at.isAfter(latestAt)) {
        latest = row;
        latestAt = at;
      }
    }
    return next ?? latest;
  }

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
    final homeGroups = <List<GlobalGym>>[];
    final seenBiz = <String>{};
    for (final gym in gyms) {
      if (!seenBiz.add(gym.businessId)) continue;
      final roles = _rolesFirst(gyms.where((g) => g.businessId == gym.businessId).toList());
      final active = roles.where((g) => g.isStaff || g.userStatus != 'pending').toList();
      if (active.isNotEmpty) homeGroups.add(active);
    }
    final upcoming = (dashboard?['upcoming_bookings'] as List?)
        ?.whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList() ?? [];
    final nextBooking = _soonestBooking(upcoming);

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
                      if (homeGroups.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            globalAuth.isLoggedIn
                                ? 'Τα γυμναστήρια που περιμένουν έγκριση είναι στα Gyms.'
                                : 'Βρες γυμναστήριο από την Αναζήτηση. Η σύνδεση ζητιέται όταν θες πακέτο.',
                            style: GoogleFonts.manrope(fontSize: 14, color: _kGray, height: 1.4),
                          ),
                        ),

                      if (homeGroups.isNotEmpty) ...[
                        Row(children: [
                          Expanded(
                            child: Text('Τα Γυμναστήριά Μου',
                              style: GoogleFonts.manrope(
                                fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                          ),
                          Text(
                            homeGroups.length == 1 ? '1 ενεργό' : '${homeGroups.length} ενεργά',
                            style: GoogleFonts.manrope(fontSize: 13, color: _kGray, fontWeight: FontWeight.w600),
                          ),
                        ]),
                        const SizedBox(height: 12),
                        _HomeGymCarousel(
                          groups: homeGroups,
                          upcoming: upcoming,
                          globalAuth: globalAuth,
                          parseColor: parseColor,
                          onEnter: onEnterGym,
                          onOpenBooking: onOpenBooking,
                          packageLine: packageLine,
                          onAddRole: (gym) {
                            Navigator.push(context, MaterialPageRoute(
                              builder: (_) => GymProfileScreen(
                                slug: gym.slug,
                                globalAuth: globalAuth,
                                onPurchaseComplete: onPurchaseComplete,
                              ),
                            ));
                          },
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

class _GymLogo extends StatelessWidget {
  const _GymLogo({required this.url, required this.name, required this.accent});

  final String? url;
  final String name;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final onFill = accent.computeLuminance() > 0.62 ? const Color(0xFF111111) : Colors.white;
    final initials = _logoInitials(name);
    if (url == null || url!.isEmpty) {
      return Container(
        width: 56,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: accent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(initials, style: GoogleFonts.manrope(color: onFill, fontWeight: FontWeight.w800, fontSize: 14)),
      );
    }
    return Container(
      width: 88,
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Image.network(
        url!,
        fit: BoxFit.contain,
        width: 76,
        height: 48,
        errorBuilder: (_, _, _) => Text(initials, style: GoogleFonts.manrope(color: const Color(0xFF111111), fontWeight: FontWeight.w800)),
      ),
    );
  }
}

String _logoInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
  if (parts.isEmpty) return 'Γ';
  if (parts.length == 1) {
    final word = parts.first;
    return word.substring(0, word.length >= 2 ? 2 : 1).toUpperCase();
  }
  return (parts[0][0] + parts[1][0]).toUpperCase();
}

class _HomeGymCarousel extends StatefulWidget {
  const _HomeGymCarousel({
    required this.groups,
    required this.upcoming,
    required this.globalAuth,
    required this.parseColor,
    required this.onEnter,
    required this.onOpenBooking,
    required this.packageLine,
    required this.onAddRole,
  });

  final List<List<GlobalGym>> groups;
  final List<Map<String, dynamic>> upcoming;
  final GlobalAuthService globalAuth;
  final Color Function(String?) parseColor;
  final Future<void> Function(GlobalGym) onEnter;
  final void Function(Map<String, dynamic>) onOpenBooking;
  final String? Function(String businessId) packageLine;
  final void Function(GlobalGym) onAddRole;

  @override
  State<_HomeGymCarousel> createState() => _HomeGymCarouselState();
}

class _HomeGymCarouselState extends State<_HomeGymCarousel> {
  late final PageController _page;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _page = PageController(viewportFraction: widget.groups.length > 1 ? 0.92 : 1);
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  double get _height {
    final maxRoles = widget.groups.fold<int>(1, (max, roles) => roles.length > max ? roles.length : max);
    final withPackage = widget.groups.any((roles) => widget.packageLine(roles.first.businessId) != null);
    return 92 + maxRoles * 118 + 72 + (withPackage ? 52 : 0);
  }

  @override
  Widget build(BuildContext context) {
    final many = widget.groups.length > 1;
    return Column(children: [
      SizedBox(
        height: _height,
        child: PageView.builder(
          controller: _page,
          itemCount: widget.groups.length,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (_, i) {
            final roles = widget.groups[i];
            return Padding(
              padding: EdgeInsets.only(right: many ? 10 : 0),
              child: _HomeGymSlide(
                gym: roles.first,
                roles: roles,
                upcoming: widget.upcoming,
                accentColor: widget.parseColor(roles.first.primaryColor),
                globalAuth: widget.globalAuth,
                onEnter: widget.onEnter,
                onOpenBooking: widget.onOpenBooking,
                packageLine: widget.packageLine(roles.first.businessId),
                onAddRole: () => widget.onAddRole(roles.first),
              ),
            );
          },
        ),
      ),
      if (many) ...[
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.groups.length, (i) => Container(
            width: i == _index ? 18 : 6,
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: i == _index ? const Color(0xFF7C5CFC) : _kGray.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(99),
            ),
          )),
        ),
      ],
    ]);
  }
}

class _HomeGymSlide extends StatelessWidget {
  const _HomeGymSlide({
    required this.gym,
    required this.roles,
    required this.upcoming,
    required this.accentColor,
    required this.globalAuth,
    required this.onEnter,
    required this.onOpenBooking,
    required this.packageLine,
    required this.onAddRole,
  });

  final GlobalGym gym;
  final List<GlobalGym> roles;
  final List<Map<String, dynamic>> upcoming;
  final Color accentColor;
  final GlobalAuthService globalAuth;
  final Future<void> Function(GlobalGym) onEnter;
  final void Function(Map<String, dynamic>) onOpenBooking;
  final String? packageLine;
  final VoidCallback onAddRole;

  Map<String, dynamic>? _nextFor(GlobalGym role) {
    final now = DateTime.now().subtract(const Duration(minutes: 20));
    for (final booking in upcoming) {
      if (booking['business_id']?.toString() != role.businessId) continue;
      final kind = booking['role']?.toString();
      if (role.isStaff && kind != 'staff') continue;
      if (!role.isStaff && kind == 'staff') continue;
      final date = booking['booking_date']?.toString() ?? '';
      final time = booking['booking_time']?.toString() ?? '00:00:00';
      final when = DateTime.tryParse('${date}T${time.length >= 8 ? time.substring(0, 8) : time}');
      if (when != null && when.isBefore(now)) continue;
      return booking;
    }
    return null;
  }

  String _roleLabel(GlobalGym role) {
    if (!role.isStaff) return 'Ασκούμενος';
    if (role.staffKind == 'nutritionist') return 'Διατροφολόγος';
    if (role.staffKind == 'physiotherapist') return 'Φυσιοθεραπευτής';
    return 'Προπονητής';
  }

  _RoleTone _tone(GlobalGym role) {
    if (!role.isStaff) {
      return const _RoleTone(
        Color(0xFF2C2450),
        Color(0xFFC4B5FD),
        Color(0xFF6D5BD0),
        Icons.directions_run_rounded,
      );
    }
    if (role.staffKind == 'nutritionist') {
      return const _RoleTone(
        Color(0xFF16301C),
        Color(0xFF86EFAC),
        Color(0xFF3F8F55),
        Icons.apple_rounded,
      );
    }
    if (role.staffKind == 'physiotherapist') {
      return const _RoleTone(
        Color(0xFF142E30),
        Color(0xFF7DD3D0),
        Color(0xFF2F8A88),
        Icons.healing_rounded,
      );
    }
    return const _RoleTone(
      Color(0xFF2A1824),
      Color(0xFFF9A8D4),
      Color(0xFFBE4B8A),
      Icons.person_rounded,
    );
  }

  Future<void> _showQr(BuildContext context) async {
    GlobalGym member = gym;
    for (final role in roles) {
      if (!role.isStaff) {
        member = role;
        break;
      }
    }
    if (member.isStaff) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Το QR είναι για τον ρόλο του ασκούμενου')),
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _kCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _GymQrSheet(gym: member, globalAuth: globalAuth),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
      decoration: BoxDecoration(
        color: const Color(0xFF17181D),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Row(children: [
              _GymLogo(url: gym.logoUrl, name: gym.appName, accent: accentColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(gym.appName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
              GestureDetector(
                onTap: () => _showQr(context),
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF14301C),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF3F8F55)),
                  ),
                  child: const Icon(Icons.qr_code_2_rounded, color: Color(0xFF86EFAC), size: 22),
                ),
              ),
            ]),
          ),
          const Divider(color: _kBorder, height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final role in roles) ...[
                  _HomeRoleButton(
                    label: _roleLabel(role),
                    tone: _tone(role),
                    onTap: () => onEnter(role),
                  ),
                  if (!role.isStaff && packageLine != null) ...[
                    const SizedBox(height: 8),
                    Text('Πακέτο', style: GoogleFonts.manrope(fontSize: 13, color: _kGray)),
                    const SizedBox(height: 2),
                    Text(packageLine!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                  ],
                  const SizedBox(height: 8),
                  _NextAppointment(
                    booking: _nextFor(role),
                    onTap: () {
                      final booking = _nextFor(role);
                      if (booking != null) onOpenBooking(booking);
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                GestureDetector(
                  onTap: onAddRole,
                  child: Container(
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF12131A),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _kBorder),
                    ),
                    child: Text('+  Νέος ρόλος',
                      style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
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
}

class _RoleTone {
  const _RoleTone(this.bg, this.fg, this.border, this.icon);
  final Color bg;
  final Color fg;
  final Color border;
  final IconData icon;
}

class _HomeRoleButton extends StatelessWidget {
  const _HomeRoleButton({required this.label, required this.tone, required this.onTap});
  final String label;
  final _RoleTone tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: tone.bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: tone.border),
        ),
        child: Row(children: [
          Icon(tone.icon, size: 18, color: tone.fg),
          const SizedBox(width: 8),
          Text(label, style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w700, color: tone.fg)),
        ]),
      ),
    );
  }
}

class _NextAppointment extends StatelessWidget {
  const _NextAppointment({required this.booking, required this.onTap});
  final Map<String, dynamic>? booking;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final time = (booking?['booking_time'] as String? ?? '');
    final hhmm = time.length >= 5 ? time.substring(0, 5) : '';
    final service = (booking?['service_name'] as String? ?? '').toUpperCase();
    return GestureDetector(
      onTap: booking == null ? null : onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Επόμενο ραντεβού',
          style: GoogleFonts.manrope(fontSize: 13, color: _kGray)),
        const SizedBox(height: 2),
        Text(
          booking == null ? 'Δεν υπάρχει ραντεβού' : '$hhmm · $service',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: booking == null ? _kGray : Colors.white,
          ),
        ),
      ]),
    );
  }
}

class _GymQrSheet extends StatefulWidget {
  const _GymQrSheet({required this.gym, required this.globalAuth});
  final GlobalGym gym;
  final GlobalAuthService globalAuth;

  @override
  State<_GymQrSheet> createState() => _GymQrSheetState();
}

class _GymQrSheetState extends State<_GymQrSheet> {
  String? _token;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final gymToken = await widget.globalAuth.getGymToken(widget.gym.businessId);
      final res = await http.get(
        Uri.parse('https://passionate-grace-production-98ad.up.railway.app/api/checkin/${widget.gym.businessId}/my-code'),
        headers: {'Authorization': 'Bearer $gymToken'},
      );
      final body = jsonDecode(res.body);
      if (res.statusCode != 200) throw body['error']?.toString() ?? 'Αποτυχία QR';
      if (mounted) setState(() => _token = body['token']?.toString());
    } catch (e) {
      if (mounted) setState(() => _error = '$e'.replaceFirst('Exception: ', ''));
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 36, height: 4, decoration: BoxDecoration(color: _kBorder, borderRadius: BorderRadius.circular(99))),
        const SizedBox(height: 16),
        Text(widget.gym.appName, style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
        const SizedBox(height: 4),
        Text('Δείξε το QR στο γυμναστήριο', style: GoogleFonts.manrope(fontSize: 13, color: _kGray)),
        const SizedBox(height: 16),
        if (_loading)
          const Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: Color(0xFF86EFAC)))
        else if (_error != null)
          Padding(padding: const EdgeInsets.all(16), child: Text(_error!, style: const TextStyle(color: Colors.white70)))
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: QrImageView(data: _token ?? '', size: 200, backgroundColor: Colors.white),
          ),
      ]),
    );
  }
}

int _roleRank(GlobalGym gym) {
  if (gym.staffKind == 'nutritionist') return 0;
  if (gym.staffKind == 'physiotherapist') return 1;
  if (!gym.isStaff) return 2;
  return 3;
}

List<GlobalGym> _rolesFirst(List<GlobalGym> roles) {
  final copy = [...roles]..sort((a, b) => _roleRank(a).compareTo(_roleRank(b)));
  return copy;
}

class _GymEntryCard extends StatefulWidget {
  const _GymEntryCard({
    required this.gym,
    required this.roles,
    required this.accentColor,
    required this.onEnter,
    required this.onAddRole,
    this.packageLine,
    this.nextBooking,
    this.onBookingTap,
    this.onRemove,
    this.margin = EdgeInsets.zero,
  });

  final GlobalGym gym;
  final List<GlobalGym> roles;
  final Color accentColor;
  final Future<void> Function(GlobalGym) onEnter;
  final VoidCallback onAddRole;
  final String? packageLine;
  final Map<String, dynamic>? nextBooking;
  final VoidCallback? onBookingTap;
  final VoidCallback? onRemove;
  final EdgeInsets margin;

  @override
  State<_GymEntryCard> createState() => _GymEntryCardState();
}

class _GymEntryCardState extends State<_GymEntryCard> {
  final _rolesScroll = ScrollController();
  GlobalGym? _selected;
  bool _rolesOverflow = false;
  int _roleDot = 0;

  @override
  void initState() {
    super.initState();
    _rolesScroll.addListener(_syncOverflow);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncOverflow());
  }

  @override
  void didUpdateWidget(covariant _GymEntryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selected != null && !widget.roles.any((role) => _sameRole(role, _selected!))) {
      _selected = null;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncOverflow());
  }

  @override
  void dispose() {
    _rolesScroll.dispose();
    super.dispose();
  }

  void _syncOverflow() {
    if (!mounted || !_rolesScroll.hasClients) return;
    final max = _rolesScroll.position.maxScrollExtent;
    final overflow = max > 8;
    final dot = !overflow ? 0 : ((_rolesScroll.offset / max) * 2).round().clamp(0, 2);
    if (overflow != _rolesOverflow || dot != _roleDot) {
      setState(() {
        _rolesOverflow = overflow;
        _roleDot = dot;
      });
    }
  }

  bool _sameRole(GlobalGym a, GlobalGym b) {
    if (a.isStaff != b.isStaff) return false;
    if (!a.isStaff) return true;
    return (a.staffKind ?? 'trainer') == (b.staffKind ?? 'trainer');
  }

  String _label(GlobalGym gym) {
    if (!gym.isStaff) return 'Ασκούμενος';
    if (gym.staffKind == 'nutritionist') return 'Διατροφολόγος';
    if (gym.staffKind == 'physiotherapist') return 'Φυσιοθεραπευτής';
    return 'Προπονητής';
  }

  IconData _icon(GlobalGym gym) {
    if (!gym.isStaff) return Icons.fitness_center_rounded;
    if (gym.staffKind == 'nutritionist') return Icons.apple_rounded;
    if (gym.staffKind == 'physiotherapist') return Icons.healing_rounded;
    return Icons.person_rounded;
  }

  String _typeLabel(GlobalGym gym) {
    final type = gym.businessType.toLowerCase();
    if (type == 'gym' || type.contains('γυμν')) return 'Γυμναστήριο';
    return gym.businessType;
  }

  void _confirmRemove() {
    final gym = widget.gym;
    final onRemove = widget.onRemove;
    if (onRemove == null) return;
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

  @override
  Widget build(BuildContext context) {
    final gym = widget.gym;
    final accent = widget.accentColor;
    final onFill = accent.computeLuminance() > 0.62 ? const Color(0xFF111111) : Colors.white;
    final isPending = !gym.isStaff && gym.userStatus == 'pending';
    final selected = _selected;
    final next = widget.nextBooking;
    final rawTime = next?['booking_time'] as String? ?? '';
    final nextStr = next == null
        ? null
        : '${rawTime.length >= 5 ? rawTime.substring(0, 5) : rawTime} · ${next['service_name'] ?? ''}';

    return Container(
      margin: widget.margin,
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _kBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 8, 12),
            child: Row(children: [
              _GymLogo(url: gym.logoUrl, name: gym.appName, accent: accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(gym.appName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(height: 2),
                  Text(_typeLabel(gym),
                    style: GoogleFonts.manrope(fontSize: 12, color: _kGray)),
                  if (!isPending && widget.packageLine != null) ...[
                    const SizedBox(height: 2),
                    Text(widget.packageLine!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                  ],
                ]),
              ),
              if (widget.onRemove != null)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: _kGray, size: 20),
                  color: const Color(0xFF1C1C2E),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (value) {
                    if (value == 'remove') _confirmRemove();
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
          const Divider(color: _kBorder, height: 1),
          if (isPending)
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Row(children: [
                Icon(Icons.hourglass_empty_rounded, color: Color(0xFFF59E0B), size: 16),
                SizedBox(width: 8),
                Expanded(child: Text('Αναμονή έγκρισης γυμναστηρίου',
                  style: TextStyle(fontSize: 13, color: Color(0xFFF59E0B), fontWeight: FontWeight.w600))),
              ]),
            )
          else ...[
            if (nextStr != null)
              GestureDetector(
                onTap: widget.onBookingTap,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                  child: Row(children: [
                    const Icon(Icons.calendar_today_outlined, size: 14, color: _kAccent),
                    const SizedBox(width: 6),
                    Expanded(child: Text('Επόμενη: $nextStr',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(fontSize: 12, color: Colors.white))),
                  ]),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Row(children: [
                const Icon(Icons.login_rounded, size: 15, color: _kGray),
                const SizedBox(width: 6),
                Expanded(
                  child: Text.rich(TextSpan(children: [
                    TextSpan(text: 'Βήμα 1: ', style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
                    TextSpan(text: 'Επίλεξε ρόλο εισόδου', style: GoogleFonts.manrope(fontSize: 12, color: _kGray)),
                  ])),
                ),
                if (widget.roles.length > 2)
                  Text('${widget.roles.length} ρόλοι',
                    style: GoogleFonts.manrope(fontSize: 12, color: _kGray, fontWeight: FontWeight.w600)),
              ]),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 44,
              child: ListView(
                controller: _rolesScroll,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                children: [
                  for (final role in widget.roles) ...[
                    _EntryRoleChip(
                      label: _label(role),
                      icon: _icon(role),
                      selected: selected != null && _sameRole(role, selected),
                      onTap: () => setState(() => _selected = role),
                    ),
                    const SizedBox(width: 8),
                  ],
                  _NewRoleChip(onTap: widget.onAddRole),
                ],
              ),
            ),
            if (_rolesOverflow)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (i) {
                    final active = _roleDot == i;
                    return Container(
                      width: active ? 14 : 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: active ? Colors.white : _kGray.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    );
                  }),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: _EntryConnectButton(
                enabled: selected != null,
                color: accent,
                onFill: onFill,
                label: selected == null ? 'Επίλεξε πρώτα ρόλο' : 'Σύνδεση ως ${_label(selected)}',
                onTap: selected == null ? null : () => widget.onEnter(selected),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EntryRoleChip extends StatelessWidget {
  const _EntryRoleChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const selectedColor = Color(0xFF7C5CFC);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? selectedColor : const Color(0xFF12131A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? selectedColor : _kBorder),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: selected ? Colors.white : _kGray),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.manrope(
            fontSize: 13, fontWeight: FontWeight.w700,
            color: selected ? Colors.white : Colors.white)),
          if (selected) ...[
            const SizedBox(width: 6),
            const Icon(Icons.check_rounded, size: 16, color: Colors.white),
          ],
        ]),
      ),
    );
  }
}

class _NewRoleChip extends StatelessWidget {
  const _NewRoleChip({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: const _DashedRRectPainter(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: SizedBox(
            height: 44,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.add_rounded, size: 16, color: _kGray),
              const SizedBox(width: 4),
              Text('Νέος', style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  const _DashedRRectPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(14)));
    final paint = Paint()
      ..color = _kBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + 5), paint);
        distance += 9;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _EntryConnectButton extends StatelessWidget {
  const _EntryConnectButton({
    required this.enabled,
    required this.color,
    required this.onFill,
    required this.label,
    required this.onTap,
  });

  final bool enabled;
  final Color color;
  final Color onFill;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled ? color : const Color(0xFF12131A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: enabled ? color : _kBorder),
          boxShadow: enabled
              ? [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 18, offset: const Offset(0, 6))]
              : null,
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (!enabled) ...[
            const Icon(Icons.lock_outline_rounded, size: 16, color: _kGray),
            const SizedBox(width: 8),
          ],
          Text(label, style: GoogleFonts.manrope(
            fontSize: 15, fontWeight: FontWeight.w800,
            color: enabled ? onFill : _kGray)),
          if (enabled) ...[
            const SizedBox(width: 6),
            Icon(Icons.arrow_forward_rounded, size: 18, color: onFill),
          ],
        ]),
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
  const _DiscoverTab({
    required this.globalAuth,
    required this.onRequestSent,
    required this.onGymAdded,
    required this.onPurchaseComplete,
  });
  final GlobalAuthService globalAuth;
  final VoidCallback onRequestSent;
  final VoidCallback onGymAdded;
  final PurchaseComplete onPurchaseComplete;

  @override
  Widget build(BuildContext context) {
    return DiscoveryLandingScreen(
      globalAuth: globalAuth,
      onLoggedIn: () {},
      onRequestSent: onRequestSent,
      onGymAdded: onGymAdded,
      onPurchaseComplete: onPurchaseComplete,
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
  String? _gymId;
  String? _locationId;

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
    final all = _scoped;
    if (all.isEmpty) return;
    final todayKey = _dateKey(DateTime.now());
    if (all.any((b) => (b['booking_date'] as String? ?? '') == todayKey)) return;
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    DateTime? pick;
    for (final b in all) {
      final date = DateTime.tryParse(b['booking_date'] as String? ?? '');
      if (date == null) continue;
      final day = DateTime(date.year, date.month, date.day);
      if (day.isBefore(startOfToday)) continue;
      if (pick == null || day.isBefore(pick)) pick = day;
    }
    pick ??= () {
      DateTime? latest;
      for (final b in all) {
        final date = DateTime.tryParse(b['booking_date'] as String? ?? '');
        if (date == null) continue;
        if (latest == null || date.isAfter(latest)) latest = date;
      }
      return latest;
    }();
    if (pick == null) return;
    final monday = startOfToday.subtract(Duration(days: startOfToday.weekday - 1));
    final weekOffset = pick.difference(monday).inDays ~/ 7;
    if (mounted) setState(() { _selected = pick!; _weekOffset = weekOffset; });
  }

  List<Map<String, dynamic>> get _all =>
      (widget.dashboard?['upcoming_bookings'] as List?)
          ?.cast<Map<String, dynamic>>() ?? [];

  List<Map<String, dynamic>> get _scoped => _all.where((b) {
    if (_gymId != null && b['business_id']?.toString() != _gymId) return false;
    if (_locationId != null && b['location_id']?.toString() != _locationId) return false;
    return true;
  }).toList();

  List<Map<String, dynamic>> get _stores {
    final raw = widget.dashboard?['locations'];
    final fromApi = raw is List
        ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).where((l) {
            if (_gymId == null) return true;
            return l['business_id']?.toString() == _gymId;
          }).toList()
        : <Map<String, dynamic>>[];
    if (fromApi.isNotEmpty) return fromApi;
    final seen = <String, String>{};
    for (final b in _all) {
      if (_gymId != null && b['business_id']?.toString() != _gymId) continue;
      final id = b['location_id']?.toString() ?? '';
      final name = b['location_name']?.toString() ?? '';
      if (id.isNotEmpty && name.isNotEmpty) seen[id] = name;
    }
    return seen.entries.map((e) => {'id': e.key, 'name': e.value}).toList();
  }

  Set<String> get _bookedDates =>
      _scoped.map((b) => (b['booking_date'] as String? ?? '')).toSet();

  List<Map<String, dynamic>> get _forDay {
    final ds = '${_selected.year.toString().padLeft(4, '0')}-'
        '${_selected.month.toString().padLeft(2, '0')}-'
        '${_selected.day.toString().padLeft(2, '0')}';
    final list = _scoped.where((b) => b['booking_date'] == ds).map((b) {
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
            if (widget.gyms.length > 1) ...[
              const SizedBox(height: 14),
              _filterRow(
                label: 'Γυμναστήριο',
                selected: _gymId,
                options: widget.gyms.map((g) => (id: g.businessId, name: g.appName)).toList(),
                onPick: (id) => setState(() {
                  _gymId = id;
                  _locationId = null;
                }),
              ),
            ],
            if (_stores.length > 1) ...[
              const SizedBox(height: 10),
              _filterRow(
                label: 'Κατάστημα',
                selected: _locationId,
                options: _stores.map((l) => (id: l['id']?.toString() ?? '', name: l['name']?.toString() ?? '')).toList(),
                onPick: (id) => setState(() => _locationId = id),
              ),
            ],
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

  Widget _filterRow({
    required String label,
    required String? selected,
    required List<({String id, String name})> options,
    required ValueChanged<String?> onPick,
  }) {
    final chips = <({String? id, String name})>[
      (id: null, name: 'Συνολικά'),
      ...options.where((o) => o.id.isNotEmpty && o.name.isNotEmpty).map((o) => (id: o.id, name: o.name)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(label, style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: _kGray)),
        ),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: chips.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final chip = chips[i];
              final on = selected == chip.id;
              return GestureDetector(
                onTap: () => onPick(chip.id),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: on ? _kBrandGradient : null,
                    color: on ? null : _kCard,
                    borderRadius: BorderRadius.circular(999),
                    border: on ? null : Border.all(color: _kBorder),
                  ),
                  child: Text(chip.name, style: GoogleFonts.manrope(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: on ? Colors.white : _kGray,
                  )),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _syncGoogleCalendar() async {
    final bookings = _scoped.where((b) {
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
            Flexible(child: Text(
              [
                gym,
                if ((booking['location_name'] as String?)?.isNotEmpty == true) booking['location_name'],
              ].join(' · '),
              overflow: TextOverflow.ellipsis,
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
    required this.packageLine,
    required this.onPurchaseComplete,
  });

  final int listVersion;
  final GlobalAuthService globalAuth;
  final bool enteringGym;
  final Future<void> Function(GlobalGym) onEnterGym;
  final VoidCallback onAddGym;
  final Future<void> Function(GlobalGym) onRemoveGym;
  final Color Function(String?) parseColor;
  final String? Function(String businessId) packageLine;
  final PurchaseComplete onPurchaseComplete;

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
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Τα Γυμναστήριά Μου',
                      style: GoogleFonts.manrope(
                        fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
                    Text('$totalCount γυμναστήρια',
                      style: GoogleFonts.manrope(fontSize: 12, color: _kGray)),
                  ]),
                  const SizedBox(height: 20),

                  if (gyms.isNotEmpty) ...[
                    _sectionLabel('Τα γυμναστήριά σου'),
                    ...() {
                      final seen = <String>{};
                      final cards = <Widget>[];
                      for (final gym in gyms) {
                        if (!seen.add(gym.businessId)) continue;
                        final roles = _rolesFirst(gyms.where((g) => g.businessId == gym.businessId).toList());
                        cards.add(_GymEntryCard(
                          gym: roles.first,
                          roles: roles,
                          accentColor: widget.parseColor(roles.first.primaryColor),
                          margin: const EdgeInsets.only(bottom: 12),
                          packageLine: widget.packageLine(gym.businessId),
                          onEnter: widget.onEnterGym,
                          onAddRole: () {
                            Navigator.push(context, MaterialPageRoute(
                              builder: (_) => GymProfileScreen(
                                slug: gym.slug,
                                globalAuth: widget.globalAuth,
                                onPurchaseComplete: widget.onPurchaseComplete,
                              ),
                            ));
                          },
                          onRemove: () => widget.onRemoveGym(gym),
                        ));
                      }
                      return cards;
                    }(),
                  ],
                  if (staffPending.isNotEmpty || memberPending.isNotEmpty) ...[
                    _sectionLabel('Εκκρεμή αιτήματα'),
                    ...staffPending.map((req) => _PendingRequestCard(
                      request: req,
                      onCancel: () => _cancelRequest(req['id'] as String),
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
            _SettingRow(
              icon: Icons.draw_outlined,
              label: 'Ηλεκτρονικές εγγραφές',
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => ElectronicDocumentsScreen.global(
                  apiBase: 'https://passionate-grace-production-98ad.up.railway.app/api',
                  token: globalAuth.token ?? '',
                ),
              )),
            ),
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
    this.guest = false,
    this.onLogin,
  });

  final String letter;
  final int unread;
  final VoidCallback onNotifications;
  final VoidCallback onProfile;
  final bool guest;
  final VoidCallback? onLogin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SvgPicture.asset('assets/omniplex_logo.svg', height: 32),
          if (guest)
            GestureDetector(
              onTap: onLogin,
              child: Text('Σύνδεση', style: GoogleFonts.manrope(
                fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFFC52473))),
            )
          else
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
