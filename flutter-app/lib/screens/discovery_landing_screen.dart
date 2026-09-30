import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../services/global_auth_service.dart';
import '../theme/brand.dart';
import '../config/tenant_config.dart';
import 'global_register_screen.dart';
import 'phone_otp_login_screen.dart';
import 'gym_profile_screen.dart';

const _kBg     = Color(0xFF0A0A0A);
const _kCard   = Color(0xFF16171B);
const _kBorder = Color(0xFF2A2B30);
const _kGray   = Color(0xFF9A9CA3);
const _kLime   = Color(0xFFC6FF3D);
const _kCyan   = Color(0xFF3EE6FF);
const _kDot    = Color(0xFF3A3C42);

class DiscoveryLandingScreen extends StatefulWidget {
  const DiscoveryLandingScreen({
    super.key,
    required this.globalAuth,
    required this.onLoggedIn,
    this.onEnterGym,
    this.hideHeader = false,
  });

  final GlobalAuthService globalAuth;
  final VoidCallback onLoggedIn;
  final void Function(TenantConfig)? onEnterGym;
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

  static const _kProgramTypes = [
    'CrossFit', 'Yoga', 'Pilates', 'Functional', 'HIIT', 'Boxing',
    'Κολύμβηση', 'Personal Training', 'Δύναμη', 'Cardio',
  ];
  static const _kAmenityIcons = {
    'Parking': '🅿', 'Showers': '🚿', 'Locker rooms': '🔒',
    'Pool': '🏊', 'Cafe': '☕', 'Towel service': '👕',
  };
  static const _kQuickChips = [
    'CrossFit', 'Yoga', 'Pilates', 'Functional', 'HIIT', 'Boxing', 'Κοντά μου',
  ];

  // (label, apiKey, iconAsset, activeBorderColor)
  static const _categories = [
    ('CrossFit', 'CrossFit', 'assets/icons/discovery_crossfit.svg', _kBorder),
    ('Yoga',     'Yoga',     'assets/icons/discovery_yoga.svg',     _kCyan),
    ('Pilates',  'Pilates',  'assets/icons/discovery_pilates.svg',  _kBorder),
    ('Δύναμη',   'Strength', 'assets/icons/discovery_more.svg',     _kBorder),
    ('HIIT',     'HIIT',     'assets/icons/discovery_more.svg',     _kBorder),
  ];

  static const _popularSearches = [
    'CrossFit', 'Yoga', 'Pilates', 'Boxing', 'Personal Training', '24ωρα γυμναστήρια',
  ];

  static const _activities = [
    ('CrossFit',          'assets/icons/discovery_act_crossfit.svg',  Color(0xFF2A1E14), Color(0xFFC06A1E)),
    ('Yoga',              'assets/icons/discovery_act_yoga.svg',       Color(0xFF141A2A), Color(0xFF3EE6FF)),
    ('Pilates',           'assets/icons/discovery_act_pilates.svg',    Color(0xFF14261C), Color(0xFF4ADE80)),
    ('Δύναμη',            'assets/icons/discovery_act_strength.svg',   Color(0xFF1A1420), Color(0xFFA78BFA)),
    ('Boxing',            'assets/icons/discovery_act_boxing.svg',     Color(0xFF2A1414), Color(0xFFF87171)),
    ('Κολύμβηση',         'assets/icons/discovery_act_swimming.svg',   Color(0xFF14202A), Color(0xFF38BDF8)),
    ('Personal Training', 'assets/icons/discovery_act_pt.svg',         Color(0xFF261E14), Color(0xFFFBBF24)),
  ];

  @override
  void initState() {
    super.initState();
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
        );
        if (mounted) setState(() { _userLat = pos.latitude; _userLng = pos.longitude; });
      }
    } catch (_) {}
    _loadFeatured();
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
      final res = await http.get(uri);
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
        !_quickFilters.contains('Κοντά μου')) return;
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
      if (_quickFilters.contains('Κοντά μου')) params['max_distance'] = '5';
      if (_filterOpenNow) params['open_now'] = 'true';
      if (_filterAmenities.isNotEmpty) params['amenities'] = _filterAmenities.join(',');
      final uri = Uri.parse('$_apiBase/global/discovery/gyms').replace(queryParameters: params);
      final res = await http.get(uri);
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
        globalAuth: widget.globalAuth,
        onLoggedIn: widget.onLoggedIn,
        onEnterGym: widget.onEnterGym,
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
    if (hex == null) return _kLime;
    try { return Color(int.parse(hex.replaceFirst('#', '0xFF'))); }
    catch (_) { return _kLime; }
  }

  // ─────────── build ───────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        children: [
          Positioned(
            top: 0, left: 0,
            child: SizedBox(
              width: 375, height: 256,
              child: CustomPaint(painter: _LimeGradientPainter()),
            ),
          ),
          Positioned(
            top: 160, right: 0,
            child: SizedBox(
              width: 160, height: 160,
              child: CustomPaint(painter: _CyanGradientPainter()),
            ),
          ),
          SafeArea(
            child: (_searchFocused || _searched)
              ? _buildSearchModeContent()
              : _buildHomeContent(),
          ),
        ],
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
                  Text('Δεν βρέθηκαν γυμναστήρια κοντά σου',
                    style: GoogleFonts.manrope(color: _kGray, fontSize: 14)),
                  const SizedBox(height: 6),
                  Text('Δοκίμασε αναζήτηση με όνομα ή πόλη',
                    style: GoogleFonts.manrope(color: _kGray.withValues(alpha: 0.6), fontSize: 12)),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
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
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: _kLime,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: SvgPicture.asset(
              'assets/icons/discovery_logo_bolt.svg',
              width: 14, height: 14,
            ),
          ),
          const SizedBox(width: 8),
          Text('OmniPlex',
            style: GoogleFonts.manrope(
              fontSize: 18, fontWeight: FontWeight.w700,
              color: Colors.white, letterSpacing: -0.45)),
        ]),
        GestureDetector(
          onTap: widget.globalAuth.isLoggedIn ? widget.onLoggedIn : _goLogin,
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            child: Text(
              widget.globalAuth.isLoggedIn
                ? (widget.globalAuth.user?.fullName.split(' ').first ?? 'Προφίλ')
                : 'Σύνδεση',
              style: GoogleFonts.manrope(
                fontSize: 14, fontWeight: FontWeight.w700,
                color: _kLime, letterSpacing: 0.35)),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Βρες το τέλειο\nγυμναστήριό σου.',
          style: GoogleFonts.manrope(
            fontSize: 32, fontWeight: FontWeight.w700,
            color: Colors.white, letterSpacing: -0.8, height: 1.1)),
        const SizedBox(height: 11),
        Text('Ανακάλυψε γυμναστήρια, μαθήματα και\nσυνδρομές κοντά σου.',
          style: GoogleFonts.manrope(
            fontSize: 14, color: _kGray, height: 1.625)),
      ],
    );
  }

  Widget _buildSearchBarHome() {
    return GestureDetector(
      onTap: () {
        setState(() => _searchFocused = true);
        _searchFocus.requestFocus();
      },
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kBorder),
        ),
        child: Row(children: [
          const SizedBox(width: 16),
          SvgPicture.asset('assets/icons/discovery_search.svg', width: 16, height: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Αναζήτηση γυμναστηρίου, μαθήματος...',
              style: GoogleFonts.manrope(fontSize: 14, color: _kGray)),
          ),
          const SizedBox(width: 16),
        ]),
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final cat   = _categories[i];
          final active = _activeCategory == cat.$2;
          final borderColor = active ? cat.$4 : _kBorder;
          final textColor   = active ? (cat.$4 == _kCyan ? _kCyan : Colors.white) : Colors.white;
          return GestureDetector(
            onTap: () => _selectCategory(cat.$2),
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(9999),
                border: Border.all(color: borderColor),
              ),
              child: Row(children: [
                SvgPicture.asset(cat.$3, width: 14, height: 14,
                  colorFilter: active && cat.$4 == _kCyan
                    ? const ColorFilter.mode(_kCyan, BlendMode.srcIn)
                    : null),
                const SizedBox(width: 8),
                Text(cat.$1,
                  style: GoogleFonts.manrope(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: textColor, letterSpacing: 0.15)),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHomeSectionHeader() {
    return Text('Γυμναστήρια κοντά σου',
      style: GoogleFonts.manrope(
        fontSize: 18, fontWeight: FontWeight.w700,
        color: Colors.white, letterSpacing: -0.45));
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
          child: SvgPicture.asset('assets/icons/discovery_back.svg',
            width: 16, height: 16),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kBorder),
          ),
          child: Row(children: [
            const SizedBox(width: 14),
            SvgPicture.asset('assets/icons/discovery_search.svg',
              width: 16, height: 16,
              colorFilter: const ColorFilter.mode(_kLime, BlendMode.srcIn)),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                focusNode: _searchFocus,
                autofocus: true,
                style: GoogleFonts.manrope(fontSize: 14, color: Colors.white),
                cursorColor: _kLime,
                decoration: InputDecoration(
                  hintText: 'Αναζήτηση γυμναστηρίου, μαθήματος...',
                  hintStyle: GoogleFonts.manrope(fontSize: 14, color: _kGray),
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
                child: Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: SvgPicture.asset('assets/icons/discovery_x.svg',
                    width: 14, height: 14),
                ),
              )
            else
              const SizedBox(width: 10),
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
                color: _hasActiveFilters ? _kLime.withValues(alpha: 0.12) : _kCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _hasActiveFilters ? _kLime : _kBorder),
              ),
              alignment: Alignment.center,
              child: SvgPicture.asset('assets/icons/discovery_filter.svg',
                width: 16, height: 16,
                colorFilter: ColorFilter.mode(
                  _hasActiveFilters ? _kLime : Colors.white, BlendMode.srcIn)),
            ),
            if (_hasActiveFilters)
              Positioned(
                top: -3, right: -3,
                child: Container(
                  width: 10, height: 10,
                  decoration: const BoxDecoration(color: _kLime, shape: BoxShape.circle),
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
          final color = isNearby ? _kCyan : _kLime;
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
                color: active ? color.withValues(alpha: 0.12) : _kCard,
                borderRadius: BorderRadius.circular(9999),
                border: Border.all(color: active ? color : _kBorder),
              ),
              alignment: Alignment.center,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (isNearby) ...[
                  Icon(Icons.near_me_rounded, size: 12,
                    color: active ? _kCyan : _kGray),
                  const SizedBox(width: 6),
                ],
                Text(chip,
                  style: GoogleFonts.manrope(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: active ? color : Colors.white)),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchResultsBody() {
    if (_searching) {
      return const Center(child: CircularProgressIndicator(color: _kLime));
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
          _searched ? '$count γυμναστήρια βρέθηκαν' : 'Κοντά σου',
          style: GoogleFonts.manrope(
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
            child: Text('Καθαρισμός όλων',
              style: GoogleFonts.manrope(fontSize: 12, color: _kLime,
                decoration: TextDecoration.underline, decorationColor: _kLime)),
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: _kCard,
                shape: BoxShape.circle,
                border: Border.all(color: _kBorder),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.search_off_rounded, size: 36, color: _kGray),
            ),
            const SizedBox(height: 20),
            Text('Δεν βρέθηκαν γυμναστήρια',
              style: GoogleFonts.manrope(
                fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 8),
            Text('Δοκίμασε διαφορετικούς όρους ή αφαίρεσε κάποια φίλτρα.',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(fontSize: 13, color: _kGray, height: 1.5)),
            if (_hasActiveFilters) ...[
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _filterProgramTypes = {};
                    _filterMaxDistanceKm = 50;
                    _filterAmenities = {};
                    _filterOpenNow = false;
                  });
                  _search();
                },
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: _kCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _kBorder),
                  ),
                  alignment: Alignment.center,
                  child: Text('Αφαίρεση φίλτρων',
                    style: GoogleFonts.manrope(
                      fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
            ],
          ],
        ),
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
            Text('Πρόσφατες αναζητήσεις',
              style: GoogleFonts.manrope(
                fontSize: 13, fontWeight: FontWeight.w700,
                color: Colors.white)),
            GestureDetector(
              onTap: () {},
              child: Text('Διαγραφή',
                style: GoogleFonts.manrope(
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
            child: Text(query,
              style: GoogleFonts.manrope(
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
        Text('Δημοφιλείς κατηγορίες',
          style: GoogleFonts.manrope(
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
              child: Text(tag,
                style: GoogleFonts.manrope(
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
        Text('Nearby Gyms',
          style: GoogleFonts.manrope(
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
    final coverUrl = gym['cover_url'] as String? ?? gym['cover_image_url'] as String?;
    final rating   = (gym['rating'] as num?)?.toStringAsFixed(1) ?? '4.8';
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
                  Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: Colors.white)),
                  const SizedBox(height: 2),
                  Row(children: [
                    SvgPicture.asset('assets/icons/discovery_star.svg',
                      width: 9, height: 9),
                    const SizedBox(width: 3),
                    Text(rating,
                      style: GoogleFonts.manrope(
                        fontSize: 10, fontWeight: FontWeight.w600,
                        color: Colors.white)),
                  ]),
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
        Text('Popular Activities',
          style: GoogleFonts.manrope(
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
                    child: Text(act.$1, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
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
        label: t,
        onRemove: () { setState(() => _filterProgramTypes.remove(t)); _search(); },
      ));
    }
    if (_filterMaxDistanceKm < 50) {
      chips.add(_activeFilterChip(
        label: 'Έως ${_filterMaxDistanceKm.toInt()} km',
        onRemove: () { setState(() => _filterMaxDistanceKm = 50); _search(); },
      ));
    }
    for (final a in _filterAmenities) {
      final icon = _kAmenityIcons[a] ?? '';
      chips.add(_activeFilterChip(
        label: '$icon $a',
        onRemove: () { setState(() => _filterAmenities.remove(a)); _search(); },
      ));
    }
    if (_filterOpenNow) {
      chips.add(_activeFilterChip(
        label: '🟢 Ανοιχτό τώρα',
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
          color: _kLime.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(9999),
          border: Border.all(color: _kLime),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label,
            style: GoogleFonts.manrope(
              fontSize: 12, fontWeight: FontWeight.w600, color: _kLime)),
          const SizedBox(width: 6),
          const Icon(Icons.close_rounded, size: 12, color: _kLime),
        ]),
      ),
    );
  }

  // ─────────── GYM CARD (shared, two modes) ───────────

  Widget _buildGymCard(Map<String, dynamic> gym, {required bool showLogoBadge}) {
    final name     = gym['app_name'] as String? ?? gym['name'] as String? ?? '';
    final logoUrl  = gym['logo_url'] as String?;
    final coverUrl = gym['cover_url'] as String? ?? gym['cover_image_url'] as String?;
    final city     = gym['city'] as String? ?? '';
    final distKm   = (gym['distance_km'] as num?);
    final distLabel = distKm != null
        ? (distKm < 1 ? '${(distKm * 1000).round()} m' : '${distKm.toStringAsFixed(1)} km')
        : null;
    final rating   = (gym['rating'] as num?)?.toStringAsFixed(1) ?? '4.8';
    final services = (gym['services'] as List?)?.cast<String>() ??
                     (gym['service_types'] as String?)?.split(',').map((s) => s.trim()).toList() ?? [];
    final color    = _parseColor(gym['primary_color'] as String?);
    final price    = gym['price_from'];
    final hasDropIn = gym['has_drop_in'] as bool? ?? false;

    return GestureDetector(
      onTap: () => _openGym(gym),
      child: Container(
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _kBorder),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 15, offset: const Offset(0, 10)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero image
            SizedBox(
              height: 176,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  coverUrl != null
                    ? Image.network(coverUrl, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _gymPlaceholder(color, name))
                    : _gymPlaceholder(color, name),

                  // Bottom gradient
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            const Color(0xFF0A0A0A).withValues(alpha: 0.7),
                          ],
                          stops: const [0.5, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // Logo badge (always visible)
                  Positioned(
                    bottom: -24, left: 16,
                    child: Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        color: _kCard,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _kBg, width: 2),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: logoUrl != null
                        ? Image.network(logoUrl, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _logoFallback(color, name))
                        : _logoFallback(color, name),
                    ),
                  ),

                  // Drop-in / Membership badge (results mode)
                  if (!showLogoBadge)
                    Positioned(
                      top: 12, right: 12,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(9999),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          color: hasDropIn
                            ? _kCyan.withValues(alpha: 0.20)
                            : Colors.black.withValues(alpha: 0.50),
                          child: Text(
                            hasDropIn ? 'Drop-in available' : 'Membership only',
                            style: GoogleFonts.manrope(
                              fontSize: 10, fontWeight: FontWeight.w700,
                              color: hasDropIn ? _kCyan : Colors.white,
                              letterSpacing: 0.2),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Info section
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 36, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  Text(name,
                    style: GoogleFonts.manrope(
                      fontSize: 16, fontWeight: FontWeight.w700,
                      color: Colors.white)),
                  const SizedBox(height: 5),

                  // Rating + city
                  Row(children: [
                    SvgPicture.asset('assets/icons/discovery_star.svg',
                      width: 11, height: 10),
                    const SizedBox(width: 4),
                    Text(rating,
                      style: GoogleFonts.manrope(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        color: Colors.white)),
                    if (distLabel != null) ...[
                      const SizedBox(width: 8),
                      Container(width: 4, height: 4,
                        decoration: const BoxDecoration(
                          color: _kDot, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      const Icon(Icons.location_on_rounded, size: 10, color: _kLime),
                      const SizedBox(width: 2),
                      Text(distLabel,
                        style: GoogleFonts.manrope(fontSize: 12, color: _kLime, fontWeight: FontWeight.w600)),
                    ] else if (city.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(width: 4, height: 4,
                        decoration: const BoxDecoration(
                          color: _kDot, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Text(city,
                        style: GoogleFonts.manrope(fontSize: 12, color: _kGray)),
                    ],
                  ]),
                  const SizedBox(height: 8),

                  // Services: pills in results mode, text in home mode
                  if (services.isNotEmpty)
                    showLogoBadge
                      ? Text(services.take(3).join(' · '),
                          style: GoogleFonts.manrope(fontSize: 12, color: _kGray))
                      : Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: services.take(3).map((s) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _kBg,
                              borderRadius: BorderRadius.circular(9999),
                              border: Border.all(color: _kBorder),
                            ),
                            child: Text(s,
                              style: GoogleFonts.manrope(
                                fontSize: 10, fontWeight: FontWeight.w500,
                                color: _kGray)),
                          )).toList(),
                        ),

                  const SizedBox(height: 11),

                  // Price + CTA
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (price != null)
                        Text.rich(TextSpan(
                          style: GoogleFonts.manrope(
                            fontSize: 14, fontWeight: FontWeight.w600,
                            color: Colors.white),
                          children: [
                            const TextSpan(text: 'Από '),
                            TextSpan(text: '€$price',
                              style: const TextStyle(color: _kLime)),
                            const TextSpan(text: '/μήνα'),
                          ],
                        ))
                      else
                        const SizedBox.shrink(),

                      showLogoBadge
                        ? Container(
                            height: 40,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            decoration: BoxDecoration(
                              gradient: kBrandGradient,
                              borderRadius: BorderRadius.circular(9999),
                            ),
                            alignment: Alignment.center,
                            child: Text('Δες το γυμναστήριο',
                              style: GoogleFonts.manrope(
                                fontSize: 12, fontWeight: FontWeight.w700,
                                color: Colors.white, letterSpacing: 0.3)),
                          )
                        : Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: _kCard,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _kBorder),
                            ),
                            alignment: Alignment.center,
                            child: SvgPicture.asset(
                              'assets/icons/discovery_chevron_right.svg',
                              width: 12, height: 12,
                              colorFilter: const ColorFilter.mode(
                                Colors.white, BlendMode.srcIn),
                            ),
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
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w800),
      ),
    );
  }
}

// ── Background gradient painters ──

class _LimeGradientPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = RadialGradient(
        center: Alignment.topCenter,
        radius: 1.0,
        colors: [
          const Color(0xFFC6FF3D).withValues(alpha: 0.10),
          const Color(0xFFC6FF3D).withValues(alpha: 0.03),
          const Color(0xFFC6FF3D).withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.35, 0.6],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

class _CyanGradientPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.7,
        colors: [
          const Color(0xFF3EE6FF).withValues(alpha: 0.10),
          const Color(0xFF3EE6FF).withValues(alpha: 0.0),
        ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2), size.width / 2, paint);
  }

  @override
  bool shouldRepaint(_) => false;
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

  static const _kProgramTypes = [
    'CrossFit', 'Yoga', 'Pilates', 'Functional', 'HIIT', 'Boxing',
    'Κολύμβηση', 'Personal Training', 'Δύναμη', 'Cardio',
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
                Text('Φίλτρα',
                  style: GoogleFonts.manrope(
                    fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                if (_hasAny)
                  GestureDetector(
                    onTap: _clearAll,
                    child: Text('Καθαρισμός όλων',
                      style: GoogleFonts.manrope(
                        fontSize: 13, fontWeight: FontWeight.w600, color: _kLime)),
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
                  _sectionLabel('Είδος Προγράμματος'),
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
                            color: sel ? _kLime.withValues(alpha: 0.12) : _kBg,
                            borderRadius: BorderRadius.circular(9999),
                            border: Border.all(
                              color: sel ? _kLime : _kBorder,
                              width: sel ? 1.5 : 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(t,
                            style: GoogleFonts.manrope(
                              fontSize: 13, fontWeight: FontWeight.w600,
                              color: sel ? _kLime : _kGray)),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),

                  // ── Απόσταση ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _sectionLabel('Απόσταση'),
                      Text(
                        _maxDistance >= 50 ? 'Οποιαδήποτε' : 'Έως ${_maxDistance.toInt()} km',
                        style: GoogleFonts.manrope(
                          fontSize: 13, fontWeight: FontWeight.w600,
                          color: _maxDistance < 50 ? _kLime : _kGray)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: _kLime,
                      inactiveTrackColor: _kBorder,
                      thumbColor: _kLime,
                      overlayColor: _kLime.withValues(alpha: 0.15),
                      trackHeight: 3,
                    ),
                    child: Slider(
                      value: _maxDistance,
                      min: 1, max: 50, divisions: 49,
                      onChanged: (v) => setState(() => _maxDistance = v),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Παροχές ──
                  _sectionLabel('Παροχές'),
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
                            color: sel ? _kLime.withValues(alpha: 0.12) : _kBg,
                            borderRadius: BorderRadius.circular(9999),
                            border: Border.all(
                              color: sel ? _kLime : _kBorder,
                              width: sel ? 1.5 : 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text('${e.value} ${e.key}',
                            style: GoogleFonts.manrope(
                              fontSize: 13, fontWeight: FontWeight.w600,
                              color: sel ? _kLime : _kGray)),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),

                  // ── Ανοιχτό τώρα ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _sectionLabel('Ανοιχτό τώρα'),
                      Switch(
                        value: _openNow,
                        activeColor: _kLime,
                        activeTrackColor: _kLime.withValues(alpha: 0.25),
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
                      color: _kLime,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: _kLime.withValues(alpha: 0.28),
                          blurRadius: 16, offset: const Offset(0, 6)),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      widget.currentResultCount > 0
                        ? 'Δες ${widget.currentResultCount} γυμναστήρια'
                        : 'Εφαρμογή Φίλτρων',
                      style: GoogleFonts.manrope(
                        fontSize: 15, fontWeight: FontWeight.w700,
                        color: _kBg)),
                  ),
                ),
                if (_hasAny) ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      widget.onClearAll();
                    },
                    child: Text('Καθαρισμός φίλτρων',
                      style: GoogleFonts.manrope(
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

  Widget _sectionLabel(String text) => Text(text,
    style: GoogleFonts.manrope(
      fontSize: 13, fontWeight: FontWeight.w700,
      color: Colors.white, letterSpacing: 0.3));
}
