import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/global_auth_service.dart';
import '../theme/app_colors.dart';
import 'global_login_screen.dart';
import 'global_register_screen.dart';
import 'gym_profile_screen.dart';

class DiscoveryLandingScreen extends StatefulWidget {
  const DiscoveryLandingScreen({
    super.key,
    required this.globalAuth,
    required this.onLoggedIn,
  });

  final GlobalAuthService globalAuth;
  final VoidCallback onLoggedIn;

  @override
  State<DiscoveryLandingScreen> createState() => _DiscoveryLandingScreenState();
}

class _DiscoveryLandingScreenState extends State<DiscoveryLandingScreen> {
  static const _apiBase = 'https://passionate-grace-production-98ad.up.railway.app/api';

  final _searchCtrl = TextEditingController();
  final _cityCtrl   = TextEditingController();

  String _selectedService = '';
  List<Map<String, dynamic>> _results = [];
  bool _searching = false;
  bool _searched = false;
  Timer? _debounce;

  static const _serviceFilters = [
    ('', 'Όλα'),
    ('Pilates', 'Pilates'),
    ('Yoga', 'Yoga'),
    ('CrossFit', 'CrossFit'),
    ('Spinning', 'Spinning'),
    ('Boxing', 'Boxing'),
    ('Fitness', 'Fitness'),
  ];

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) {
      if (_searched) setState(() { _results = []; _searched = false; });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), _search);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q       = _searchCtrl.text.trim();
    final city    = _cityCtrl.text.trim();
    final service = _selectedService;

    if (q.isEmpty && city.isEmpty && service.isEmpty) return;

    setState(() { _searching = true; _searched = true; });
    try {
      Uri uri;
      // Name-only search: use /tenants/search (returns all active gyms, not just discoverable)
      // Service/city filter: use /global/discovery/gyms (discoverable only)
      if (q.isNotEmpty && city.isEmpty && service.isEmpty) {
        uri = Uri.parse('$_apiBase/tenants/search').replace(queryParameters: {'q': q});
      } else {
        final params = <String, String>{};
        if (q.isNotEmpty)       params['q']       = q;
        if (city.isNotEmpty)    params['city']    = city;
        if (service.isNotEmpty) params['service'] = service;
        uri = Uri.parse('$_apiBase/global/discovery/gyms').replace(queryParameters: params);
      }

      final res = await http.get(uri);
      if (res.statusCode == 200) {
        setState(() {
          _results = (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _searching = false);
  }

  void _openGym(Map<String, dynamic> gym) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GymProfileScreen(
          slug: gym['slug'] as String,
          globalAuth: widget.globalAuth,
          onLoggedIn: widget.onLoggedIn,
        ),
      ),
    );
  }

  void _goLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GlobalLoginScreen(
          globalAuth: widget.globalAuth,
          onLoggedIn: widget.onLoggedIn,
        ),
      ),
    );
  }

  void _goRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GlobalRegisterScreen(
          globalAuth: widget.globalAuth,
          onRegistered: widget.onLoggedIn,
        ),
      ),
    );
  }

  Color _parseColor(String? hex) {
    if (hex == null) return AppColors.lime;
    try { return Color(int.parse(hex.replaceFirst('#', '0xFF'))); }
    catch (_) { return AppColors.lime; }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'OmniPlex',
                    style: TextStyle(
                      fontSize: 28, fontWeight: FontWeight.w900,
                      color: AppColors.lime, letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Βρες το γυμναστήριό σου',
                    style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),

                  // Search bar
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Αναζήτηση γυμναστηρίου...',
                            hintStyle: const TextStyle(color: AppColors.textSecondary),
                            prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary, size: 20),
                            filled: true,
                            fillColor: AppColors.surfaceLight,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: AppColors.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: AppColors.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: AppColors.lime),
                            ),
                          ),
                          onChanged: _onSearchChanged,
                          onSubmitted: (_) => _search(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _search,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.lime,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.arrow_forward_rounded, color: AppColors.bg, size: 20),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // City filter
                  TextField(
                    controller: _cityCtrl,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Πόλη (π.χ. Αθήνα)',
                      hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                      prefixIcon: const Icon(Icons.location_on_outlined, color: AppColors.textSecondary, size: 18),
                      filled: true,
                      fillColor: AppColors.surfaceLight,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.lime),
                      ),
                    ),
                    onChanged: (_) {
                      _debounce?.cancel();
                      _debounce = Timer(const Duration(milliseconds: 500), _search);
                    },
                    onSubmitted: (_) => _search(),
                  ),
                  const SizedBox(height: 10),

                  // Service chips
                  SizedBox(
                    height: 34,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: _serviceFilters.map((f) {
                        final selected = _selectedService == f.$1;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _selectedService = f.$1);
                              _search();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: selected ? AppColors.lime : AppColors.surfaceLight,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: selected ? AppColors.lime : AppColors.border,
                                ),
                              ),
                              child: Text(
                                f.$2,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: selected ? AppColors.bg : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),

            // Results or auth buttons
            Expanded(
              child: _searching
                  ? const Center(child: CircularProgressIndicator(color: AppColors.lime))
                  : _searched && _results.isEmpty
                      ? Center(
                          child: Text(
                            'Δεν βρέθηκαν αποτελέσματα',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        )
                      : _results.isNotEmpty
                          ? ListView.builder(
                              padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                              itemCount: _results.length,
                              itemBuilder: (_, i) {
                                final g = _results[i];
                                final color = _parseColor(g['primary_color'] as String?);
                                return GestureDetector(
                                  onTap: () => _openGym(g),
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceLight,
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(color: AppColors.border),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 48, height: 48,
                                          decoration: BoxDecoration(
                                            color: color.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: g['logo_url'] != null
                                              ? ClipRRect(
                                                  borderRadius: BorderRadius.circular(11),
                                                  child: Image.network(g['logo_url'] as String, fit: BoxFit.contain,
                                                      errorBuilder: (_, __, ___) => Center(
                                                        child: Text(
                                                          (g['app_name'] as String? ?? g['name'] as String? ?? '?')[0].toUpperCase(),
                                                          style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800),
                                                        ),
                                                      )),
                                                )
                                              : Center(
                                                  child: Text(
                                                    (g['app_name'] as String? ?? g['name'] as String? ?? '?')[0].toUpperCase(),
                                                    style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800),
                                                  ),
                                                ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                g['app_name'] as String? ?? g['name'] as String? ?? '',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700, fontSize: 15,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                              if ((g['city'] as String?)?.isNotEmpty == true)
                                                Text(
                                                  g['city'] as String,
                                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                                ),
                                            ],
                                          ),
                                        ),
                                        const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: 20),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            )
                          : Padding(
                              padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  const Spacer(),
                                  // Illustration / placeholder
                                  Container(
                                    padding: const EdgeInsets.all(32),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceLight,
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(color: AppColors.border),
                                    ),
                                    child: Column(
                                      children: [
                                        Icon(Icons.fitness_center_rounded, size: 56, color: AppColors.lime.withValues(alpha: 0.7)),
                                        const SizedBox(height: 16),
                                        const Text(
                                          'Βρες & κράτησε θέση\nστο γυμναστήριό σου',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 18, fontWeight: FontWeight.w800,
                                            color: AppColors.textPrimary, height: 1.3,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        const Text(
                                          'Αναζήτησε με όνομα, πόλη ή κατηγορία',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Spacer(),

                                  // Login / Register buttons
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton(
                                      onPressed: _goLogin,
                                      style: FilledButton.styleFrom(
                                        backgroundColor: AppColors.lime,
                                        foregroundColor: AppColors.bg,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      ),
                                      child: const Text('Σύνδεση', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton(
                                      onPressed: _goRegister,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.textPrimary,
                                        side: BorderSide(color: AppColors.border),
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      ),
                                      child: const Text('Εγγραφή', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
