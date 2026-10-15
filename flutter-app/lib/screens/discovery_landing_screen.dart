import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../services/global_auth_service.dart';
import '../config/tenant_config.dart';
import 'global_register_screen.dart';
import 'phone_otp_login_screen.dart';
import 'gym_profile_screen.dart';
import 'gyms_map_screen.dart';
import '../l10n/tr.dart';


const _kBg      = Color(0xFF090A0F);
const _kCard    = Color(0xFF14161F);
const _kBorder  = Color(0xFF2B2E3D);
const _kText    = Color(0xFFF5F5FA);
const _kGray    = Color(0xFFA7ABBE);
const _kAccent  = Color(0xFF9A9DFF);
const _kPrimary = Color(0xFF565CE4);
const _kGuideBg = Color(0xFF242642);
const _kNavCard = Color(0xFF1C1F2B);
const _kGold    = Color(0xFFF0CC85);
const _kGreen   = Color(0xFF8DE2BB);
const _kGreenBg = Color(0xFF17332B);

class DiscoveryLandingScreen extends StatefulWidget {
  const DiscoveryLandingScreen({
    super.key,
    required this.globalAuth,
    required this.onLoggedIn,
    this.onEnterGym,
    this.onRequestSent,
    this.onGymAdded,
    this.onPurchaseComplete,
    this.hideHeader = false,
  });

  final GlobalAuthService globalAuth;
  final VoidCallback onLoggedIn;
  final void Function(TenantConfig)? onEnterGym;
  final VoidCallback? onRequestSent;
  final VoidCallback? onGymAdded;
  final PurchaseComplete? onPurchaseComplete;
  final bool hideHeader;

  @override
  State<DiscoveryLandingScreen> createState() => _DiscoveryLandingScreenState();
}

class _DiscoveryLandingScreenState extends State<DiscoveryLandingScreen> {
  static const _apiBase = 'https://passionate-grace-production-98ad.up.railway.app/api';

  final _searchCtrl  = TextEditingController();
  final _searchFocus = FocusNode();

  String _activeCategory = '';
  List<Map<String, dynamic>> _results  = [];
  List<Map<String, dynamic>> _featured = [];
  bool _searching     = false;
  bool _searched      = false;
  bool _searchFocused = false;
  Timer? _debounce;

  double? _userLat;
  double? _userLng;

  // Quick filter chips (search mode)
  final Set<String> _quickFilters = {};

  // Advanced filters
  Set<String> _filterProgramTypes = {};
  double _filterMaxDistanceKm = 50.0;
  Set<String> _filterAmenities = {};
  bool _filterOpenNow = false;

  // Static recent searches
  final _recentSearches = ['CrossFit Athens', 'Yoga near me', '24h fitness clubs'];

  static final _kProgramTypes = [
    'CrossFit', 'Yoga', 'Pilates', 'Functional', 'HIIT', 'Boxing',
    tr('Κολύμβηση'), 'Personal Training', tr('Δύναμη'), 'Cardio',
  ];
  static const _kAmenityIcons = {
    'Parking': '🅿', 'Showers': '🚿', 'Locker rooms': '🔒',
    'Pool': '🏊', 'Cafe': '☕', 'Towel service': '👕',
  };
  static final _kQuickChips = [
    'CrossFit', 'Yoga', 'Pilates', 'Functional', 'HIIT', 'Boxing', tr('Κοντά μου'),
  ];

  // (label, apiKey, iconAsset, _unused)
  static final _categories = [
    ('Όλα',       '',         'assets/icons/discovery_more.svg',     _kBorder),
    ('Δύναμη',    'Strength', 'assets/icons/discovery_more.svg',     _kBorder),
    ('Pilates',   'Pilates',  'assets/icons/discovery_pilates.svg',  _kBorder),
    ('Yoga',      'Yoga',     'assets/icons/discovery_yoga.svg',     _kBorder),
    ('CrossFit',  'CrossFit', 'assets/icons/discovery_crossfit.svg', _kBorder),
  ];

  static final _popularSearches = [
    'CrossFit', 'Yoga', 'Pilates', 'Boxing', 'Personal Training', tr('24ωρα γυμναστήρια'),
  ];

  static final _activities = [
    ('CrossFit',          'assets/icons/discovery_act_crossfit.svg',  Color(0xFF2A1E14), Color(0xFFC06A1E)),
    ('Yoga',              'assets/icons/discovery_act_yoga.svg',       Color(0xFF141A2A), Color(0xFF3EE6FF)),
    ('Pilates',           'assets/icons/discovery_act_pilates.svg',    Color(0xFF14261C), Color(0xFF4ADE80)),
    (tr('Δύναμη'),            'assets/icons/discovery_act_strength.svg',   Color(0xFF1A1420), Color(0xFFA78BFA)),
    ('Boxing',            'assets/icons/discovery_act_boxing.svg',     Color(0xFF2A1414), Color(0xFFF87171)),
    (tr('Κολύμβηση'),         'assets/icons/discovery_act_swimming.svg',   Color(0xFF14202A), Color(0xFF38BDF8)),
    ('Personal Training', 'assets/icons/discovery_act_pt.svg',         Color(0xFF261E14), Color(0xFFFBBF24)),
  ];

  @override
  void initState() {
    super.initState();
    _loadFeatured();
    _initLocation();
    _searchFocus.addListener(_onFocusChanged);
  }

  Future<void> _initLocation() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.whileInUse || perm == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
        ).timeout(const Duration(seconds: 4));
        if (!mounted) return;
        setState(() { _userLat = pos.latitude; _userLng = pos.longitude; });
        _loadFeatured();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _searchFocus.removeListener(_onFocusChanged);
    _searchFocus.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    // Only activate search mode on focus gain — never deactivate from focus loss
    // (bottom sheets / pickers steal focus temporarily and must not reset state)
    if (_searchFocus.hasFocus && mounted) {
      setState(() => _searchFocused = true);
    }
  }

  Future<void> _loadFeatured() async {
    try {
      final params = <String, String>{};
      if (_userLat != null && _userLng != null) {
        params['lat'] = _userLat!.toString();
        params['lng'] = _userLng!.toString();
      }
      final uri = Uri.parse('$_apiBase/global/discovery/gyms').replace(queryParameters: params.isEmpty ? null : params);
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200 && mounted) {
        setState(() {
          _featured = (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
        });
      }
    } catch (_) {}
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    if (v.trim().isEmpty && _activeCategory.isEmpty) {
      if (_searched) setState(() { _results = []; _searched = false; });
      return;
    }
    if (v.trim().length >= 2) {
      _debounce = Timer(const Duration(milliseconds: 500), _search);
    }
  }

  Future<void> _search() async {
    final q = _searchCtrl.text.trim();
    final allPrograms = {
      ...(_activeCategory.isNotEmpty ? {_activeCategory} : <String>{}),
      ..._filterProgramTypes,
      ..._quickFilters.where((c) => c != 'Κοντά μου'),
    };
    if (q.isEmpty && allPrograms.isEmpty && !_hasActiveFilters &&
        !_quickFilters.contains(tr('Κοντά μου'))) return;
    setState(() { _searching = true; _searched = true; });
    try {
      final params = <String, String>{};
      if (q.isNotEmpty) params['q'] = q;
      if (allPrograms.isNotEmpty) params['service'] = allPrograms.join(',');
      if (_userLat != null && _userLng != null) {
        params['lat'] = _userLat!.toString();
        params['lng'] = _userLng!.toString();
      }
      if (_filterMaxDistanceKm < 50) {
        params['max_distance'] = _filterMaxDistanceKm.toStringAsFixed(0);
      }
      if (_quickFilters.contains(tr('Κοντά μου'))) params['max_distance'] = '5';
      if (_filterOpenNow) params['open_now'] = 'true';
      if (_filterAmenities.isNotEmpty) params['amenities'] = _filterAmenities.join(',');
      final uri = Uri.parse('$_apiBase/global/discovery/gyms').replace(queryParameters: params);
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200 && mounted) {
        setState(() => _results = (jsonDecode(res.body) as List).cast<Map<String, dynamic>>());
      }
    } catch (_) {}
    if (mounted) setState(() => _searching = false);
  }

  void _selectCategory(String key) {
    setState(() {
      _activeCategory = _activeCategory == key ? '' : key;
    });
    if (_activeCategory.isEmpty && _searchCtrl.text.trim().length < 2) {
      setState(() { _results = []; _searched = false; });
    } else {
      _search();
    }
  }

  void _openGym(Map<String, dynamic> gym) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => GymProfileScreen(
        slug: gym['slug'] as String,
        locationId: gym['location_id'] as String?,
        globalAuth: widget.globalAuth,
        onLoggedIn: widget.onLoggedIn,
        onEnterGym: widget.onEnterGym,
        onRequestSent: widget.onRequestSent,
        onGymAdded: widget.onGymAdded,
        onPurchaseComplete: widget.onPurchaseComplete,
      ),
    ));
  }

  void _goLogin() {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => PhoneOtpLoginScreen(
        globalAuth: widget.globalAuth,
        onLoggedIn: widget.onLoggedIn,
      ),
    ));
  }

  void _goRegister() {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => GlobalRegisterScreen(
        globalAuth: widget.globalAuth,
        onRegistered: widget.onLoggedIn,
      ),
    ));
  }

  bool get _hasActiveFilters =>
    _filterProgramTypes.isNotEmpty || _filterMaxDistanceKm < 50 ||
    _filterAmenities.isNotEmpty || _filterOpenNow;

  void _exitSearch() {
    _searchFocus.unfocus();
    _searchCtrl.clear();
    setState(() {
      _searched       = false;
      _searchFocused  = false;
      _results        = [];
      _activeCategory = '';
      _quickFilters.clear();
    });
  }

  Color _parseColor(String? hex) {
    if (hex == null) return _kAccent;
    try { return Color(int.parse(hex.replaceFirst('#', '0xFF'))); }
    catch (_) { return _kAccent; }
  }

  // ─────────── build ───────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: (_searchFocused || _searched)
          ? _buildSearchModeContent()
          : _buildHomeContent(),
      ),
    );
  }

  // ─────────── HOME STATE (11:320) ───────────

  Widget _buildHomeContent() {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!widget.hideHeader) ...[
                  _buildHeader(),
                  const SizedBox(height: 32),
                ],
                _buildHeroText(),
                const SizedBox(height: 24),
                _buildSearchBarHome(),
                const SizedBox(height: 24),
                _buildCategoryChips(),
                const SizedBox(height: 36),
                _buildHomeSectionHeader(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        if (_featured.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.location_off_outlined, color: _kGray, size: 40),
                  const SizedBox(height: 12),
                  Text(tr('Δεν βρέθηκαν γυμναστήρια κοντά σου'),
                    style: GoogleFonts.inter(color: _kGray, fontSize: 14)),
                  const SizedBox(height: 6),
                  Text(tr('Αναζήτησε με όνομα χώρου ή περιοχή'),
                    style: GoogleFonts.inter(color: _kGray.withValues(alpha: 0.6), fontSize: 12)),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: _buildGymCard(_featured[i], showLogoBadge: true),
                ),
                childCount: _featured.length,
              ),
            ),
          ),
        if (!widget.globalAuth.isLoggedIn)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            sliver: SliverToBoxAdapter(
              child: GestureDetector(
                onTap: _goLogin,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _kGuideBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _kAccent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.person_outline_rounded, color: _kAccent, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          tr('Εξερευνάς ως επισκέπτης. Συνδέσου για να προσθέσεις γυμναστήριο, αγοράσεις πλάνο ή κάνεις κράτηση.'),
                          style: GoogleFonts.inter(color: _kGray, fontSize: 12, height: 1.45),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(children: [
          const Icon(Icons.location_on_rounded, color: _kAccent, size: 16),
          const SizedBox(width: 4),
          Text(
            _userLat != null ? tr('Κοντά σου') : tr('Αθήνα'),
            style: GoogleFonts.inter(
              fontSize: 14, fontWeight: FontWeight.w600,
              color: _kText, letterSpacing: -0.2)),
        ]),
        GestureDetector(
          onTap: widget.globalAuth.isLoggedIn ? widget.onLoggedIn : _goLogin,
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: widget.globalAuth.isLoggedIn ? _kGuideBg : _kPrimary,
              borderRadius: BorderRadius.circular(9999),
              border: widget.globalAuth.isLoggedIn
                ? Border.all(color: _kAccent.withValues(alpha: 0.4))
                : null,
            ),
            alignment: Alignment.center,
            child: Text(
              tr(widget.globalAuth.isLoggedIn
                ? (widget.globalAuth.user?.fullName.split(' ').first ?? tr('Προφίλ'))
                : tr('Σύνδεση')),
              style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: _kText)),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _kGuideBg,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(tr('Το fitness σου, στα μέτρα σου'),
            style: GoogleFonts.inter(
              fontSize: 10, fontWeight: FontWeight.w700,
              color: _kAccent, letterSpacing: 0.8)),
        ),
        const SizedBox(height: 12),
        Text(tr('Βρες τον ρυθμό σου.\nΚλείσε τον χώρο σου.'),
          style: GoogleFonts.inter(
            fontSize: 34, fontWeight: FontWeight.w800,
            color: _kText, letterSpacing: -0.8, height: 1.08)),
        const SizedBox(height: 10),
        Text(tr('Εξερεύνησε κορυφαία γυμναστήρια και ευέλικτα μαθήματα στην περιοχή σου.'),
          style: GoogleFonts.inter(
            fontSize: 14, color: _kGray, height: 1.55)),
      ],
    );
  }

  Widget _buildSearchBarHome() {
    return Row(children: [
      Expanded(
        child: GestureDetector(
          onTap: () {
            setState(() => _searchFocused = true);
            _searchFocus.requestFocus();
          },
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kBorder),
            ),
            child: Row(children: [
              const SizedBox(width: 16),
              const Icon(Icons.search_rounded, color: _kGray, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(tr('Δοκίμασε "Pilates", "Yoga" ή το αγαπημένο σου γυμναστήριο...'),
                  style: GoogleFonts.inter(fontSize: 14, color: _kGray)),
              ),
              const SizedBox(width: 16),
            ]),
          ),
        ),
      ),
      const SizedBox(width: 10),
      GestureDetector(
        onTap: _showFilterSheet,
        child: Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            color: _hasActiveFilters ? _kGuideBg : _kCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _hasActiveFilters ? _kAccent : _kBorder),
          ),
          alignment: Alignment.center,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.tune_rounded, color: _kText, size: 20),
              if (_hasActiveFilters)
                Positioned(
                  top: -3, right: -3,
                  child: Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(color: _kAccent, shape: BoxShape.circle),
                  ),
                ),
            ],
          ),
        ),
      ),
    ]);
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final cat    = _categories[i];
          final active = _activeCategory == cat.$2;
          return GestureDetector(
            onTap: () => _selectCategory(cat.$2),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: active ? _kGuideBg : _kCard,
                borderRadius: BorderRadius.circular(9999),
                border: Border.all(color: active ? _kAccent : _kBorder),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                SvgPicture.asset(cat.$3, width: 13, height: 13,
                  colorFilter: ColorFilter.mode(
                    active ? _kAccent : _kGray, BlendMode.srcIn)),
                const SizedBox(width: 6),
                Text(tr(cat.$1),
                  style: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: active ? _kAccent : _kGray)),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHomeSectionHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('Κοντά σου'),
              style: GoogleFonts.inter(
                fontSize: 18, fontWeight: FontWeight.w700,
                color: _kText, letterSpacing: -0.45)),
            if (_featured.isNotEmpty)
              Text(tr('${_featured.length} γυμναστήρια · Κατά σύσταση'),
                style: GoogleFonts.inter(fontSize: 11, color: _kGray)),
          ],
        ),
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => GymsMapScreen(
              gyms: _featured,
              userLat: _userLat,
              userLng: _userLng,
              onOpenGym: _openGym,
            )),
          ),
          child: Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _kBorder),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.map_outlined, size: 13, color: _kAccent),
              const SizedBox(width: 4),
              Text(tr('Χάρτης'), style: GoogleFonts.inter(fontSize: 12, color: _kAccent, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ],
    );
  }

  // ─────────── SEARCH MODE (unified: focused + results) ───────────

  Widget _buildSearchModeContent() {
    final hasInput = _searchCtrl.text.trim().isNotEmpty || _quickFilters.isNotEmpty || _hasActiveFilters;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top bar
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: _buildSearchModeTopBar(),
        ),
        // Quick filter chips
        const SizedBox(height: 12),
        _buildQuickFilterChips(),
        // Active advanced filter chips
        if (_hasActiveFilters) ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildActiveFiltersRow(),
          ),
        ],
        const SizedBox(height: 4),
        // Results or suggestions
        Expanded(
          child: hasInput
            ? _buildSearchResultsBody()
            : _buildSearchSuggestions(),
        ),
      ],
    );
  }

  Widget _buildSearchModeTopBar() {
    return Row(children: [
      GestureDetector(
        onTap: _exitSearch,
        child: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: _kCard,
            shape: BoxShape.circle,
            border: Border.all(color: _kBorder),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.arrow_back, color: _kText, size: 18),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kBorder),
          ),
          child: Row(children: [
            const SizedBox(width: 14),
            const Icon(Icons.search_rounded, color: _kGray, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                focusNode: _searchFocus,
                autofocus: true,
                style: GoogleFonts.inter(fontSize: 14, color: _kText),
                cursorColor: _kAccent,
                decoration: InputDecoration(
                  hintText: tr('Δοκίμασε "Pilates", "Yoga" ή το αγαπημένο σου γυμναστήριο...'),
                  hintStyle: GoogleFonts.inter(fontSize: 14, color: _kGray),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: _onSearchChanged,
                onSubmitted: (_) => _search(),
              ),
            ),
            if (_searchCtrl.text.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _searchCtrl.clear();
                  setState(() { _results = []; _searched = false; });
                },
                child: const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Icon(Icons.close_rounded, color: _kGray, size: 16),
                ),
              )
            else
              const SizedBox(width: 12),
          ]),
        ),
      ),
      const SizedBox(width: 10),
      GestureDetector(
        onTap: _showFilterSheet,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: _hasActiveFilters ? _kGuideBg : _kCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _hasActiveFilters ? _kAccent : _kBorder),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.tune_rounded, color: _kText, size: 18),
            ),
            if (_hasActiveFilters)
              Positioned(
                top: -3, right: -3,
                child: Container(
                  width: 9, height: 9,
                  decoration: const BoxDecoration(color: _kAccent, shape: BoxShape.circle),
                ),
              ),
          ],
        ),
      ),
    ]);
  }

  Widget _buildQuickFilterChips() {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _kQuickChips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final chip = _kQuickChips[i];
          final active = _quickFilters.contains(chip);
          final isNearby = chip == 'Κοντά μου';
          return GestureDetector(
            onTap: () {
              setState(() {
                if (active) _quickFilters.remove(chip);
                else        _quickFilters.add(chip);
              });
              if (_quickFilters.isEmpty && _searchCtrl.text.trim().length < 2 && !_hasActiveFilters) {
                setState(() { _results = []; _searched = false; });
              } else {
                _search();
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: active ? _kGuideBg : _kCard,
                borderRadius: BorderRadius.circular(9999),
                border: Border.all(color: active ? _kAccent : _kBorder),
              ),
              alignment: Alignment.center,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (isNearby) ...[
                  Icon(Icons.near_me_rounded, size: 12,
                    color: active ? _kAccent : _kGray),
                  const SizedBox(width: 6),
                ],
                Text(tr(chip),
                  style: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: active ? _kAccent : _kText)),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchResultsBody() {
    if (_searching) {
      return const Center(child: CircularProgressIndicator(color: _kAccent));
    }
    if (_searched && _results.isEmpty) {
      return _buildEmptyState();
    }
    final gyms = _results.isNotEmpty ? _results : _featured;
    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          sliver: SliverToBoxAdapter(
            child: _buildResultsCountHeader(gyms.length),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildGymCard(gyms[i], showLogoBadge: false),
              ),
              childCount: gyms.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultsCountHeader(int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          tr(_searched ? '$count γυμναστήρια βρέθηκαν' : tr('Κοντά σου')),
          style: GoogleFonts.inter(
            fontSize: 13, fontWeight: FontWeight.w600, color: _kGray)),
        if (_hasActiveFilters || _quickFilters.isNotEmpty)
          GestureDetector(
            onTap: () {
              setState(() {
                _quickFilters.clear();
                _filterProgramTypes = {};
                _filterMaxDistanceKm = 50;
                _filterAmenities = {};
                _filterOpenNow = false;
              });
              if (_searchCtrl.text.trim().isNotEmpty) _search();
              else setState(() { _results = []; _searched = false; });
            },
            child: Text(tr('Καθαρισμός'),
              style: GoogleFonts.inter(fontSize: 12, color: _kAccent,
                decoration: TextDecoration.underline, decorationColor: _kAccent)),
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: _kCard,
                shape: BoxShape.circle,
                border: Border.all(color: _kBorder),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.search_rounded, size: 40, color: _kGray),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            tr('Ας διευρύνουμε την αναζήτησή σου.'),
            style: GoogleFonts.inter(
              fontSize: 26, fontWeight: FontWeight.w800,
              color: _kText, height: 1.15, letterSpacing: -0.5),
          ),
          const SizedBox(height: 10),
          Text(
            tr('Δεν βρέθηκαν γυμναστήρια με αυτά τα φίλτρα. Δοκίμασε μεγαλύτερη ακτίνα ή λιγότερα φίλτρα.'),
            style: GoogleFonts.inter(color: _kGray, fontSize: 14, height: 1.55),
          ),
          const SizedBox(height: 28),
          if (_hasActiveFilters || _quickFilters.isNotEmpty) ...[
            GestureDetector(
              onTap: () {
                setState(() {
                  _filterProgramTypes = {};
                  _filterMaxDistanceKm = 50;
                  _filterAmenities = {};
                  _filterOpenNow = false;
                  _quickFilters.clear();
                });
                _search();
              },
              child: Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  color: _kPrimary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(tr('Επαναφορά φίλτρων'),
                      style: GoogleFonts.inter(
                        fontSize: 14, fontWeight: FontWeight.w600, color: _kText)),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward, color: _kText, size: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          GestureDetector(
            onTap: _exitSearch,
            child: Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFF1C1F2B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(tr('Αλλαγή αναζήτησης'),
                    style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w600, color: _kText)),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward, color: _kText, size: 16),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kBorder),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: _kGray, size: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tr('Τα φίλτρα σου δεν έδωσαν αποτελέσματα. Η ανακάλυψη γυμναστηρίων λειτουργεί κανονικά — δεν είναι σφάλμα σύνδεσης.'),
                    style: GoogleFonts.inter(color: _kGray, fontSize: 12, height: 1.45),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSuggestions() {
    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRecentSearches(),
                const SizedBox(height: 24),
                _buildPopularSearches(),
              ],
            ),
          ),
        ),
      ],
    );
  }



  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _kCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _GymFilterSheet(
        initialProgramTypes: _filterProgramTypes,
        initialMaxDistance: _filterMaxDistanceKm,
        initialAmenities: _filterAmenities,
        initialOpenNow: _filterOpenNow,
        currentResultCount: _results.length,
        onApply: (programs, dist, amenities, openNow) {
          setState(() {
            _filterProgramTypes   = programs;
            _filterMaxDistanceKm  = dist;
            _filterAmenities      = amenities;
            _filterOpenNow        = openNow;
          });
          _search();
        },
        onClearAll: () {
          setState(() {
            _filterProgramTypes  = {};
            _filterMaxDistanceKm = 50.0;
            _filterAmenities     = {};
            _filterOpenNow       = false;
          });
          if (_searchCtrl.text.trim().isNotEmpty || _quickFilters.isNotEmpty || _activeCategory.isNotEmpty) {
            _search();
          } else {
            setState(() { _results = []; _searched = false; });
          }
        },
      ),
    );
  }


  Widget _buildRecentSearches() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(tr('Πρόσφατες αναζητήσεις'),
              style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w700,
                color: Colors.white)),
            GestureDetector(
              onTap: () {},
              child: Text(tr('Διαγραφή'),
                style: GoogleFonts.inter(
                  fontSize: 12, color: _kGray)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._recentSearches.map((q) => _recentSearchRow(q)),
      ],
    );
  }

  Widget _recentSearchRow(String query) {
    return GestureDetector(
      onTap: () {
        _searchCtrl.text = query;
        _search();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          SvgPicture.asset('assets/icons/discovery_clock.svg',
            width: 16, height: 16,
            colorFilter: const ColorFilter.mode(_kGray, BlendMode.srcIn)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(tr(query),
              style: GoogleFonts.inter(
                fontSize: 13, color: Colors.white)),
          ),
          SvgPicture.asset('assets/icons/discovery_x.svg',
            width: 12, height: 12,
            colorFilter: const ColorFilter.mode(_kGray, BlendMode.srcIn)),
        ]),
      ),
    );
  }

  Widget _buildPopularSearches() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr('Δημοφιλείς κατηγορίες'),
          style: GoogleFonts.inter(
            fontSize: 13, fontWeight: FontWeight.w700,
            color: Colors.white)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _popularSearches.map((tag) => GestureDetector(
            onTap: () {
              _searchCtrl.text = tag;
              _search();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(9999),
                border: Border.all(color: _kBorder),
              ),
              child: Text(tr(tag),
                style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w500,
                  color: Colors.white)),
            ),
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildNearbyGymsSection() {
    if (_featured.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr('Nearby Gyms'),
          style: GoogleFonts.inter(
            fontSize: 14, fontWeight: FontWeight.w700,
            color: Colors.white)),
        const SizedBox(height: 12),
        SizedBox(
          height: 148,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _featured.take(3).length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _nearbyGymTile(_featured[i]),
          ),
        ),
      ],
    );
  }

  Widget _nearbyGymTile(Map<String, dynamic> gym) {
    final name     = gym['app_name'] as String? ?? gym['name'] as String? ?? '';
    final coverUrl = _mediaUrl(gym['cover_url'] as String? ?? gym['cover_image_url'] as String?);
    final rating   = (gym['rating'] as num?)?.toStringAsFixed(1);
    final color    = _parseColor(gym['primary_color'] as String?);
    return GestureDetector(
      onTap: () => _openGym(gym),
      child: Container(
        width: 128,
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: coverUrl != null
                ? Image.network(coverUrl, fit: BoxFit.cover, width: double.infinity,
                    errorBuilder: (_, __, ___) => _gymPlaceholder(color, name))
                : _gymPlaceholder(color, name),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr(name), maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: Colors.white)),
                  if (rating != null) ...[
                    const SizedBox(height: 2),
                    Row(children: [
                      SvgPicture.asset('assets/icons/discovery_star.svg',
                        width: 9, height: 9),
                      const SizedBox(width: 3),
                      Text(tr(rating),
                        style: GoogleFonts.inter(
                          fontSize: 10, fontWeight: FontWeight.w600,
                          color: Colors.white)),
                    ]),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPopularActivitiesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr('Popular Activities'),
          style: GoogleFonts.inter(
            fontSize: 14, fontWeight: FontWeight.w700,
            color: Colors.white)),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 3.0,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: _activities.length,
          itemBuilder: (_, i) {
            final act = _activities[i];
            return GestureDetector(
              onTap: () {
                _searchCtrl.text = act.$1;
                _search();
              },
              child: Container(
                decoration: BoxDecoration(
                  color: _kCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kBorder),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: act.$3,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: SvgPicture.asset(act.$2,
                      width: 14, height: 14,
                      colorFilter: ColorFilter.mode(act.$4, BlendMode.srcIn)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(tr(act.$1), maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        color: Colors.white)),
                  ),
                ]),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActiveFiltersRow() {
    final chips = <Widget>[];
    for (final t in _filterProgramTypes) {
      chips.add(_activeFilterChip(
        label: tr(t),
        onRemove: () { setState(() => _filterProgramTypes.remove(t)); _search(); },
      ));
    }
    if (_filterMaxDistanceKm < 50) {
      chips.add(_activeFilterChip(
        label: tr('Έως ${_filterMaxDistanceKm.toInt()} km'),
        onRemove: () { setState(() => _filterMaxDistanceKm = 50); _search(); },
      ));
    }
    for (final a in _filterAmenities) {
      final icon = _kAmenityIcons[a] ?? '';
      chips.add(_activeFilterChip(
        label: tr('$icon $a'),
        onRemove: () { setState(() => _filterAmenities.remove(a)); _search(); },
      ));
    }
    if (_filterOpenNow) {
      chips.add(_activeFilterChip(
        label: tr('🟢 Ανοιχτό τώρα'),
        onRemove: () { setState(() => _filterOpenNow = false); _search(); },
      ));
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: chips
          .expand((c) => [c, const SizedBox(width: 8)])
          .toList()
          ..removeLast(),
      ),
    );
  }

  Widget _activeFilterChip({required String label, required VoidCallback onRemove}) {
    return GestureDetector(
      onTap: onRemove,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: _kGuideBg,
          borderRadius: BorderRadius.circular(9999),
          border: Border.all(color: _kAccent),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(tr(label),
            style: GoogleFonts.inter(
              fontSize: 12, fontWeight: FontWeight.w600, color: _kAccent)),
          const SizedBox(width: 6),
          const Icon(Icons.close_rounded, size: 12, color: _kAccent),
        ]),
      ),
    );
  }

  // ─────────── GYM CARD (shared, two modes) ───────────

  Widget _buildGymCard(Map<String, dynamic> gym, {required bool showLogoBadge}) {
    final name      = gym['app_name'] as String? ?? gym['name'] as String? ?? '';
    final coverUrl  = _mediaUrl(gym['cover_url'] as String? ?? gym['cover_image_url'] as String?);
    final city      = gym['city'] as String? ?? '';
    final area      = gym['area'] as String? ?? '';
    final distKm    = (gym['distance_km'] as num?);
    final distLabel = distKm != null
        ? (distKm < 1 ? '${(distKm * 1000).round()} m' : '${distKm.toStringAsFixed(1)} km')
        : null;
    final rating    = (gym['rating'] as num?)?.toStringAsFixed(1);
    final color     = _parseColor(gym['primary_color'] as String?);
    final price     = gym['price_from'];
    final hasDropIn = gym['has_drop_in'] as bool? ?? false;
    final services  = ((gym['service_tags'] as List?) ?? const [])
        .whereType<String>().take(3).toList();

    return GestureDetector(
      onTap: () => _openGym(gym),
      child: Container(
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _kBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo
            SizedBox(
              height: 154,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  coverUrl != null
                    ? Image.network(coverUrl, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _gymPlaceholder(color, name))
                    : _gymPlaceholder(color, name),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, _kBg.withValues(alpha: 0.6)],
                          stops: const [0.55, 1.0],
                        ),
                      ),
                    ),
                  ),
                  if (hasDropIn)
                    Positioned(
                      top: 10, right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: _kGreenBg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: _kGreen.withValues(alpha: 0.4)),
                        ),
                        child: Text('Drop-in',
                          style: GoogleFonts.inter(
                            fontSize: 10, fontWeight: FontWeight.w700, color: _kGreen)),
                      ),
                    ),
                ],
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  Text(tr(name),
                    style: GoogleFonts.inter(
                      fontSize: 17, fontWeight: FontWeight.w700, color: _kText)),
                  const SizedBox(height: 4),

                  // Rating + distance/city
                  Row(children: [
                    if (rating != null) ...[
                      const Icon(Icons.star_rounded, color: _kGold, size: 12),
                      const SizedBox(width: 3),
                      Text(rating,
                        style: GoogleFonts.inter(
                          fontSize: 12, fontWeight: FontWeight.w600, color: _kGold)),
                      const SizedBox(width: 8),
                    ],
                    if (distLabel != null) ...[
                      const Icon(Icons.location_on_rounded, size: 11, color: _kGray),
                      const SizedBox(width: 2),
                      Text(distLabel,
                        style: GoogleFonts.inter(fontSize: 12, color: _kGray)),
                    ] else if (area.isNotEmpty || city.isNotEmpty) ...[
                      const Icon(Icons.location_on_rounded, size: 11, color: _kGray),
                      const SizedBox(width: 2),
                      Text([area, city].where((s) => s.isNotEmpty).join(', '),
                        style: GoogleFonts.inter(fontSize: 12, color: _kGray)),
                    ],
                  ]),

                  // Service tags
                  if (services.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      children: services.map((tag) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _kBg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: _kBorder),
                        ),
                        child: Text(tr(tag),
                          style: GoogleFonts.inter(fontSize: 10, color: _kGray)),
                      )).toList(),
                    ),
                  ],

                  const SizedBox(height: 10),

                  // Price + CTA
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (price != null)
                        Text.rich(TextSpan(
                          style: GoogleFonts.inter(fontSize: 13, color: _kGray),
                          children: [
                            TextSpan(text: tr('Από ')),
                            TextSpan(text: '€$price',
                              style: const TextStyle(
                                color: _kText, fontWeight: FontWeight.w700)),
                            TextSpan(text: tr('/μήνα')),
                          ],
                        ))
                      else
                        const SizedBox.shrink(),

                      Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: _kPrimary,
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        alignment: Alignment.center,
                        child: Text(tr('Δες τον χώρο'),
                          style: GoogleFonts.inter(
                            fontSize: 12, fontWeight: FontWeight.w700,
                            color: _kText)),
                      ),
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

  String? _mediaUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http')) return url;
    const host = 'https://passionate-grace-production-98ad.up.railway.app';
    return url.startsWith('/') ? '$host$url' : '$host/$url';
  }

  Widget _gymPlaceholder(Color color, String name) {
    return Container(
      color: color.withValues(alpha: 0.08),
      alignment: Alignment.center,
      child: Icon(Icons.fitness_center_rounded,
        color: color.withValues(alpha: 0.4), size: 48),
    );
  }

  Widget _logoFallback(Color color, String name) {
    return Container(
      color: color.withValues(alpha: 0.12),
      alignment: Alignment.center,
      child: Text(
        tr(name.isNotEmpty ? name[0].toUpperCase() : '?'),
        style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w800),
      ),
    );
  }
}

// ─────────────────────────────────────────
// Gym Filter Bottom Sheet
// ─────────────────────────────────────────

class _GymFilterSheet extends StatefulWidget {
  const _GymFilterSheet({
    required this.initialProgramTypes,
    required this.initialMaxDistance,
    required this.initialAmenities,
    required this.initialOpenNow,
    required this.currentResultCount,
    required this.onApply,
    required this.onClearAll,
  });

  final Set<String> initialProgramTypes;
  final double      initialMaxDistance;
  final Set<String> initialAmenities;
  final bool        initialOpenNow;
  final int         currentResultCount;
  final void Function(Set<String>, double, Set<String>, bool) onApply;
  final VoidCallback onClearAll;

  @override
  State<_GymFilterSheet> createState() => _GymFilterSheetState();
}

class _GymFilterSheetState extends State<_GymFilterSheet> {
  late Set<String> _programTypes;
  late double      _maxDistance;
  late Set<String> _amenities;
  late bool        _openNow;

  static final _kProgramTypes = [
    'CrossFit', 'Yoga', 'Pilates', 'Functional', 'HIIT', 'Boxing',
    tr('Κολύμβηση'), 'Personal Training', tr('Δύναμη'), 'Cardio',
  ];
  static const _kAmenityIcons = {
    'Parking': '🅿', 'Showers': '🚿', 'Locker rooms': '🔒',
    'Pool': '🏊', 'Cafe': '☕', 'Towel service': '👕',
  };

  @override
  void initState() {
    super.initState();
    _programTypes = Set.from(widget.initialProgramTypes);
    _maxDistance  = widget.initialMaxDistance;
    _amenities    = Set.from(widget.initialAmenities);
    _openNow      = widget.initialOpenNow;
  }

  void _clearAll() {
    setState(() {
      _programTypes.clear();
      _maxDistance = 50;
      _amenities.clear();
      _openNow = false;
    });
  }

  bool get _hasAny =>
    _programTypes.isNotEmpty || _maxDistance < 50 ||
    _amenities.isNotEmpty || _openNow;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: _kBorder,
                borderRadius: BorderRadius.circular(2)),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(tr('Φίλτρα'),
                  style: GoogleFonts.inter(
                    fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                const Spacer(),
                if (_hasAny)
                  GestureDetector(
                    onTap: _clearAll,
                    child: Text(tr('Καθαρισμός'),
                      style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w600, color: _kAccent)),
                  ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _kBg,
                      shape: BoxShape.circle,
                      border: Border.all(color: _kBorder),
                    ),
                    child: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),

          // Scrollable content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Είδος Προγράμματος ──
                  _sectionLabel(tr('Είδος Προγράμματος')),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: _kProgramTypes.map((t) {
                      final sel = _programTypes.contains(t);
                      return GestureDetector(
                        onTap: () => setState(() =>
                          sel ? _programTypes.remove(t) : _programTypes.add(t)),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: sel ? _kGuideBg : _kBg,
                            borderRadius: BorderRadius.circular(9999),
                            border: Border.all(
                              color: sel ? _kAccent : _kBorder,
                              width: sel ? 1.5 : 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(tr(t),
                            style: GoogleFonts.inter(
                              fontSize: 13, fontWeight: FontWeight.w600,
                              color: sel ? _kAccent : _kGray)),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),

                  // ── Distance ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _sectionLabel(tr('Απόσταση')),
                      Text(
                        tr(_maxDistance >= 50 ? 'Οποιαδήποτε απόσταση' : 'Έως ${_maxDistance.toInt()} km'),
                        style: GoogleFonts.inter(
                          fontSize: 13, fontWeight: FontWeight.w600,
                          color: _maxDistance < 50 ? _kAccent : _kGray)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: _kAccent,
                      inactiveTrackColor: _kBorder,
                      thumbColor: _kAccent,
                      overlayColor: _kAccent.withValues(alpha: 0.15),
                      trackHeight: 3,
                    ),
                    child: Slider(
                      value: _maxDistance,
                      min: 1, max: 50, divisions: 49,
                      onChanged: (v) => setState(() => _maxDistance = v),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Amenities ──
                  _sectionLabel(tr('Ανέσεις')),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: _kAmenityIcons.entries.map((e) {
                      final sel = _amenities.contains(e.key);
                      return GestureDetector(
                        onTap: () => setState(() =>
                          sel ? _amenities.remove(e.key) : _amenities.add(e.key)),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: sel ? _kGuideBg : _kBg,
                            borderRadius: BorderRadius.circular(9999),
                            border: Border.all(
                              color: sel ? _kAccent : _kBorder,
                              width: sel ? 1.5 : 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(tr('${e.value} ${e.key}'),
                            style: GoogleFonts.inter(
                              fontSize: 13, fontWeight: FontWeight.w600,
                              color: sel ? _kAccent : _kGray)),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),

                  // ── Open now ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _sectionLabel(tr('Ανοιχτό τώρα')),
                      Switch(
                        value: _openNow,
                        activeColor: _kText,
                        activeTrackColor: _kAccent,
                        inactiveTrackColor: _kBorder,
                        inactiveThumbColor: _kGray,
                        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
                        onChanged: (v) => setState(() => _openNow = v),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          // Sticky bottom
          Padding(
            padding: EdgeInsets.fromLTRB(24, 12, 24,
              MediaQuery.of(context).viewInsets.bottom +
              MediaQuery.of(context).padding.bottom + 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    widget.onApply(_programTypes, _maxDistance, _amenities, _openNow);
                  },
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: _kPrimary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      tr(widget.currentResultCount > 0
                        ? 'Εμφάνιση ${widget.currentResultCount} γυμναστηρίων'
                        : 'Εφαρμογή φίλτρων'),
                      style: GoogleFonts.inter(
                        fontSize: 15, fontWeight: FontWeight.w700,
                        color: _kText)),
                  ),
                ),
                if (_hasAny) ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      widget.onClearAll();
                    },
                    child: Text(tr('Καθαρισμός φίλτρων'),
                      style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: _kGray,
                        decoration: TextDecoration.underline,
                        decorationColor: _kGray)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(tr(text),
    style: GoogleFonts.inter(
      fontSize: 13, fontWeight: FontWeight.w700,
      color: Colors.white, letterSpacing: 0.3));
}
