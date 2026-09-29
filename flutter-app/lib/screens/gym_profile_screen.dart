import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../services/global_auth_service.dart';
import '../services/biometric_auth_service.dart';
import '../config/tenant_config.dart';
import 'phone_otp_login_screen.dart';

const _kBg     = Color(0xFF0A0A0A);
const _kCard   = Color(0xFF16171B);
const _kBorder = Color(0xFF2A2B30);
const _kGray   = Color(0xFF9A9CA3);
const _kLime   = Color(0xFFC6FF3D);

class GymProfileScreen extends StatefulWidget {
  const GymProfileScreen({
    super.key,
    this.gymName = '',
    this.slug,
    this.gymData,
    this.globalAuth,
    this.onLoggedIn,
    this.onEnterGym,
    this.initialTab = 0,
  });

  final String gymName;
  final String? slug;
  final Map<String, dynamic>? gymData;
  final GlobalAuthService? globalAuth;
  final VoidCallback? onLoggedIn;
  final void Function(TenantConfig)? onEnterGym;
  final int initialTab;

  @override
  State<GymProfileScreen> createState() => _GymProfileScreenState();
}

class _GymProfileScreenState extends State<GymProfileScreen>
    with SingleTickerProviderStateMixin {
  static const _apiBase = 'https://passionate-grace-production-98ad.up.railway.app/api';

  late TabController _tabCtrl;

  Map<String, dynamic>? _gym;
  List<Map<String, dynamic>> _packages = [];
  List<Map<String, dynamic>> _hours    = [];
  bool _loadingGym  = true;
  bool _loadingPkgs = true;
  bool _enteringGym = false;

  bool _joiningGym = false;
  bool _memberPending = false;
  bool _staffPending = false;

  String? get _slug => widget.slug ?? _gym?['slug'] as String?;
  bool get _memberLinked => widget.globalAuth != null &&
      _slug != null &&
      widget.globalAuth!.gyms.any((g) => g.slug == _slug && !g.isStaff);
  bool get _staffLinked => widget.globalAuth != null &&
      _slug != null &&
      widget.globalAuth!.gyms.any((g) => g.slug == _slug && g.isStaff);
  bool get _canEnter => _memberLinked || _staffLinked;
  bool get _canRequest => widget.globalAuth?.isLoggedIn == true &&
      !((_memberLinked || _memberPending) && (_staffLinked || _staffPending));

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this, initialIndex: widget.initialTab.clamp(0, 3));
    if (widget.gymData != null) {
      _gym = widget.gymData;
      _loadingGym = false;
    }
    _loadAll().then((_) {
      if (mounted) _loadJoinStatus();
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final slug = widget.slug ?? (widget.gymData?['slug'] as String?);
    if (slug == null) return;
    await Future.wait([
      _loadGym(slug),
      _loadPackages(slug),
      _loadHours(slug),
    ]);
  }

  Future<void> _loadJoinStatus() async {
    if (widget.globalAuth == null || !widget.globalAuth!.isLoggedIn) return;
    try {
      final res = await http.get(
        Uri.parse('$_apiBase/global/join-requests'),
        headers: {'Authorization': 'Bearer ${widget.globalAuth!.token}'},
      );
      if (!mounted || res.statusCode != 200) return;
      final list = jsonDecode(res.body) as List;
      final bizId = widget.gymData?['business_id'] as String? ?? _gym?['business_id'] as String?;
      var memberPending = false;
      var staffPending = false;
      for (final raw in list) {
        final r = raw as Map<String, dynamic>;
        if (bizId == null || r['business_id'] != bizId) continue;
        if (r['status'] != 'pending') continue;
        if (r['role'] == 'staff') staffPending = true;
        else memberPending = true;
      }
      setState(() {
        _memberPending = memberPending;
        _staffPending = staffPending;
      });
    } catch (_) {}
  }

  Future<void> _requestJoin() async {
    if (widget.globalAuth == null || !widget.globalAuth!.isLoggedIn) {
      _showLoginPrompt(); return;
    }
    final bizId = _gym?['business_id'] as String?;
    if (bizId == null) return;

    final locations = ((_gym?['locations'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    String? locationId;
    if (locations.length > 1) {
      final picked = await _showLocationPicker(locations);
      if (picked == null || !mounted) return;
      locationId = picked;
    } else if (locations.length == 1) {
      locationId = locations.first['id'] as String?;
    }

    final role = await _showRolePicker();
    if (role == null || !mounted) return;

    final user = widget.globalAuth!.user;
    await _submitJoinRequest(bizId, role, {
      'full_name': user?.fullName,
      'phone': user?.phone,
      if ((user?.email ?? '').isNotEmpty) 'email': user!.email,
      if (locationId != null) 'location_id': locationId,
    });
  }

  Future<String?> _showLocationPicker(List<Map<String, dynamic>> locations) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        decoration: BoxDecoration(
          color: const Color(0xFF16171B),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF2A2B30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text('Σε ποιο κατάστημα;',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
            const SizedBox(height: 6),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text('Η έγκριση και οι κρατήσεις ισχύουν για το κατάστημα που θα διαλέξεις',
                style: TextStyle(fontSize: 13, color: Color(0xFF9A9CA3))),
            ),
            const SizedBox(height: 16),
            ...locations.map((loc) => _RoleOption(
              icon: Icons.location_on_outlined,
              color: const Color(0xFFC6FF3D),
              title: loc['name'] as String? ?? 'Κατάστημα',
              subtitle: [
                loc['address'] as String?,
                loc['city'] as String?,
                (loc['accepts_drop_in'] == true || loc['accepts_drop_in'] == 1) ? 'Drop-in' : null,
              ].whereType<String>().where((s) => s.trim().isNotEmpty).join(' · '),
              onTap: () => Navigator.pop(sheetCtx, loc['id'] as String),
            )),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<String?> _showRolePicker() {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        decoration: BoxDecoration(
          color: const Color(0xFF16171B),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF2A2B30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('Πώς θα συνδεθείς;',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('Επέλεξε τον ρόλο σου σε αυτό το γυμναστήριο',
                style: const TextStyle(fontSize: 13, color: Color(0xFF9A9CA3))),
            ),
            const SizedBox(height: 20),
            if (!_memberLinked && !_memberPending)
              _RoleOption(
                icon: Icons.fitness_center_rounded,
                color: const Color(0xFFC6FF3D),
                title: 'Ασκούμενος',
                subtitle: 'Θέλω να κάνω κρατήσεις ως πελάτης',
                onTap: () => Navigator.pop(sheetCtx, 'member'),
              ),
            if (!_memberLinked && !_memberPending && !_staffLinked && !_staffPending)
              const SizedBox(height: 10),
            if (!_staffLinked && !_staffPending)
              _RoleOption(
                icon: Icons.sports_rounded,
                color: const Color(0xFF3EE6FF),
                title: 'Trainer',
                subtitle: 'Εργάζομαι σε αυτό το γυμναστήριο',
                onTap: () => Navigator.pop(sheetCtx, 'staff'),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _submitJoinRequest(String bizId, String role, Map<String, String?> formData) async {
    setState(() => _joiningGym = true);
    try {
      final payload = <String, dynamic>{
        'business_id': bizId,
        'role': role,
        ...formData.map((k, v) => MapEntry(k, v)),
      };
      payload.removeWhere((_, v) => v == null);
      final res = await http.post(
        Uri.parse('$_apiBase/global/join-requests'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.globalAuth!.token}',
        },
        body: jsonEncode(payload),
      );
      if (!mounted) return;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 || res.statusCode == 201) {
        await _loadJoinStatus();
        await widget.globalAuth!.refreshGyms();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Το αίτημα στάλθηκε. Θα μπεις στο γυμναστήριο μόλις εγκριθεί.'),
            backgroundColor: Color(0xFF16171B),
          ),
        );
      } else {
        final err = body['message'] ?? body['error'] ?? 'Σφάλμα';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err.toString()), backgroundColor: Colors.red.shade700));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red.shade700));
    } finally {
      if (mounted) setState(() => _joiningGym = false);
    }
  }

  Future<void> _loadGym(String slug) async {
    if (widget.gymData != null) { setState(() => _loadingGym = false); return; }
    try {
      final res = await http.get(Uri.parse('$_apiBase/global/discovery/gyms/$slug'));
      if (res.statusCode == 200 && mounted) {
        setState(() { _gym = jsonDecode(res.body) as Map<String, dynamic>; _loadingGym = false; });
      }
    } catch (_) { if (mounted) setState(() => _loadingGym = false); }
  }

  Future<void> _loadPackages(String slug) async {
    try {
      final res = await http.get(Uri.parse('$_apiBase/global/discovery/gyms/$slug/packages'));
      if (mounted) {
        setState(() {
          if (res.statusCode == 200) {
            _packages = (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
          }
          _loadingPkgs = false;
        });
      }
    } catch (_) { if (mounted) setState(() => _loadingPkgs = false); }
  }

  Future<void> _loadHours(String slug) async {
    try {
      final res = await http.get(Uri.parse('$_apiBase/global/discovery/gyms/$slug/opening-hours'));
      if (res.statusCode == 200 && mounted) {
        setState(() => _hours = (jsonDecode(res.body) as List).cast<Map<String, dynamic>>());
      }
    } catch (_) {}
  }

  Color _accentColor() {
    final hex = _gym?['primary_color'] as String?;
    if (hex == null) return _kLime;
    try { return Color(int.parse(hex.replaceFirst('#', '0xFF'))); }
    catch (_) { return _kLime; }
  }

  Future<void> _enterGym() async {
    if (widget.globalAuth == null || _gym == null) return;
    setState(() => _enteringGym = true);
    try {
      final bizId = _gym!['business_id'] as String;
      final gymToken = _memberLinked
          ? await widget.globalAuth!.getGymToken(bizId)
          : await widget.globalAuth!.getTrainerToken(bizId);
      await BiometricAuthService.instance.saveToken(bizId, gymToken);
      final config = await TenantConfig.loadFromApi(
        slug:       _slug!,
        apiBaseUrl: 'https://passionate-grace-production-98ad.up.railway.app',
      );
      if (!mounted) return;
      if (widget.onEnterGym != null) {
        widget.onEnterGym!(config);
      } else {
        widget.onLoggedIn?.call();
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red.shade700),
      );
    } finally {
      if (mounted) setState(() => _enteringGym = false);
    }
  }

  Future<void> _purchasePlan(Map<String, dynamic> plan) async {
    if (widget.globalAuth == null || !widget.globalAuth!.isLoggedIn) {
      _showLoginPrompt();
      return;
    }
    final slug = _slug;
    if (slug == null) return;

    final planId = plan['id'] as String;
    final user   = widget.globalAuth!.user!;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: _kLime)),
    );

    try {
      // Create payment intent
      final res = await http.post(
        Uri.parse('$_apiBase/global/purchase/$slug/intent'),
        headers: {'Content-Type': 'application/json',
                   'Authorization': 'Bearer ${widget.globalAuth!.token}'},
        body: jsonEncode({
          'plan_id': planId,
          'user_info': {
            'full_name': user.fullName,
            'email':     user.email,
          },
        }),
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // close loading

      if (res.statusCode != 200) {
        final err = (jsonDecode(res.body) as Map?)?['error'] ?? 'Σφάλμα';
        _showError(err.toString());
        return;
      }

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final clientSecret    = body['client_secret'] as String;
      final publishableKey  = body['publishable_key'] as String;
      final intentId        = body['intent_id'] as String;

      Stripe.publishableKey = publishableKey;

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: _gym?['app_name'] as String? ?? 'OmniPlex',
          style: ThemeMode.dark,
          appearance: const PaymentSheetAppearance(
            colors: PaymentSheetAppearanceColors(
              primary: _kLime,
              background: _kBg,
              componentBackground: _kCard,
              componentBorder: _kBorder,
              primaryText: Colors.white,
              secondaryText: _kGray,
            ),
          ),
        ),
      );

      await Stripe.instance.presentPaymentSheet();

      // Payment succeeded — confirm on backend
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator(color: _kLime)),
      );

      final confirm = await http.post(
        Uri.parse('$_apiBase/global/purchase/$slug/confirm'),
        headers: {'Content-Type': 'application/json',
                   'Authorization': 'Bearer ${widget.globalAuth!.token}'},
        body: jsonEncode({
          'intent_id': intentId,
          'plan_id':   planId,
          'user_info': {'full_name': user.fullName, 'email': user.email},
        }),
      );

      if (!mounted) return;
      Navigator.of(context).pop();

      if (confirm.statusCode == 200) {
        await widget.globalAuth!.refreshGyms();
        _showSuccess(plan['name'] as String);
      } else {
        final err = (jsonDecode(confirm.body) as Map?)?['error'] ?? 'Σφάλμα';
        _showError(err.toString());
      }
    } on StripeException catch (e) {
      if (!mounted) return;
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      if (e.error.code != FailureCode.Canceled) {
        _showError(e.error.localizedMessage ?? 'Η πληρωμή απέτυχε');
      }
    } catch (e) {
      if (!mounted) return;
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      _showError(e.toString());
    }
  }

  void _showLoginPrompt() {
    final navigator = Navigator.of(context);
    final myRoute   = ModalRoute.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: _kCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(
            color: _kBorder, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Text('Απαιτείται σύνδεση',
            style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 8),
          Text('Συνδέσου ή δημιούργησε λογαριασμό για να στείλεις αίτημα εγγραφής.',
            style: GoogleFonts.manrope(fontSize: 14, color: _kGray), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          _limeButton('Σύνδεση / Εγγραφή', () {
            Navigator.pop(sheetCtx); // close bottom sheet
            navigator.push(MaterialPageRoute(
              builder: (_) => PhoneOtpLoginScreen(
                globalAuth: widget.globalAuth!,
                onLoggedIn: () {
                  // Pop OTP/profile/role screens back to this gym profile
                  navigator.popUntil((route) => route == myRoute);
                  // Re-trigger join now that user is logged in
                  if (mounted) Future.microtask(_requestJoin);
                },
              ),
            ));
          }),
        ]),
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700));
  }

  void _showSuccess(String planName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _kCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(color: _kLime.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: const Icon(Icons.check_circle_rounded, color: _kLime, size: 36)),
          const SizedBox(height: 16),
          Text('Επιτυχής αγορά!',
            style: GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 8),
          Text('Το πακέτο "$planName" ενεργοποιήθηκε στον λογαριασμό σου.',
            style: GoogleFonts.manrope(fontSize: 14, color: _kGray), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          _limeButton('Ωραία!', () => Navigator.pop(context)),
        ]),
      ),
    );
  }

  // ─── BUILD ───

  @override
  Widget build(BuildContext context) {
    final accent   = _accentColor();
    final gymName  = _gym?['app_name'] as String? ?? _gym?['name'] as String? ?? widget.gymName;
    final coverUrl = _gym?['cover_url'] as String? ?? _gym?['cover_image_url'] as String?;
    final logoUrl  = _gym?['logo_url'] as String?;

    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        children: [
          NestedScrollView(
            headerSliverBuilder: (_, __) => [
              SliverToBoxAdapter(child: _buildHero(gymName, coverUrl, logoUrl, accent)),
              SliverToBoxAdapter(child: _buildTitleSection(gymName)),
              SliverToBoxAdapter(child: _buildTabBar()),
            ],
            body: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildOverviewTab(),
                _buildScheduleTab(),
                _buildPackagesTab(),
                _buildReviewsTab(),
              ],
            ),
          ),

          // Bottom CTA bar
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: _buildBottomBar(),
          ),

          if (_enteringGym)
            const ColoredBox(
              color: Color(0xAA000000),
              child: Center(child: CircularProgressIndicator(color: Colors.white)),
            ),
        ],
      ),
    );
  }

  Widget _buildHero(String name, String? coverUrl, String? logoUrl, Color accent) {
    return SizedBox(
      height: 300,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Cover
          coverUrl != null
            ? Image.network(coverUrl, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _gymPlaceholder(accent, name))
            : _gymPlaceholder(accent, name),

          // Gradient overlay
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.black.withValues(alpha: 0.4), _kBg.withValues(alpha: 0.95)],
              ),
            ),
          ),

          // Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _glassBtn(onTap: () => Navigator.maybePop(context),
                    child: const Icon(Icons.arrow_back, color: Colors.white, size: 20)),
                  Row(children: [
                    _glassBtn(child: const Icon(Icons.bookmark_border, color: Colors.white, size: 20)),
                    const SizedBox(width: 10),
                    _glassBtn(child: const Icon(Icons.share_outlined, color: Colors.white, size: 20)),
                  ]),
                ],
              ),
            ),
          ),

        ],
      ),
    );
  }

  Widget _buildTitleSection(String name) {
    final city    = _gym?['city'] as String? ?? '';
    final rating  = (_gym?['rating'] as num?)?.toStringAsFixed(1);
    final reviews = _gym?['review_count'] as int? ?? 0;
    final logoUrl = _gym?['logo_url'] as String?;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (logoUrl != null && logoUrl.isNotEmpty) ...[
          Container(
            height: 52,
            constraints: const BoxConstraints(maxWidth: 200),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Image.network(logoUrl, fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const SizedBox()),
          ),
          const SizedBox(height: 14),
        ],
        _loadingGym
          ? _shimmer(220, 26)
          : Text(name, style: GoogleFonts.manrope(
              fontSize: 24, fontWeight: FontWeight.w700,
              color: Colors.white, letterSpacing: -0.6)),
        const SizedBox(height: 6),
        if (rating != null)
          Row(children: [
            const Icon(Icons.star_rounded, color: Colors.white, size: 14),
            const SizedBox(width: 4),
            Text(rating, style: GoogleFonts.manrope(
              fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
            if (reviews > 0) ...[
              const SizedBox(width: 6),
              Text('($reviews αξιολογήσεις)', style: GoogleFonts.manrope(
                fontSize: 12, color: _kGray)),
            ],
          ]),
        if (city.isNotEmpty) ...[
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.location_on_outlined, color: _kGray, size: 14),
            const SizedBox(width: 4),
            Text(city, style: GoogleFonts.manrope(fontSize: 13, color: _kGray)),
          ]),
        ],
        const SizedBox(height: 20),
      ]),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: TabBar(
        controller: _tabCtrl,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        labelStyle: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700),
        unselectedLabelStyle: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w600),
        labelColor: _kBg,
        unselectedLabelColor: _kGray,
        tabs: const [
          Tab(text: 'Επισκόπηση'),
          Tab(text: 'Πρόγραμμα'),
          Tab(text: 'Πακέτα'),
          Tab(text: 'Κριτικές'),
        ],
      ),
    );
  }

  // ── Overview Tab ──

  Widget _buildOverviewTab() {
    final desc     = _gym?['description'] as String?;
    final services = (_gym?['services'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final photos   = (_gym?['photos'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Photo carousel
        if (photos.isNotEmpty) ...[
          SizedBox(
            height: 190,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: photos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  photos[i]['url'] as String,
                  width: photos.length == 1 ? double.infinity : 260,
                  height: 190,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 260, height: 190, color: _kCard,
                    child: const Icon(Icons.broken_image_outlined, color: _kGray)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
        ],

        if (desc != null && desc.isNotEmpty) ...[
          _sectionTitle('Σχετικά'),
          const SizedBox(height: 8),
          Text(desc, style: GoogleFonts.manrope(fontSize: 14, color: _kGray, height: 1.625)),
          const SizedBox(height: 28),
        ],

        if (services.isNotEmpty) ...[
          _sectionTitle('Υπηρεσίες'),
          const SizedBox(height: 14),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: services.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final s = services[i];
              final imageUrl = s['image_url'] as String?;
              final description = s['description'] as String?;
              return GestureDetector(
                onTap: (description != null && description.isNotEmpty)
                    ? () => showModalBottomSheet(
                          context: context,
                          backgroundColor: _kCard,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          builder: (_) => Padding(
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Center(
                                  child: Container(
                                    width: 36, height: 4,
                                    decoration: BoxDecoration(
                                      color: _kBorder,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(s['name'] as String? ?? '',
                                  style: GoogleFonts.manrope(
                                    fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
                                const SizedBox(height: 10),
                                Text(description,
                                  style: GoogleFonts.manrope(fontSize: 14, color: _kGray, height: 1.6)),
                              ],
                            ),
                          ),
                        )
                    : null,
                child: Container(
                  decoration: BoxDecoration(
                    color: _kCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _kBorder),
                  ),
                  child: Row(
                    children: [
                      if (imageUrl != null && imageUrl.isNotEmpty)
                        ClipRRect(
                          borderRadius: const BorderRadius.horizontal(left: Radius.circular(13)),
                          child: Image.network(
                            imageUrl,
                            width: 68, height: 68,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 68, height: 68, color: _kBorder,
                              child: const Icon(Icons.fitness_center, color: Colors.white38, size: 24)),
                          ),
                        )
                      else
                        Container(
                          width: 68, height: 68,
                          decoration: BoxDecoration(
                            color: _kBorder,
                            borderRadius: const BorderRadius.horizontal(left: Radius.circular(13)),
                          ),
                          child: const Icon(Icons.fitness_center, color: Colors.white38, size: 24),
                        ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s['name'] as String? ?? '',
                              style: GoogleFonts.manrope(
                                fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                            if (description != null && description.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.manrope(fontSize: 12, color: _kGray, height: 1.4)),
                            ],
                          ],
                        ),
                      ),
                      if (description != null && description.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Icon(Icons.chevron_right, color: _kGray, size: 18),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 28),
        ],

        _sectionTitle('Ώρες Λειτουργίας'),
        const SizedBox(height: 14),
        _buildHoursCard(),
        const SizedBox(height: 28),

        _buildContactSection(),
      ]),
    );
  }

  Widget _buildContactSection() {
    final phone   = _gym?['phone'] as String?;
    final email   = _gym?['email'] as String?;
    final website = _gym?['website'] as String?;
    final address = _gym?['address'] as String?;

    final items = <Map<String, dynamic>>[
      if (phone != null && phone.isNotEmpty)
        {'icon': Icons.phone_outlined, 'label': phone},
      if (email != null && email.isNotEmpty)
        {'icon': Icons.email_outlined, 'label': email},
      if (website != null && website.isNotEmpty)
        {'icon': Icons.language_outlined, 'label': website},
      if (address != null && address.isNotEmpty)
        {'icon': Icons.location_on_outlined, 'label': address},
    ];

    if (items.isEmpty) return const SizedBox();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle('Επικοινωνία'),
      const SizedBox(height: 14),
      Container(
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kBorder),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          children: List.generate(items.length, (i) {
            final item = items[i];
            return Container(
              decoration: BoxDecoration(
                border: i < items.length - 1
                  ? const Border(bottom: BorderSide(color: Color(0xFF26272C)))
                  : null,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(children: [
                Icon(item['icon'] as IconData, color: _kGray, size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(item['label'] as String,
                    style: GoogleFonts.manrope(fontSize: 13, color: Colors.white)),
                ),
              ]),
            );
          }),
        ),
      ),
      const SizedBox(height: 28),
    ]);
  }

  Widget _buildHoursCard() {
    if (_hours.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kBorder),
        ),
        child: Text('Δεν υπάρχουν διαθέσιμα ωράρια',
          style: GoogleFonts.manrope(fontSize: 13, color: _kGray)),
      );
    }
    const dayNames = ['Κυρ', 'Δευ', 'Τρί', 'Τετ', 'Πέμ', 'Παρ', 'Σάβ'];
    final today = DateTime.now().weekday % 7; // Mon=1->1, Sun=7->0
    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: List.generate(_hours.length, (i) {
          final h = _hours[i];
          final dow     = (h['day_of_week'] as int?) ?? i;
          final isToday = dow == today;
          final closed  = h['is_closed'] as bool? ?? false;
          final open    = h['open_time'] as String? ?? '';
          final close   = h['close_time'] as String? ?? '';
          final timeStr = closed ? 'Κλειστό' : '${open.substring(0,5)} – ${close.substring(0,5)}';
          return Container(
            decoration: BoxDecoration(
              color: isToday ? _kLime.withValues(alpha: 0.08) : Colors.transparent,
              border: i < _hours.length - 1
                ? const Border(bottom: BorderSide(color: Color(0xFF26272C)))
                : null,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Row(children: [
                if (isToday) ...[
                  Container(width: 6, height: 6,
                    decoration: const BoxDecoration(color: _kLime, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                ],
                Text(dayNames[dow % 7],
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w600,
                    color: isToday ? _kLime : _kGray)),
              ]),
              Text(timeStr,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                  color: isToday ? _kLime : (closed ? _kGray.withValues(alpha: 0.5) : _kGray))),
            ]),
          );
        }),
      ),
    );
  }

  // ── Schedule Tab ──

  int _scheduleDay = 0; // 0 = today's day index

  Widget _buildScheduleTab() {
    final schedule = (_gym?['schedule'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final today = DateTime.now().weekday; // 1=Mon .. 7=Sun
    final dayLabels = ['', 'Δευ', 'Τρί', 'Τετ', 'Πέμ', 'Παρ', 'Σάβ', 'Κυρ'];

    // initialise to today on first build
    if (_scheduleDay == 0) _scheduleDay = today;

    final filtered = schedule.where((e) => (e['day_of_week'] as int?) == _scheduleDay).toList();

    if (schedule.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.calendar_month_outlined, color: _kGray, size: 48),
        const SizedBox(height: 12),
        Text('Δεν υπάρχει πρόγραμμα', style: GoogleFonts.manrope(
          fontSize: 14, color: _kGray)),
      ]));
    }

    // Which days actually have entries
    final activeDays = schedule.map((e) => e['day_of_week'] as int).toSet();

    return Column(
      children: [
        // Day selector
        Container(
          height: 48,
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kBorder),
          ),
          child: Row(
            children: List.generate(7, (i) {
              final day = i + 1;
              final isSelected = _scheduleDay == day;
              final hasEntries = activeDays.contains(day);
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _scheduleDay = day),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    alignment: Alignment.center,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Text(dayLabels[day],
                          style: GoogleFonts.manrope(
                            fontSize: 11, fontWeight: FontWeight.w700,
                            color: isSelected ? _kBg : (hasEntries ? Colors.white : _kGray))),
                        if (hasEntries && !isSelected)
                          Positioned(
                            bottom: -4, left: 0, right: 0,
                            child: Center(child: Container(
                              width: 4, height: 4,
                              decoration: const BoxDecoration(color: Colors.white54, shape: BoxShape.circle),
                            )),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: filtered.isEmpty
            ? Center(child: Text('Δεν υπάρχουν μαθήματα',
                style: GoogleFonts.manrope(fontSize: 13, color: _kGray)))
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _buildClassCard(filtered[i]),
              ),
        ),
      ],
    );
  }

  Widget _buildClassCard(Map<String, dynamic> entry) {
    final color = _parseClassColor(entry['color'] as String?);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Row(children: [
        Container(
          width: 4, height: 48,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 52,
          child: Text(entry['start_time'] as String? ?? '',
            style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(entry['class_name'] as String? ?? '',
              style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
            if ((entry['trainer_name'] as String?) != null)
              Text(entry['trainer_name'] as String,
                style: GoogleFonts.manrope(fontSize: 12, color: _kGray)),
            if ((entry['equipment'] as String?) != null)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Text(entry['equipment'] as String,
                  style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
              ),
          ]),
        ),
        if ((entry['max_capacity'] as int?) != null)
          Text('${entry['max_capacity']} άτ.',
            style: GoogleFonts.manrope(fontSize: 11, color: _kGray)),
      ]),
    );
  }

  Color _parseClassColor(String? hex) {
    if (hex == null) return _kLime;
    try {
      return Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));
    } catch (_) { return _kLime; }
  }

  // ── Packages Tab ──

  Widget _buildPackagesTab() {
    if (_loadingPkgs) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const CircularProgressIndicator(color: Colors.white),
        const SizedBox(height: 12),
        Text('Φόρτωση πακέτων...', style: GoogleFonts.manrope(fontSize: 13, color: _kGray)),
      ]));
    }
    if (_packages.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.inventory_2_outlined, color: _kGray, size: 48),
        const SizedBox(height: 12),
        Text('Δεν υπάρχουν διαθέσιμα πακέτα', style: GoogleFonts.manrope(fontSize: 13, color: _kGray)),
      ]));
    }

    // Group by service
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final p in _packages) {
      final svc = p['service_name'] as String? ?? 'Γενικά';
      grouped.putIfAbsent(svc, () => []).add(p);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
      children: grouped.entries.map((e) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(e.key, style: GoogleFonts.manrope(
              fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 12),
            ...e.value.map((p) => _buildPackageCard(p)),
            const SizedBox(height: 24),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildPackageCard(Map<String, dynamic> plan) {
    final name     = plan['name'] as String? ?? '';
    final sessions = plan['sessions'] as int?;
    final billing  = plan['billing_period'] as String?;
    final cents    = (plan['price_cents'] as int?) ?? 0;
    final euros    = (cents / 100).toStringAsFixed(cents % 100 == 0 ? 0 : 2);
    final svcName  = plan['service_name'] as String?;
    final imageUrl = plan['image_url'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (imageUrl != null && imageUrl.isNotEmpty)
          Image.network(
            imageUrl,
            width: double.infinity,
            height: 150,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox(),
          ),

        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Expanded(
                child: Text(name, style: GoogleFonts.manrope(
                  fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
              Text('€$euros',
                style: GoogleFonts.manrope(
                  fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
            ]),

            if (svcName != null && svcName.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(svcName, style: GoogleFonts.manrope(fontSize: 12, color: _kGray)),
            ],

            const SizedBox(height: 10),

            // Meta pills
            Wrap(spacing: 8, children: [
              if (sessions != null)
                _metaPill('$sessions ${sessions == 1 ? 'συνεδρία' : 'συνεδρίες'}',
                  Icons.fitness_center_outlined),
              if (billing != null)
                _metaPill(_billingLabel(billing), Icons.calendar_today_outlined),
            ]),

            const SizedBox(height: 14),

            _memberLinked
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.check_circle_outline, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text('Είσαι ήδη μέλος',
                      style: GoogleFonts.manrope(
                        fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                  ]),
                )
              : GestureDetector(
                  onTap: () => _purchasePlan(plan),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text('Αγορά πακέτου – €$euros',
                      style: GoogleFonts.manrope(
                        fontSize: 13, fontWeight: FontWeight.w700, color: _kBg, letterSpacing: 0.3)),
                  ),
                ),
          ]),
        ),
      ]),
    );
  }

  Widget _metaPill(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: _kBorder),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: _kGray),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.manrope(fontSize: 11, color: _kGray)),
      ]),
    );
  }

  // ── Reviews Tab ──

  Widget _buildReviewsTab() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            color: _kCard, shape: BoxShape.circle,
            border: Border.all(color: _kBorder)),
          child: const Icon(Icons.star_outline_rounded, color: _kGray, size: 32),
        ),
        const SizedBox(height: 16),
        Text('Δεν υπάρχουν κριτικές ακόμα',
          style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
        const SizedBox(height: 6),
        Text('Γίνε ο πρώτος που θα αξιολογήσει αυτό το γυμναστήριο.',
          style: GoogleFonts.manrope(fontSize: 13, color: _kGray),
          textAlign: TextAlign.center),
      ]),
    );
  }

  // ── Bottom Bar ──

  Widget _buildBottomBar() {
    return Container(
      decoration: BoxDecoration(
        color: _kBg.withValues(alpha: 0.96),
        border: const Border(top: BorderSide(color: _kBorder)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20,
        MediaQuery.of(context).padding.bottom + 16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (_canEnter)
          _limeButton('Άνοιξε το Γυμναστήριο', _enteringGym ? null : _enterGym,
              icon: Icons.fitness_center_rounded),
        if (!_canEnter && (_memberPending || _staffPending))
          _pendingJoinBanner(),
        if (_canEnter && (_memberPending || _staffPending)) ...[
          const SizedBox(height: 10),
          _pendingJoinBanner(),
        ],
        if (!_canEnter && !_memberPending && !_staffPending)
          Row(children: [
            if (_gym?['accepts_drop_in'] == true) ...[
              Expanded(
                child: _outlineButton('Κλείσε Drop-in', () => _tabCtrl.animateTo(2)),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: _limeButton('Δες Πακέτα', () => _tabCtrl.animateTo(2)),
            ),
          ]),
        if (_canRequest) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _joiningGym ? null : _requestJoin,
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _kBorder),
              ),
              alignment: Alignment.center,
              child: _joiningGym
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.add_circle_outline, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text('Αίτημα συμμετοχής',
                      style: GoogleFonts.manrope(
                        fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                  ]),
            ),
          ),
        ],
      ]),
    );
  }

  // ── Helpers ──

  Widget _pendingJoinBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFA500).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFA500).withValues(alpha: 0.4)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.schedule_rounded, color: Color(0xFFFFA500), size: 18),
        const SizedBox(width: 8),
        Flexible(
          child: Text('Το αίτημά σου εκκρεμεί έγκριση από τον διαχειριστή',
            style: GoogleFonts.manrope(
              fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFFFFA500)),
            textAlign: TextAlign.center),
        ),
      ]),
    );
  }

  Widget _limeButton(String label, VoidCallback? onTap, {IconData? icon}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: onTap == null ? Colors.white.withValues(alpha: 0.5) : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, color: _kBg, size: 18),
            const SizedBox(width: 8),
          ],
          Text(label, style: GoogleFonts.manrope(
            fontSize: 14, fontWeight: FontWeight.w700, color: _kBg, letterSpacing: 0.3)),
        ]),
      ),
    );
  }

  Widget _outlineButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kBorder),
        ),
        alignment: Alignment.center,
        child: Text(label, style: GoogleFonts.manrope(
          fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
      ),
    );
  }

  Widget _sectionTitle(String t) {
    return Text(t, style: GoogleFonts.manrope(
      fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.45));
  }

  Widget _glassBtn({required Widget child, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: const Color(0xCC16171B),
          shape: BoxShape.circle,
          border: Border.all(color: _kBorder),
        ),
        child: Center(child: child),
      ),
    );
  }

  Widget _gymPlaceholder(Color color, String name) {
    return Container(
      color: color.withValues(alpha: 0.08),
      alignment: Alignment.center,
      child: Icon(Icons.fitness_center_rounded, color: color.withValues(alpha: 0.4), size: 64),
    );
  }

  Widget _logoFallback(Color color, String name) {
    return Container(
      color: color.withValues(alpha: 0.12),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(color: color, fontSize: 28, fontWeight: FontWeight.w800)),
    );
  }

  Widget _shimmer(double w, double h) {
    return Container(
      width: w, height: h,
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(8)),
    );
  }

  String _billingLabel(String billing) {
    switch (billing) {
      case 'monthly':   return 'Μηνιαία';
      case 'quarterly': return 'Τριμηνιαία';
      case 'biannual':  return 'Εξαμηνιαία';
      case 'annual':    return 'Ετήσια';
      case 'one_time':  return 'Εφάπαξ';
      case 'drop_in':   return 'Drop-in';
      default:          return billing;
    }
  }
}

class _RoleOption extends StatelessWidget {
  const _RoleOption({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(height: 3),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF9A9CA3))),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: color, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
