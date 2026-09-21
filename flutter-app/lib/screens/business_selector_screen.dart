import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/tenant_config.dart';
import '../services/global_auth_service.dart';
import '../theme/app_colors.dart';
import 'global_login_screen.dart';

class BusinessSelectorScreen extends StatefulWidget {
  const BusinessSelectorScreen({
    super.key,
    required this.onConfigLoaded,
    this.showBack = false,
    this.apiBaseUrl = 'https://passionate-grace-production-98ad.up.railway.app',
    this.globalAuth,
    this.onGlobalDashboard,
  });

  final void Function(TenantConfig) onConfigLoaded;
  final bool showBack;
  final String apiBaseUrl;
  final GlobalAuthService? globalAuth;
  final VoidCallback? onGlobalDashboard;

  @override
  State<BusinessSelectorScreen> createState() => _BusinessSelectorScreenState();
}

class _SearchResult {
  final String slug;
  final String name;
  final String appName;
  final String businessType;
  final String primaryColor;
  final String? logoUrl;
  final String? city;
  final String? description;
  final List<String> services;

  const _SearchResult({
    required this.slug,
    required this.name,
    required this.appName,
    required this.businessType,
    required this.primaryColor,
    this.logoUrl,
    this.city,
    this.description,
    this.services = const [],
  });

  factory _SearchResult.fromJson(Map<String, dynamic> j) => _SearchResult(
    slug:         j['slug']          as String,
    name:         j['name']          as String,
    appName:      j['app_name']      as String,
    businessType: j['business_type'] as String,
    primaryColor: j['primary_color'] as String? ?? '#B8F55E',
    logoUrl:      j['logo_url']      as String?,
    city:         j['city']          as String?,
    description:  j['description']   as String?,
    services:     (j['services']     as List?)?.cast<String>() ?? [],
  );
}

class _BusinessSelectorScreenState extends State<BusinessSelectorScreen>
    with SingleTickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  final _focusNode  = FocusNode();
  late final AnimationController _entry;
  late final Animation<double> _entryOpacity;
  late final Animation<Offset> _entrySlide;

  List<_SearchResult> _results  = [];
  bool _searching   = false;
  bool _connecting  = false;
  String? _error;
  Timer? _debounce;
  bool _searchFocused = false;
  String _selectedService = '';
  final _cityCtrl = TextEditingController();

  static const _serviceFilters = [
    ('', 'Όλα'),
    ('Pilates', 'Pilates'),
    ('Yoga', 'Yoga'),
    ('CrossFit', 'CrossFit'),
    ('Spinning', 'Spinning'),
    ('Boxing', 'Boxing'),
    ('Fitness', 'Fitness'),
  ];

  @override
  void initState() {
    super.initState();
    _entry = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
      ..forward();
    _entryOpacity = CurvedAnimation(parent: _entry, curve: const Interval(0, 0.7, curve: Curves.easeOut));
    _entrySlide = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entry, curve: const Interval(0, 0.7, curve: Curves.easeOutCubic)));

    _focusNode.addListener(() => setState(() => _searchFocused = _focusNode.hasFocus));
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _entry.dispose();
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    _debounce?.cancel();
    final hasFilter = _selectedService.isNotEmpty || _cityCtrl.text.trim().isNotEmpty;
    if (val.trim().length < 2 && !hasFilter) {
      setState(() { _results = []; _error = null; });
      return;
    }
    setState(() { _searching = true; _error = null; });
    _debounce = Timer(const Duration(milliseconds: 400), () => _doSearch(val.trim()));
  }

  void _onFilterChanged() {
    _debounce?.cancel();
    setState(() { _searching = true; _error = null; });
    _debounce = Timer(const Duration(milliseconds: 300), () => _doSearch(_searchCtrl.text.trim()));
  }

  Future<void> _doSearch(String q) async {
    final city    = _cityCtrl.text.trim();
    final service = _selectedService;
    final useDiscovery = service.isNotEmpty || city.isNotEmpty;

    try {
      Uri uri;
      if (useDiscovery) {
        final params = <String, String>{};
        if (q.length >= 2) params['q'] = q;
        if (service.isNotEmpty) params['service'] = service;
        if (city.isNotEmpty) params['city'] = city;
        uri = Uri.parse('${widget.apiBaseUrl}/api/global/discovery/gyms').replace(queryParameters: params);
      } else {
        if (q.length < 2) { setState(() { _results = []; _searching = false; }); return; }
        uri = Uri.parse('${widget.apiBaseUrl}/api/tenants/search?q=${Uri.encodeComponent(q)}');
      }
      final res = await http.get(uri).timeout(const Duration(seconds: 6));
      if (!mounted) return;
      if (res.statusCode == 200) {
        final list = (jsonDecode(res.body) as List)
            .map((e) => _SearchResult.fromJson(e as Map<String, dynamic>))
            .toList();
        setState(() { _results = list; _searching = false; });
      } else {
        setState(() { _error = 'Σφάλμα σύνδεσης (${res.statusCode})'; _searching = false; });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() { _error = 'Αδύνατη η σύνδεση. Έλεγξε τη σύνδεσή σου.'; _searching = false; });
    }
  }

  Future<void> _selectBusiness(_SearchResult biz) async {
    setState(() { _connecting = true; _error = null; });
    try {
      final config = await TenantConfig.loadFromApi(
        slug:       biz.slug,
        apiBaseUrl: widget.apiBaseUrl,
      );
      if (!mounted) return;
      widget.onConfigLoaded(config);
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _connecting = false; });
    }
  }

  Color _parseColor(String hex) {
    try { return Color(int.parse(hex.replaceFirst('#', '0xFF'))); }
    catch (_) { return AppColors.lime; }
  }

  String _typeLabel(String t) {
    const m = {
      'gym': 'Γυμναστήριο', 'aesthetic': 'Αισθητική',
      'salon': 'Κομμωτήριο', 'barbershop': 'Barbershop',
      'spa': 'Spa', 'pilates': 'Pilates / Yoga',
      'physiotherapy': 'Φυσικοθεραπεία', 'personal_training': 'Personal Training',
    };
    return m[t] ?? t;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090E),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Ambient background
          CustomPaint(painter: _BackgroundPainter()),

          // Main content
          SafeArea(
            child: SlideTransition(
              position: _entrySlide,
              child: FadeTransition(
                opacity: _entryOpacity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header zone
                    Padding(
                      padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Logo + wordmark
                          Row(
                            children: [
                              SizedBox(
                                width: 36, height: 36,
                                child: Image.asset(
                                  'assets/logo.png',
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => _OmniplexMark(size: 36),
                                ),
                              ),
                              const SizedBox(width: 10),
                              ShaderMask(
                                shaderCallback: (bounds) => const LinearGradient(
                                  colors: [Color(0xFF7C5CFC), Color(0xFFE040FB)],
                                ).createShader(bounds),
                                child: const Text(
                                  'OmniPlex',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 40),

                          // Hero headline
                          const Text(
                            'Βρες τον\nχώρο σου.',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              height: 1.15,
                              letterSpacing: -0.5,
                              color: Colors.white,
                            ),
                          ),

                          const SizedBox(height: 10),
                          Text(
                            'Αναζήτησε γυμναστήριο ή κέντρο',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 14,
                              letterSpacing: 0.2,
                            ),
                          ),

                          const SizedBox(height: 28),

                          // Search field — custom minimal design
                          _SearchField(
                            controller: _searchCtrl,
                            focusNode: _focusNode,
                            focused: _searchFocused,
                            searching: _searching,
                            onChanged: _onSearchChanged,
                            onClear: () {
                              _searchCtrl.clear();
                              setState(() { _results = []; _error = null; });
                            },
                          ),

                          const SizedBox(height: 12),

                          // City field
                          _CityField(
                            controller: _cityCtrl,
                            onChanged: (_) => _onFilterChanged(),
                          ),

                          const SizedBox(height: 12),

                          // Service type filter chips
                          SizedBox(
                            height: 34,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _serviceFilters.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 8),
                              itemBuilder: (_, i) {
                                final (val, label) = _serviceFilters[i];
                                final selected = _selectedService == val;
                                return GestureDetector(
                                  onTap: () {
                                    setState(() => _selectedService = val);
                                    _onFilterChanged();
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: selected ? AppColors.lime : Colors.white.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: selected ? AppColors.lime : Colors.white.withValues(alpha: 0.15),
                                      ),
                                    ),
                                    child: Text(
                                      label,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: selected ? Colors.black : Colors.white.withValues(alpha: 0.75),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Error
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(28, 8, 28, 0),
                        child: _ErrorBanner(message: _error!),
                      ),

                    // Results
                    Expanded(
                      child: _buildResults(),
                    ),

                    // Footer
                    _GlobalAccountBanner(
                      globalAuth: widget.globalAuth,
                      onGlobalDashboard: widget.onGlobalDashboard,
                      onLoginDone: () {
                        if (widget.onGlobalDashboard != null && (widget.globalAuth?.gyms.length ?? 0) >= 2) {
                          widget.onGlobalDashboard!();
                        } else {
                          setState(() {});
                        }
                      },
                    ),
                    _Footer(),
                  ],
                ),
              ),
            ),
          ),

          // Connecting overlay
          if (_connecting) _ConnectingOverlay(),
        ],
      ),
    );
  }

  Widget _buildResults() {
    final hasQuery = _searchCtrl.text.trim().length >= 2;
    final hasFilter = _selectedService.isNotEmpty || _cityCtrl.text.trim().isNotEmpty;

    if (!hasQuery && !hasFilter) {
      return _EmptyState(
        icon: Icons.search_rounded,
        message: 'Ξεκίνα πληκτρολογώντας\nή επέλεξε φίλτρο',
      );
    }

    if (!_searching && _results.isEmpty) {
      return _EmptyState(
        icon: Icons.search_off_rounded,
        message: 'Δεν βρέθηκαν αποτελέσματα\nΔοκίμασε διαφορετική αναζήτηση',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 24),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final biz   = _results[i];
        final color = _parseColor(biz.primaryColor);
        final logoUrl = biz.logoUrl != null
            ? (biz.logoUrl!.startsWith('http') ? biz.logoUrl! : '${widget.apiBaseUrl}${biz.logoUrl}')
            : null;
        return _ResultCard(
          biz: biz,
          color: color,
          logoUrl: logoUrl,
          onTap: () => _selectBusiness(biz),
          typeLabel: _typeLabel(biz.businessType),
        );
      },
    );
  }
}

// ── Search field ──────────────────────────────────────────────────────────────
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.focused,
    required this.searching,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool focused;
  final bool searching;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: const Color(0xFF131319),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: focused
              ? const Color(0xFF7C5CFC).withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.07),
          width: 1.5,
        ),
        boxShadow: focused
            ? [BoxShadow(color: const Color(0xFF7C5CFC).withValues(alpha: 0.08), blurRadius: 20)]
            : [],
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          SizedBox(
            width: 20, height: 20,
            child: searching
                ? CircularProgressIndicator(
                    strokeWidth: 1.5,
                    valueColor: AlwaysStoppedAnimation(Colors.white.withValues(alpha: 0.35)),
                  )
                : Icon(
                    Icons.search_rounded,
                    color: focused
                        ? const Color(0xFF9C5FFC)
                        : Colors.white.withValues(alpha: 0.28),
                    size: 20,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              cursorColor: const Color(0xFF7C5CFC),
              decoration: InputDecoration(
                hintText: 'π.χ. Handstand, FitLife...',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.22),
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          if (controller.text.isNotEmpty) ...[
            GestureDetector(
              onTap: onClear,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Icon(
                  Icons.close_rounded,
                  color: Colors.white.withValues(alpha: 0.3),
                  size: 16,
                ),
              ),
            ),
          ] else
            const SizedBox(width: 14),
        ],
      ),
    );
  }
}

// ── City filter field ─────────────────────────────────────────────────────────
class _CityField extends StatelessWidget {
  const _CityField({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFF131319),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(Icons.location_on_rounded, size: 16, color: Colors.white.withValues(alpha: 0.35)),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Πόλη (π.χ. Αθήνα, Θεσσαλονίκη)',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.22), fontSize: 13),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            GestureDetector(
              onTap: () { controller.clear(); onChanged(''); },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Icon(Icons.close_rounded, size: 14, color: Colors.white.withValues(alpha: 0.3)),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Result card ───────────────────────────────────────────────────────────────
class _ResultCard extends StatefulWidget {
  const _ResultCard({
    required this.biz,
    required this.color,
    required this.logoUrl,
    required this.onTap,
    required this.typeLabel,
  });

  final _SearchResult biz;
  final Color color;
  final String? logoUrl;
  final VoidCallback onTap;
  final String typeLabel;

  @override
  State<_ResultCard> createState() => _ResultCardState();
}

class _ResultCardState extends State<_ResultCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 100),
        opacity: _pressed ? 0.7 : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _pressed
                ? const Color(0xFF1C1C28)
                : const Color(0xFF111118),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _pressed
                  ? widget.color.withValues(alpha: 0.25)
                  : Colors.white.withValues(alpha: 0.06),
            ),
          ),
          child: Row(
            children: [
              // Logo
              Container(
                width: 50, height: 50,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: widget.color.withValues(alpha: 0.2)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: widget.logoUrl != null
                      ? Image.network(
                          widget.logoUrl!,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => _LogoFallback(color: widget.color, name: widget.biz.appName),
                        )
                      : _LogoFallback(color: widget.color, name: widget.biz.appName),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.biz.appName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          width: 5, height: 5,
                          decoration: BoxDecoration(
                            color: widget.color.withValues(alpha: 0.7),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.typeLabel,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.40),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (widget.biz.city != null) ...[
                          Text(
                            ' · ${widget.biz.city}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.30),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (widget.biz.services.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        widget.biz.services.take(3).join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: widget.color.withValues(alpha: 0.6),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    if (widget.biz.description != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        widget.biz.description!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.30),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: widget.color.withValues(alpha: 0.8),
                  size: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Logo fallback ─────────────────────────────────────────────────────────────
class _LogoFallback extends StatelessWidget {
  const _LogoFallback({required this.color, required this.name});
  final Color color;
  final String name;

  @override
  Widget build(BuildContext context) {
    final letter = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Center(
      child: Text(
        letter,
        style: TextStyle(
          color: color,
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white.withValues(alpha: 0.10), size: 48),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.22),
                fontSize: 14,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error banner ──────────────────────────────────────────────────────────────
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFF1E0E0E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: Colors.red.withValues(alpha: 0.7), size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Global account banner ─────────────────────────────────────────────────────
class _GlobalAccountBanner extends StatelessWidget {
  const _GlobalAccountBanner({required this.globalAuth, required this.onGlobalDashboard, required this.onLoginDone});
  final GlobalAuthService? globalAuth;
  final VoidCallback? onGlobalDashboard;
  final VoidCallback onLoginDone;

  @override
  Widget build(BuildContext context) {
    final auth = globalAuth;
    final isLoggedIn = auth?.isLoggedIn ?? false;
    final gymCount   = auth?.gyms.length ?? 0;

    if (isLoggedIn && gymCount >= 2 && onGlobalDashboard != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 12),
        child: GestureDetector(
          onTap: onGlobalDashboard,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF7C5CFC).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF7C5CFC).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.grid_view_rounded, color: Color(0xFF7C5CFC), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Τα γυμναστήριά μου ($gymCount)',
                    style: const TextStyle(color: Color(0xFF9D7BFE), fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF7C5CFC), size: 13),
              ],
            ),
          ),
        ),
      );
    }

    // Not logged in — show login prompt
    if (auth != null && !isLoggedIn) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 12),
        child: GestureDetector(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => GlobalLoginScreen(globalAuth: auth, onDone: () { Navigator.pop(context); onLoginDone(); }),
            ));
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                Icon(Icons.person_rounded, color: Colors.white.withValues(alpha: 0.5), size: 18),
                const SizedBox(width: 10),
                Text(
                  'Σύνδεση / Εγγραφή global λογαριασμού',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

// ── Footer ────────────────────────────────────────────────────────────────────
class _Footer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(width: 20, height: 1, color: Colors.white.withValues(alpha: 0.06)),
          const SizedBox(width: 10),
          Text(
            'OMNIPLEX',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.10),
              fontSize: 10,
              letterSpacing: 3,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 10),
          Container(width: 20, height: 1, color: Colors.white.withValues(alpha: 0.06)),
        ],
      ),
    );
  }
}

// ── Connecting overlay ────────────────────────────────────────────────────────
class _ConnectingOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.6),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 40, height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(const Color(0xFF9C5FFC)),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'ΣΥΝΔΕΣΗ',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 11,
                letterSpacing: 3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Omniplex mark (fallback for logo asset) ───────────────────────────────────
class _OmniplexMark extends StatelessWidget {
  const _OmniplexMark({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: const BoxDecoration(
        color: Color(0xFF131319),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          'O',
          style: TextStyle(
            color: const Color(0xFF9C5FFC),
            fontSize: size * 0.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

// ── Background painter ────────────────────────────────────────────────────────
class _BackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Top-right subtle glow
    canvas.drawCircle(
      Offset(size.width, 0),
      size.width * 0.5,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF7C5CFC).withValues(alpha: 0.05),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: Offset(size.width, 0), radius: size.width * 0.5)),
    );

    // Bottom-left purple glow
    canvas.drawCircle(
      Offset(0, size.height),
      size.width * 0.55,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.purple.withValues(alpha: 0.06),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: Offset(0, size.height), radius: size.width * 0.55)),
    );

    // Fine grid pattern
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.025)
      ..strokeWidth = 0.5;

    const step = 60.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(_BackgroundPainter _) => false;
}

