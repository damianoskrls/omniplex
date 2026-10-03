import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../services/global_auth_service.dart';
import '../services/biometric_auth_service.dart';
import '../config/tenant_config.dart';
import '../theme/brand.dart';
import 'global_profile_details_screen.dart';
import 'gym_entry_splash.dart';
import 'phone_otp_login_screen.dart';
import '../l10n/tr.dart';


const _kBg     = Color(0xFF0A0A0A);
const _kCard   = Color(0xFF16171B);
const _kBorder = Color(0xFF2A2B30);
const _kGray   = Color(0xFF9A9CA3);
const _kLime   = Color(0xFFC6FF3D);

typedef PurchaseComplete = void Function({
  required String message,
  required String businessId,
  required String tabKey,
});

class GymLaunch {
  static String? tabKey;
  static String? message;
}

String _checkoutError(Object raw) {
  final text = raw.toString().replaceFirst('Exception: ', '');
  if (text.toLowerCase().contains('api key')) {
    return tr('Οι online πληρωμές δεν είναι ρυθμισμένες για αυτό το γυμναστήριο.');
  }
  return text;
}

class GymProfileScreen extends StatefulWidget {
  const GymProfileScreen({
    super.key,
    this.gymName = '',
    this.slug,
    this.gymData,
    this.globalAuth,
    this.onLoggedIn,
    this.onEnterGym,
    this.onRequestSent,
    this.onGymAdded,
    this.onPurchaseComplete,
    this.initialTab = 0,
  });

  final String gymName;
  final String? slug;
  final Map<String, dynamic>? gymData;
  final GlobalAuthService? globalAuth;
  final VoidCallback? onLoggedIn;
  final void Function(TenantConfig)? onEnterGym;
  final VoidCallback? onRequestSent;
  final VoidCallback? onGymAdded;
  final PurchaseComplete? onPurchaseComplete;
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
  bool _hasStaffKind(String kind) => widget.globalAuth?.gyms.any(
        (g) => g.slug == _slug && g.isStaff && (g.staffKind ?? 'trainer') == kind,
      ) ?? false;
  bool get _canAskMember => !_memberLinked && !_memberPending;
  bool get _canAskTrainer => !_hasStaffKind('trainer') && !_staffPending;
  bool get _canAskNutritionist => !_hasStaffKind('nutritionist') && !_staffPending;
  bool get _canAskPhysio => !_hasStaffKind('physiotherapist') && !_staffPending;
  bool get _canRequest => widget.globalAuth?.isLoggedIn == true &&
      (_canAskMember || _canAskTrainer || _canAskNutritionist || _canAskPhysio);
  bool get _dropInOn => _gym?['accepts_drop_in'] == true || _dropins.isNotEmpty;
  List<Map<String, dynamic>> get _dropins {
    final raw = _gym?['dropin_services'];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

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

  bool get _showAddGym => !_canEnter && !_memberPending && !_staffPending;

  Future<void> _addToMyGyms() async {
    if (widget.globalAuth == null || !widget.globalAuth!.isLoggedIn) {
      _showLoginPrompt(
        title: tr('Προσθήκη στα γυμναστήριά μου'),
        body: tr('Βάλε το κινητό σου και τον κωδικό OTP. Αν σε έχει ήδη περάσει ο διαχειριστής, το γυμναστήριο μπαίνει αμέσως στη λίστα σου.'),
        skipProfile: true,
        afterLogin: _addToMyGyms,
      );
      return;
    }
    final bizId = _gym?['business_id'] as String?;
    if (bizId == null) return;

    setState(() => _joiningGym = true);
    Map<String, dynamic> claim;
    try {
      claim = await widget.globalAuth!.claimGym(bizId);
    } catch (e) {
      if (mounted) {
        setState(() => _joiningGym = false);
        _showError(e.toString());
      }
      return;
    }
    if (!mounted) return;
    setState(() => _joiningGym = false);
    if (claim['status'] == 'linked') {
      if (!_profileReady() && mounted) await _collectProfile();
      if (!mounted) return;
      widget.onGymAdded?.call();
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }

    if (!await _collectProfile() || !mounted) return;
    await _requestJoin();
  }

  Future<void> _requestJoin() async {
    if (widget.globalAuth == null || !widget.globalAuth!.isLoggedIn) {
      _showLoginPrompt(
        title: tr('Προσθήκη στα γυμναστήριά μου'),
        body: tr('Βάλε το κινητό σου και τον κωδικό OTP. Αν σε έχει ήδη περάσει ο διαχειριστής, το γυμναστήριο μπαίνει αμέσως στη λίστα σου.'),
        skipProfile: true,
        afterLogin: _addToMyGyms,
      );
      return;
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

    final picked = await _showRolePicker();
    if (picked == null || !mounted) return;
    final parts = picked.split(':');
    final role = parts.first;
    final specialty = parts.length > 1
        ? (parts[1] == 'nutritionist'
            ? 'Διατροφολόγος'
            : parts[1] == 'physiotherapist'
                ? 'Φυσιοθεραπευτής'
                : 'Trainer')
        : null;

    final user = widget.globalAuth!.user;
    await _submitJoinRequest(bizId, role, {
      'full_name': user?.fullName,
      'phone': user?.phone,
      if ((user?.email ?? '').isNotEmpty) 'email': user!.email,
      if (locationId != null) 'location_id': locationId,
      if (specialty != null) 'specialty': specialty,
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
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(tr('Σε ποιο κατάστημα;'),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(tr('Η έγκριση και οι κρατήσεις ισχύουν για το κατάστημα που θα διαλέξεις'),
                style: TextStyle(fontSize: 13, color: Color(0xFF9A9CA3))),
            ),
            const SizedBox(height: 16),
            ...locations.map((loc) => _RoleOption(
              icon: Icons.location_on_outlined,
              color: const Color(0xFFC6FF3D),
              title: tr(loc['name'] as String? ?? tr('Κατάστημα')),
              subtitle: tr([
                loc['address'] as String?,
                loc['city'] as String?,
                (loc['accepts_drop_in'] == true || loc['accepts_drop_in'] == 1) ? 'Drop-in' : null,
              ].whereType<String>().where((s) => s.trim().isNotEmpty).join(' · ')),
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
              child: Text(tr('Πώς θα συνδεθείς;'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                tr(_canEnter ? 'Φαίνονται μόνο ρόλοι που δεν έχεις ήδη' : tr('Διάλεξε τον ρόλο για το αίτημα προς τον διαχειριστή')),
                style: const TextStyle(fontSize: 13, color: Color(0xFF9A9CA3))),
            ),
            const SizedBox(height: 20),
            if (_canAskMember)
              _RoleOption(
                icon: Icons.fitness_center_rounded,
                color: const Color(0xFFC6FF3D),
                title: tr('Ασκούμενος'),
                subtitle: tr(_staffLinked
                    ? 'Θέλω να γίνω και πελάτης σε αυτό το γυμναστήριο'
                    : tr('Θέλω να κάνω κρατήσεις ως πελάτης')),
                onTap: () => Navigator.pop(sheetCtx, 'member'),
              ),
            if (_canAskTrainer) ...[
              if (_canAskMember) const SizedBox(height: 10),
              _RoleOption(
                icon: Icons.sports_rounded,
                color: const Color(0xFF3EE6FF),
                title: tr('Trainer'),
                subtitle: tr(_canEnter ? 'Θέλω και ρόλο trainer στο ίδιο γυμναστήριο' : tr('Εργάζομαι ως γυμναστής')),
                onTap: () => Navigator.pop(sheetCtx, 'staff:trainer'),
              ),
            ],
            if (_canAskNutritionist) ...[
              if (_canAskMember || _canAskTrainer) const SizedBox(height: 10),
              _RoleOption(
                icon: Icons.restaurant_menu_rounded,
                color: const Color(0xFF34D399),
                title: tr('Διατροφολόγος'),
                subtitle: tr(_staffLinked
                    ? 'Θέλω να γίνω και διατροφολόγος'
                    : tr('Θέλω πρόσβαση στους πελάτες διατροφής')),
                onTap: () => Navigator.pop(sheetCtx, 'staff:nutritionist'),
              ),
            ],
            if (_canAskPhysio) ...[
              if (_canAskMember || _canAskTrainer || _canAskNutritionist) const SizedBox(height: 10),
              _RoleOption(
                icon: Icons.healing_rounded,
                color: const Color(0xFFF59E0B),
                title: tr('Φυσιοθεραπευτής'),
                subtitle: tr('Ζητάω σύνδεση ως φυσιοθεραπευτής'),
                onTap: () => Navigator.pop(sheetCtx, 'staff:physiotherapist'),
              ),
            ],
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
        if (body['status'] == 'linked') {
          widget.onGymAdded?.call();
        } else {
          widget.onRequestSent?.call();
        }
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        final err = body['message'] ?? body['error'] ?? tr('Σφάλμα');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(err.toString())), backgroundColor: Colors.red.shade700));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(e.toString())), backgroundColor: Colors.red.shade700));
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
    if (widget.globalAuth == null || _gym == null || _enteringGym) return;
    setState(() => _enteringGym = true);
    final nav = Navigator.of(context);
    final name = _gym?['app_name'] as String? ?? _gym?['name'] as String? ?? tr('Γυμναστήριο');
    unawaited(showGymEntrySplash(
      context,
      name: name,
      logoUrl: _gym?['logo_url'] as String?,
    ));
    try {
      final bizId = _gym!['business_id'] as String;
      GlobalGym? staffHere;
      for (final gym in widget.globalAuth!.gyms) {
        if (gym.slug == _slug && gym.isStaff) {
          staffHere = gym;
          break;
        }
      }
      final gymToken = _memberLinked
          ? await widget.globalAuth!.getGymToken(bizId)
          : await widget.globalAuth!.getTrainerToken(bizId, asKind: staffHere?.staffKind);
      await BiometricAuthService.instance.storeSessionToken(bizId, gymToken);
      final api = 'https://passionate-grace-production-98ad.up.railway.app';
      final config = await TenantConfig.openFast(
        businessId: bizId,
        slug: _slug!,
        appName: name,
        apiBaseUrl: api,
        primaryColor: _gym?['primary_color'] as String? ?? '#00b33e',
        logoUrl: _gym?['logo_url'] as String?,
      );
      if (!mounted) return;
      if (widget.onEnterGym != null) {
        widget.onEnterGym!(config);
      } else {
        if (nav.canPop()) nav.pop();
        widget.onLoggedIn?.call();
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      if (nav.canPop()) nav.pop();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(e.toString())), backgroundColor: Colors.red.shade700),
      );
    } finally {
      if (mounted) setState(() => _enteringGym = false);
    }
  }

  bool _profileReady() {
    final name = (widget.globalAuth?.user?.fullName ?? '').trim();
    return name.isNotEmpty && !RegExp(tr(r'^Χρήστης\s+\d+$')).hasMatch(name);
  }

  Future<bool> _collectProfile() async {
    final auth = widget.globalAuth;
    if (auth == null || !auth.isLoggedIn) return false;
    if (_profileReady()) return true;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => GlobalProfileDetailsScreen(
          globalAuth: auth,
          onDone: () => Navigator.of(context).pop(true),
        ),
      ),
    );
    return saved == true && _profileReady();
  }

  Future<String?> _chooseStore(List<Map<String, dynamic>> locations) async {
    if (locations.length > 1) return _showLocationPicker(locations);
    if (locations.length == 1) return locations.first['id'] as String?;
    return null;
  }

  void _finishPurchase(String message, {required String tabKey}) {
    final bizId = _gym?['business_id'] as String? ?? '';
    widget.onPurchaseComplete?.call(
      message: tr(message),
      businessId: bizId,
      tabKey: tabKey,
    );
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _bookDropIn(Map<String, dynamic> offer) async {
    if (widget.globalAuth == null || !widget.globalAuth!.isLoggedIn) {
      _showLoginPrompt(
        title: tr('Σύνδεση για αγορά'),
        body: tr('Βάλε το κινητό σου και τον κωδικό OTP. Μετά συμπληρώνεις όνομα και email, διαλέγεις κατάστημα και πληρώνεις.'),
        afterLogin: () => _bookDropIn(offer),
      );
      return;
    }
    if (!await _collectProfile() || !mounted) return;
    final bizId = _gym?['business_id'] as String?;
    final serviceId = offer['id'] as String?;
    if (bizId == null || serviceId == null) return;

    final locations = ((_gym?['locations'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where((loc) => offer['location_id'] == null || loc['id'] == offer['location_id'])
        .toList();
    var locationId = offer['location_id'] as String?;
    if (locationId == null) {
      final picked = await _chooseStore(locations);
      if (locations.length > 1 && (picked == null || !mounted)) return;
      locationId = picked;
    }

    final booked = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => _DropInBookSheet(
        apiBase: _apiBase,
        bizId: bizId,
        serviceId: serviceId,
        serviceName: offer['name'] as String? ?? 'Drop-in',
        gymName: _gym?['app_name'] as String? ?? _gym?['name'] as String? ?? widget.gymName,
        locationId: locationId,
        priceCents: (offer['drop_in_price_cents'] as num?)?.toInt() ?? 0,
        globalAuth: widget.globalAuth!,
        memberLinked: _memberLinked,
      ),
    );
    if (booked == true && mounted) {
      await widget.globalAuth!.refreshGyms();
      if (!mounted) return;
      _finishPurchase(
        tr('Η κράτηση καταχωρήθηκε. Τη βλέπεις στα Ραντεβού.'),
        tabKey: 'appointments',
      );
    }
  }

  Future<void> _purchasePlan(Map<String, dynamic> plan) async {
    if (widget.globalAuth == null || !widget.globalAuth!.isLoggedIn) {
      _showLoginPrompt(
        title: tr('Σύνδεση για αγορά'),
        body: tr('Βάλε το κινητό σου και τον κωδικό OTP. Μετά συμπληρώνεις όνομα και email, διαλέγεις κατάστημα και πληρώνεις με κάρτα.'),
        afterLogin: () => _purchasePlan(plan),
      );
      return;
    }
    if (!await _collectProfile() || !mounted) return;
    final locations = ((_gym?['locations'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final locationId = await _chooseStore(locations);
    if (locations.length > 1 && (locationId == null || !mounted)) return;
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
          if (locationId != null) 'location_id': locationId,
          'user_info': {
            'full_name': user.fullName,
            'email':     user.email,
            'phone':     user.phone,
          },
        }),
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // close loading

      if (res.statusCode != 200) {
        final err = (jsonDecode(res.body) as Map?)?['error'] ?? tr('Σφάλμα');
        _showError(_checkoutError(err));
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
      if (!mounted) return;

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
          if (locationId != null) 'location_id': locationId,
          'user_info': {'full_name': user.fullName, 'email': user.email, 'phone': user.phone},
        }),
      );

      if (!mounted) return;
      Navigator.of(context).pop();

      if (confirm.statusCode == 200) {
        final confirmBody = jsonDecode(confirm.body);
        if (confirmBody is Map && confirmBody['token'] != null) {
          await widget.globalAuth!.persistFromPurchase(Map<String, dynamic>.from(confirmBody));
        } else {
          await widget.globalAuth!.refreshGyms();
        }
        if (!mounted) return;
        _finishPurchase(
          tr('Το πακέτο «${plan['name']}» είναι ενεργό. Μπορείς να κάνεις κράτηση.'),
          tabKey: 'booking',
        );
      } else {
        final err = (jsonDecode(confirm.body) as Map?)?['error'] ?? tr('Σφάλμα');
        _showError(_checkoutError(err));
      }
    } on StripeException catch (e) {
      if (!mounted) return;
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      if (e.error.code != FailureCode.Canceled) {
        _showError(_checkoutError(e.error.localizedMessage ?? tr('Η πληρωμή απέτυχε')));
      }
    } catch (e) {
      if (!mounted) return;
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      _showError(_checkoutError(e));
    }
  }

  void _showLoginPrompt({
    String title = 'Απαιτείται σύνδεση',
    String body = 'Συνδέσου ή δημιούργησε λογαριασμό για να στείλεις αίτημα εγγραφής.',
    bool skipProfile = false,
    VoidCallback? afterLogin,
  }) {
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
          Text(tr(title),
            style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 8),
          Text(tr(body),
            style: GoogleFonts.inter(fontSize: 14, color: _kGray), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          _limeButton(tr('Σύνδεση / Εγγραφή'), () {
            Navigator.pop(sheetCtx); // close bottom sheet
            navigator.push(MaterialPageRoute(
              builder: (_) => PhoneOtpLoginScreen(
                globalAuth: widget.globalAuth!,
                skipProfile: skipProfile,
                onLoggedIn: () {
                  // Pop OTP/profile/role screens back to this gym profile
                  navigator.popUntil((route) => route == myRoute);
                  if (mounted) Future.microtask(afterLogin ?? _requestJoin);
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
      SnackBar(content: Text(tr(msg)), backgroundColor: Colors.red.shade700));
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
          : Text(tr(name), style: GoogleFonts.inter(
              fontSize: 24, fontWeight: FontWeight.w700,
              color: Colors.white, letterSpacing: -0.6)),
        const SizedBox(height: 6),
        if (rating != null)
          Row(children: [
            const Icon(Icons.star_rounded, color: Colors.white, size: 14),
            const SizedBox(width: 4),
            Text(tr(rating), style: GoogleFonts.inter(
              fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
            if (reviews > 0) ...[
              const SizedBox(width: 6),
              Text(tr('($reviews αξιολογήσεις)'), style: GoogleFonts.inter(
                fontSize: 12, color: _kGray)),
            ],
          ]),
        if (city.isNotEmpty) ...[
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.location_on_outlined, color: _kGray, size: 14),
            const SizedBox(width: 4),
            Text(tr(city), style: GoogleFonts.inter(fontSize: 13, color: _kGray)),
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
        labelStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
        labelColor: _kBg,
        unselectedLabelColor: _kGray,
        tabs: [
          Tab(text: tr('Επισκόπηση')),
          Tab(text: tr('Πρόγραμμα')),
          Tab(text: tr('Πακέτα')),
          Tab(text: tr('Κριτικές')),
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
          _sectionTitle(tr('Σχετικά')),
          const SizedBox(height: 8),
          Text(tr(desc), style: GoogleFonts.inter(fontSize: 14, color: _kGray, height: 1.625)),
          const SizedBox(height: 28),
        ],

        if (services.isNotEmpty) ...[
          _sectionTitle(tr('Υπηρεσίες')),
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
                                Text(tr(s['name'] as String? ?? ''),
                                  style: GoogleFonts.inter(
                                    fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
                                const SizedBox(height: 10),
                                Text(tr(description),
                                  style: GoogleFonts.inter(fontSize: 14, color: _kGray, height: 1.6)),
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
                            Text(tr(s['name'] as String? ?? ''),
                              style: GoogleFonts.inter(
                                fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                            if (description != null && description.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(tr(description),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(fontSize: 12, color: _kGray, height: 1.4)),
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

        _sectionTitle(tr('Ώρες Λειτουργίας')),
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
      _sectionTitle(tr('Επικοινωνία')),
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
                  child: Text(tr(item['label'] as String),
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.white)),
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
    final places = ((_gym?['locations'] as List?) ?? const [])
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .where((row) => row['hours'] is List && (row['hours'] as List).isNotEmpty)
        .toList();
    if (places.isEmpty && _hours.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kBorder),
        ),
        child: Text(tr('Δεν υπάρχουν διαθέσιμα ωράρια'),
          style: GoogleFonts.inter(fontSize: 13, color: _kGray)),
      );
    }
    if (places.isNotEmpty) {
      final multi = places.length > 1;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final place in places) ...[
            if (multi) ...[
              Text(tr(place['name'] as String? ?? tr('Κατάστημα')),
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
              const SizedBox(height: 8),
            ],
            _hoursTable((place['hours'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()),
            const SizedBox(height: 12),
          ],
        ],
      );
    }
    return _hoursTable(_hours);
  }

  Widget _hoursTable(List<Map<String, dynamic>> hours) {
    final today = DateTime.now().weekday - 1;
    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: List.generate(hours.length, (i) {
          final h = hours[i];
          final dow = (h['day_index'] as int?) ?? (h['day_of_week'] as int?) ?? i;
          final isToday = dow == today;
          final closed = h['closed'] == true || h['is_closed'] == true || h['is_closed'] == 1;
          final open = (h['open'] as String?) ?? (h['open_time'] as String?) ?? '';
          final close = (h['close'] as String?) ?? (h['close_time'] as String?) ?? '';
          final dayNames = [tr('Δευ'), tr('Τρί'), tr('Τετ'), tr('Πέμ'), tr('Παρ'), tr('Σαβ'), tr('Κυρ')];
          final label = (h['day'] as String?)?.isNotEmpty == true
              ? h['day'] as String
              : dayNames[dow.clamp(0, 6)];
          final timeStr = closed || open.isEmpty
              ? 'Κλειστό'
              : '${open.length >= 5 ? open.substring(0, 5) : open} – ${close.length >= 5 ? close.substring(0, 5) : close}';
          return Container(
            decoration: BoxDecoration(
              color: isToday ? _kLime.withValues(alpha: 0.08) : Colors.transparent,
              border: i < hours.length - 1
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
                Text(tr(label),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w600,
                    color: isToday ? _kLime : _kGray)),
              ]),
              Text(tr(timeStr),
                style: GoogleFonts.inter(
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
    final dayLabels = ['', tr('Δευ'), tr('Τρί'), tr('Τετ'), tr('Πέμ'), tr('Παρ'), tr('Σάβ'), tr('Κυρ')];

    // initialise to today on first build
    if (_scheduleDay == 0) _scheduleDay = today;

    final filtered = schedule.where((e) => (e['day_of_week'] as int?) == _scheduleDay).toList();

    if (schedule.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.calendar_month_outlined, color: _kGray, size: 48),
        const SizedBox(height: 12),
        Text(tr('Δεν υπάρχει πρόγραμμα'), style: GoogleFonts.inter(
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
                        Text(tr(dayLabels[day]),
                          style: GoogleFonts.inter(
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
            ? Center(child: Text(tr('Δεν υπάρχουν μαθήματα'),
                style: GoogleFonts.inter(fontSize: 13, color: _kGray)))
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
          child: Text(tr(entry['start_time'] as String? ?? ''),
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr(entry['class_name'] as String? ?? ''),
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
            if ((entry['trainer_name'] as String?) != null)
              Text(tr(entry['trainer_name'] as String),
                style: GoogleFonts.inter(fontSize: 12, color: _kGray)),
            if ((entry['equipment'] as String?) != null)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Text(tr(entry['equipment'] as String),
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
              ),
          ]),
        ),
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
        Text(tr('Φόρτωση πακέτων...'), style: GoogleFonts.inter(fontSize: 13, color: _kGray)),
      ]));
    }
    if (_packages.isEmpty && _dropins.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.inventory_2_outlined, color: _kGray, size: 48),
        const SizedBox(height: 12),
        Text(tr('Δεν υπάρχουν διαθέσιμα πακέτα'), style: GoogleFonts.inter(fontSize: 13, color: _kGray)),
      ]));
    }

    // Group by service
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final p in _packages) {
      final svc = p['service_name'] as String? ?? tr('Γενικά');
      grouped.putIfAbsent(svc, () => []).add(p);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
      children: [
        if (_dropins.isNotEmpty) ...[
          Text(tr('Drop-in'), style: GoogleFonts.inter(
            fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 6),
          Text(tr('Μία συνεδρία, χωρίς πακέτο. Ισχύει και αν είσαι ήδη πελάτης, για υπηρεσία που δεν έχεις.'),
            style: GoogleFonts.inter(fontSize: 12, color: _kGray, height: 1.4)),
          const SizedBox(height: 12),
          ..._dropins.map(_buildDropinCard),
          const SizedBox(height: 24),
        ],
        ...grouped.entries.map((e) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr(e.key), style: GoogleFonts.inter(
              fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 12),
            ...e.value.map((p) => _buildPackageCard(p)),
            const SizedBox(height: 24),
          ],
        );
      }),
      ],
    );
  }

  Widget _buildDropinCard(Map<String, dynamic> offer) {
    final cents = (offer['drop_in_price_cents'] as num?)?.toInt() ?? 0;
    final euros = (cents / 100).toStringAsFixed(cents % 100 == 0 ? 0 : 2);
    final name = offer['name'] as String? ?? 'Drop-in';
    final mins = offer['duration_mins'];
    final place = offer['location_name'] as String?;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(tr(name), style: GoogleFonts.inter(
            fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white))),
          Text(tr('€$euros'), style: GoogleFonts.inter(
            fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
        ]),
        const SizedBox(height: 6),
        Text(tr([
          if (mins != null) tr('$mins λεπτά'),
          if (place != null && place.isNotEmpty) place,
          tr('Χωρίς συνδρομή'),
        ].join(' · ')), style: GoogleFonts.inter(fontSize: 12, color: _kGray)),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: () => _bookDropIn(offer),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              gradient: kBrandGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(tr('Αγορά drop-in – €$euros'), style: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ),
      ]),
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
                child: Text(tr(name), style: GoogleFonts.inter(
                  fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
              Text(tr('€$euros'),
                style: GoogleFonts.inter(
                  fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
            ]),

            if (svcName != null && svcName.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(tr(svcName), style: GoogleFonts.inter(fontSize: 12, color: _kGray)),
            ],

            const SizedBox(height: 10),

            // Meta pills
            Wrap(spacing: 8, children: [
              if (sessions != null)
                _metaPill(tr('$sessions ${sessions == 1 ? 'συνεδρία' : 'συνεδρίες'}'),
                  Icons.fitness_center_outlined),
              if (billing != null)
                _metaPill(_billingLabel(billing), Icons.calendar_today_outlined),
            ]),

            const SizedBox(height: 14),

            GestureDetector(
                  onTap: () => _purchasePlan(plan),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      gradient: kBrandGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      tr(_memberLinked ? 'Πάρε και αυτό το πακέτο – €$euros' : tr('Αγορά πακέτου – €$euros')),
                      style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.3)),
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
        Text(tr(label), style: GoogleFonts.inter(fontSize: 11, color: _kGray)),
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
        Text(tr('Δεν υπάρχουν κριτικές ακόμα'),
          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
        const SizedBox(height: 6),
        Text(tr('Γίνε ο πρώτος που θα αξιολογήσει αυτό το γυμναστήριο.'),
          style: GoogleFonts.inter(fontSize: 13, color: _kGray),
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
          _limeButton(tr('Άνοιξε το Γυμναστήριο'), _enteringGym ? null : _enterGym,
              icon: Icons.fitness_center_rounded),
        if (!_canEnter && (_memberPending || _staffPending))
          _pendingJoinBanner(),
        if (_canEnter && (_memberPending || _staffPending)) ...[
          const SizedBox(height: 10),
          _pendingJoinBanner(),
        ],
        if (_dropInOn || (!_canEnter && !_memberPending && !_staffPending))
          Row(children: [
            if (_dropInOn) ...[
              Expanded(
                child: _outlineButton('Drop-in', () => _tabCtrl.animateTo(2)),
              ),
              const SizedBox(width: 12),
            ],
            if (!_canEnter && !_memberPending && !_staffPending)
              Expanded(
                child: _outlineButton(tr('Δες Πακέτα'), () => _tabCtrl.animateTo(2)),
              ),
          ]),
        if (_showAddGym) ...[
          const SizedBox(height: 10),
          _limeButton(
            tr('Προσθήκη στα γυμναστήριά μου'),
            _joiningGym ? null : _addToMyGyms,
            icon: Icons.add_circle_outline,
          ),
        ],
        if (_canEnter && _canRequest) ...[
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
              child: Text(tr('Αίτημα για νέο ρόλο'),
                style: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
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
          child: Text(tr('Το αίτημά σου εκκρεμεί έγκριση από τον διαχειριστή'),
            style: GoogleFonts.inter(
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
          gradient: onTap == null ? null : kBrandGradient,
          color: onTap == null ? Colors.white24 : null,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
          ],
          Text(tr(label), style: GoogleFonts.inter(
            fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.3)),
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
        child: Text(tr(label), style: GoogleFonts.inter(
          fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
      ),
    );
  }

  Widget _sectionTitle(String t) {
    return Text(tr(t), style: GoogleFonts.inter(
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
        tr(name.isNotEmpty ? name[0].toUpperCase() : '?'),
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
      case 'monthly':   return tr('Μηνιαία');
      case 'quarterly': return tr('Τριμηνιαία');
      case 'biannual':  return tr('Εξαμηνιαία');
      case 'annual':    return tr('Ετήσια');
      case 'one_time':  return tr('Εφάπαξ');
      case 'drop_in':   return 'Drop-in';
      default:          return billing;
    }
  }
}

class _DropInBookSheet extends StatefulWidget {
  const _DropInBookSheet({
    required this.apiBase,
    required this.bizId,
    required this.serviceId,
    required this.serviceName,
    required this.gymName,
    required this.locationId,
    required this.priceCents,
    required this.globalAuth,
    required this.memberLinked,
  });

  final String apiBase;
  final String bizId;
  final String serviceId;
  final String serviceName;
  final String gymName;
  final String? locationId;
  final int priceCents;
  final GlobalAuthService globalAuth;
  final bool memberLinked;

  @override
  State<_DropInBookSheet> createState() => _DropInBookSheetState();
}

class _DropInBookSheetState extends State<_DropInBookSheet> {
  DateTime _date = DateTime.now();
  List<Map<String, dynamic>> _slots = [];
  Map<String, dynamic>? _selected;
  bool _loading = true;
  bool _booking = false;
  String? _message;
  bool _sought = false;

  static final _weekdays = [tr('Δευτέρα'), tr('Τρίτη'), tr('Τετάρτη'), tr('Πέμπτη'), tr('Παρασκευή'), tr('Σάββατο'), tr('Κυριακή')];
  static final _months = [tr('Ιαν'), tr('Φεβ'), tr('Μαρ'), tr('Απρ'), tr('Μαΐ'), tr('Ιουν'), tr('Ιουλ'), tr('Αυγ'), tr('Σεπ'), tr('Οκτ'), tr('Νοε'), tr('Δεκ')];

  @override
  void initState() {
    super.initState();
    _load(seek: true);
  }

  String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _slotTime(Map<String, dynamic> slot) {
    final raw = slot['time']?.toString() ?? '';
    return raw.length >= 5 ? raw.substring(0, 5) : raw;
  }

  String _dateLabel(DateTime d) => '${_weekdays[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';

  Future<void> _load({bool seek = false}) async {
    setState(() { _loading = true; _message = null; _slots = []; _selected = null; });
    try {
      final uri = Uri.parse('${widget.apiBase}/booking/${widget.bizId}/slots').replace(
        queryParameters: {
          'service_id': widget.serviceId,
          'date': _ymd(_date),
          'dropin': '1',
          if (widget.locationId != null) 'location_id': widget.locationId!,
        },
      );
      final res = await http.get(uri);
      if (!mounted) return;
      final body = jsonDecode(res.body);
      if (res.statusCode != 200 || body is! Map) {
        setState(() => _message = tr('Δεν φορτώθηκαν οι ώρες'));
        return;
      }
      final raw = body['slots'];
      final slots = raw is List
          ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).where((s) {
              final full = s['is_full'] == true;
              return !full;
            }).toList()
          : <Map<String, dynamic>>[];
      if (seek && !_sought && slots.isEmpty) {
        _sought = true;
        final nextUri = Uri.parse('${widget.apiBase}/booking/${widget.bizId}/next-slot').replace(
          queryParameters: {
            'service_id': widget.serviceId,
            'dropin': '1',
            if (widget.locationId != null) 'location_id': widget.locationId!,
          },
        );
        final nextRes = await http.get(nextUri);
        if (!mounted) return;
        if (nextRes.statusCode == 200) {
          final next = jsonDecode(nextRes.body);
          final nextDate = next is Map ? next['date']?.toString() : null;
          final parsed = nextDate == null ? null : DateTime.tryParse(nextDate);
          if (parsed != null && _ymd(parsed) != _ymd(_date)) {
            setState(() => _date = parsed);
            await _load();
            return;
          }
        }
      }
      setState(() {
        _slots = slots;
        _selected = null;
        _message = null;
      });
    } catch (_) {
      if (mounted) setState(() => _message = tr('Δεν φορτώθηκαν οι ώρες'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirm(Map<String, dynamic> slot) async {
    setState(() { _booking = true; _message = null; });
    try {
      String? gymToken;
      if (widget.memberLinked) {
        gymToken = await widget.globalAuth.getGymToken(widget.bizId);
      }
      final user = widget.globalAuth.user;
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${gymToken ?? widget.globalAuth.token}',
      };
      final time = _slotTime(slot);
      final staff = slot['available_staff'];
      final staffId = staff is List && staff.isNotEmpty ? staff.first['id'] : null;
      String? intentId;
      if (widget.priceCents > 0) {
        final intentRes = await http.post(
          Uri.parse('${widget.apiBase}/booking/${widget.bizId}/dropin/payment-intent'),
          headers: headers,
          body: jsonEncode({
            'service_id': widget.serviceId,
            if (widget.locationId != null) 'location_id': widget.locationId,
            if (gymToken == null) 'guest_name': user?.fullName,
          }),
        ).timeout(const Duration(seconds: 25));
        final intentBody = jsonDecode(intentRes.body);
        if (intentRes.statusCode != 200 || intentBody is! Map) {
          final err = intentBody is Map ? (intentBody['error'] ?? tr('Η πληρωμή με κάρτα δεν είναι διαθέσιμη')) : tr('Η πληρωμή με κάρτα δεν είναι διαθέσιμη');
          throw Exception(_checkoutError(err.toString()));
        }
        final secret = intentBody['client_secret'] as String?;
        final key = intentBody['publishable_key'] as String?;
        intentId = intentBody['intent_id'] as String?;
        if (secret == null || key == null || intentId == null) {
          throw Exception(tr('Η πληρωμή με κάρτα δεν είναι διαθέσιμη'));
        }
        Stripe.publishableKey = key;
        await Stripe.instance.initPaymentSheet(
          paymentSheetParameters: SetupPaymentSheetParameters(
            paymentIntentClientSecret: secret,
            merchantDisplayName: 'OmniPlex',
            style: ThemeMode.dark,
          ),
        );
        await Stripe.instance.presentPaymentSheet();
      }
      final res = await http.post(
        Uri.parse('${widget.apiBase}/booking/${widget.bizId}/dropin/book'),
        headers: headers,
        body: jsonEncode({
          'service_id': widget.serviceId,
          'date': _ymd(_date),
          'time': time,
          'location_id': widget.locationId,
          'staff_id': staffId,
          'payment_method': intentId != null ? 'card' : 'venue',
          if (intentId != null) 'payment_intent_id': intentId,
          if (gymToken == null) 'guest_name': user?.fullName,
          if (gymToken == null) 'guest_email': user?.email,
          if (gymToken == null) 'guest_phone': user?.phone,
        }),
      ).timeout(const Duration(seconds: 25));
      if (!mounted) return;
      if (res.statusCode == 200 || res.statusCode == 201) {
        Navigator.pop(context, true);
        return;
      }
      final body = jsonDecode(res.body);
      final err = body is Map ? (body['error'] ?? tr('Η κράτηση απέτυχε')) : tr('Η κράτηση απέτυχε');
      setState(() => _message = _checkoutError(err.toString()));
    } on StripeException catch (e) {
      if (!mounted || e.error.code == FailureCode.Canceled) return;
      setState(() => _message = e.error.localizedMessage ?? tr('Η πληρωμή ακυρώθηκε'));
    } catch (e) {
      if (!mounted) return;
      setState(() => _message = _checkoutError(e.toString().replaceFirst('Exception: ', '')));
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final euros = (widget.priceCents / 100).toStringAsFixed(widget.priceCents % 100 == 0 ? 0 : 2);
    final days = List.generate(14, (i) => DateTime.now().add(Duration(days: i)));
    final selectedTime = _selected == null ? null : _slotTime(_selected!);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.86),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF16171B),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF2A2B30)),
      ),
      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 36, height: 4,
          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 14),
        Text(tr(widget.serviceName), style: GoogleFonts.inter(
          fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
        Text(tr('€$euros · πληρωμή με κάρτα'), style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF9A9CA3))),
        const SizedBox(height: 12),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: days.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final day = days[i];
              final on = day.year == _date.year && day.month == _date.month && day.day == _date.day;
              return GestureDetector(
                onTap: _booking ? null : () { setState(() => _date = day); _load(); },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: on ? kBrandGradient : null,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: on ? Colors.transparent : const Color(0xFF2A2B30)),
                  ),
                  child: Text(tr('${day.day}/${day.month}'), style: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator(color: Colors.white)),
          )
        else if (_slots.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(tr('Δεν υπάρχουν ώρες αυτή την ημέρα'),
              style: GoogleFonts.inter(color: const Color(0xFF9A9CA3))),
          )
        else
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final slot in _slots)
              GestureDetector(
                onTap: _booking ? null : () => setState(() { _selected = slot; _message = null; }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: _slotTime(slot) == selectedTime ? kBrandGradient : null,
                    color: _slotTime(slot) == selectedTime ? null : const Color(0xFF0A0A0A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _slotTime(slot) == selectedTime
                        ? Colors.transparent
                        : const Color(0xFF2A2B30)),
                  ),
                  child: Text(tr(_slotTime(slot)),
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
          ]),
        if (_selected != null) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0A0A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF2A2B30)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('Σύνοψη'), style: GoogleFonts.inter(
                fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF9A9CA3))),
              const SizedBox(height: 8),
              Text(tr('Drop-in · ${widget.serviceName}'), style: GoogleFonts.inter(
                fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
              const SizedBox(height: 4),
              Text(tr(widget.gymName), style: GoogleFonts.inter(fontSize: 14, color: Colors.white)),
              const SizedBox(height: 4),
              Text(tr('${_dateLabel(_date)} · $selectedTime'), style: GoogleFonts.inter(
                fontSize: 14, color: const Color(0xFF9A9CA3))),
              const SizedBox(height: 4),
              Text(tr('€$euros'), style: GoogleFonts.inter(
                fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
            ]),
          ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(tr(_message!), style: GoogleFonts.inter(color: const Color(0xFFF87171), height: 1.35)),
            ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _booking ? null : () => _confirm(_selected!),
            child: Container(
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: _booking ? null : kBrandGradient,
                color: _booking ? Colors.white24 : null,
                borderRadius: BorderRadius.circular(14),
              ),
              child: _booking
                ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                    SizedBox(width: 10),
                    Text(tr('Ολοκλήρωση πληρωμής…'), style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ])
                : Text(tr('Πληρωμή €$euros'), style: GoogleFonts.inter(
                    fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
          ),
        ],
      ])),
    );
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
                    Text(tr(title), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(height: 3),
                    Text(tr(subtitle), style: const TextStyle(fontSize: 12, color: Color(0xFF9A9CA3))),
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
