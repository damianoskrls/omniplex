import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/global_auth_service.dart';
import '../theme/app_colors.dart';
import 'global_login_screen.dart';

class GymProfileScreen extends StatefulWidget {
  const GymProfileScreen({
    super.key,
    required this.slug,
    required this.globalAuth,
    required this.onLoggedIn,
  });

  final String slug;
  final GlobalAuthService globalAuth;
  final VoidCallback onLoggedIn;

  @override
  State<GymProfileScreen> createState() => _GymProfileScreenState();
}

class _GymProfileScreenState extends State<GymProfileScreen> {
  static const _apiBase = 'https://passionate-grace-production-98ad.up.railway.app/api';

  Map<String, dynamic>? _gym;
  List<Map<String, dynamic>> _packages = [];
  bool _loading = true;
  String? _error;
  bool _joiningRequest = false;
  String? _joinStatus;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final gymRes = await http.get(Uri.parse('$_apiBase/global/discovery/gyms/${widget.slug}'));
      final pkgRes = await http.get(Uri.parse('$_apiBase/global/discovery/gyms/${widget.slug}/packages'));

      if (gymRes.statusCode == 200) {
        _gym = jsonDecode(gymRes.body) as Map<String, dynamic>;
      }
      if (pkgRes.statusCode == 200) {
        _packages = (jsonDecode(pkgRes.body) as List).cast<Map<String, dynamic>>();
      }
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _sendJoinRequest() async {
    if (!widget.globalAuth.isLoggedIn) {
      final loggedIn = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => GlobalLoginScreen(
            globalAuth: widget.globalAuth,
            onLoggedIn: () {
              Navigator.pop(context, true);
              widget.onLoggedIn();
            },
          ),
        ),
      );
      if (loggedIn != true && !widget.globalAuth.isLoggedIn) return;
    }

    setState(() => _joiningRequest = true);
    try {
      final token = widget.globalAuth.token;
      final res = await http.post(
        Uri.parse('$_apiBase/global/join-requests'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({'business_id': _gym!['id']}),
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() => _joinStatus = body['status'] as String?);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(body['message'] as String? ?? 'Αίτημα στάλθηκε'),
          backgroundColor: AppColors.surfaceLight,
        ));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString()),
        backgroundColor: Colors.red.shade700,
      ));
    } finally {
      if (mounted) setState(() => _joiningRequest = false);
    }
  }

  Color _parseColor(String? hex) {
    if (hex == null) return AppColors.lime;
    try { return Color(int.parse(hex.replaceFirst('#', '0xFF'))); }
    catch (_) { return AppColors.lime; }
  }

  String _fmtPrice(int cents) {
    final eur = cents / 100;
    return '€${eur % 1 == 0 ? eur.toInt() : eur.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: const Center(child: CircularProgressIndicator(color: AppColors.lime)),
      );
    }
    if (_error != null || _gym == null) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(backgroundColor: AppColors.bg, elevation: 0,
          leading: BackButton(color: AppColors.textPrimary)),
        body: Center(child: Text(_error ?? 'Δεν βρέθηκε', style: const TextStyle(color: AppColors.textSecondary))),
      );
    }

    final gym   = _gym!;
    final color = _parseColor(gym['primary_color'] as String?);
    final name  = gym['app_name'] as String? ?? gym['name'] as String? ?? '';
    final city  = gym['city'] as String? ?? '';
    final desc  = gym['description'] as String? ?? '';
    final services = (gym['services'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          // Hero
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: AppColors.bg,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color.withValues(alpha: 0.3), AppColors.bg],
                  ),
                ),
                child: Center(
                  child: gym['logo_url'] != null
                      ? Image.network(gym['logo_url'] as String, height: 100, fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => _Initial(name: name, color: color))
                      : _Initial(name: name, color: color, size: 64),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                  if (city.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(city, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    ]),
                  ],

                  // Services chips
                  if (services.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: services.map((s) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: color.withValues(alpha: 0.3)),
                        ),
                        child: Text(s['name'] as String? ?? '', style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600, color: color)),
                      )).toList(),
                    ),
                  ],

                  // Description
                  if (desc.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(desc, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.6)),
                  ],

                  // Packages
                  if (_packages.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    const Text('Πακέτα', style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                    const SizedBox(height: 12),
                    ..._packages.map((p) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p['name'] as String? ?? '', style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary)),
                                if ((p['description'] as String?)?.isNotEmpty == true)
                                  Text(p['description'] as String, style: const TextStyle(
                                    fontSize: 12, color: AppColors.textSecondary)),
                                const SizedBox(height: 4),
                                Text(
                                  '${p['sessions_included']} συνεδρίες · ${p['validity_days']} ημέρες',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _fmtPrice(p['price_cents'] as int? ?? 0),
                            style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w900, color: color),
                          ),
                        ],
                      ),
                    )),
                  ],

                  // Join request CTA
                  const SizedBox(height: 28),
                  if (_joinStatus == 'pending')
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.lime.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.lime.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.hourglass_top_rounded, color: AppColors.lime, size: 18),
                          SizedBox(width: 8),
                          Text('Το αίτημά σου εκκρεμεί',
                            style: TextStyle(color: AppColors.lime, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    )
                  else if (_joinStatus == 'linked')
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_rounded, color: Colors.green, size: 18),
                          SizedBox(width: 8),
                          Text('Είσαι ήδη μέλος!', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _joiningRequest ? null : _sendJoinRequest,
                        style: FilledButton.styleFrom(
                          backgroundColor: color,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: _joiningRequest
                            ? const SizedBox(width: 20, height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Αίτηση Εγγραφής', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Initial extends StatelessWidget {
  const _Initial({required this.name, required this.color, this.size = 48});
  final String name;
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size * 1.5, height: size * 1.5,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      shape: BoxShape.circle,
    ),
    child: Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(color: color, fontSize: size * 0.6, fontWeight: FontWeight.w900),
      ),
    ),
  );
}
