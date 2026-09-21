import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/global_auth_service.dart';
import '../theme/app_colors.dart';
import 'global_login_screen.dart';
import 'service_detail_screen.dart';

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
  List<Map<String, dynamic>> _hours    = [];
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
      final results = await Future.wait([
        http.get(Uri.parse('$_apiBase/global/discovery/gyms/${widget.slug}')),
        http.get(Uri.parse('$_apiBase/global/discovery/gyms/${widget.slug}/packages')),
        http.get(Uri.parse('$_apiBase/global/discovery/gyms/${widget.slug}/opening-hours')),
      ]);
      if (results[0].statusCode == 200) {
        _gym = jsonDecode(results[0].body) as Map<String, dynamic>;
      }
      if (results[1].statusCode == 200) {
        _packages = (jsonDecode(results[1].body) as List).cast<Map<String, dynamic>>();
      }
      if (results[2].statusCode == 200) {
        _hours = (jsonDecode(results[2].body) as List).cast<Map<String, dynamic>>();
      }
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _sendJoinRequest() async {
    if (!widget.globalAuth.isLoggedIn) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GlobalLoginScreen(
            globalAuth: widget.globalAuth,
            onLoggedIn: () { Navigator.pop(context); widget.onLoggedIn(); },
          ),
        ),
      );
      if (!widget.globalAuth.isLoggedIn) return;
    }

    setState(() => _joiningRequest = true);
    try {
      final res = await http.post(
        Uri.parse('$_apiBase/global/join-requests'),
        headers: {'Content-Type': 'application/json',
                  'Authorization': 'Bearer ${widget.globalAuth.token}'},
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

  void _goLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GlobalLoginScreen(
          globalAuth: widget.globalAuth,
          preselectedGym: _gym,
          onLoggedIn: () { Navigator.pop(context); widget.onLoggedIn(); setState(() {}); },
        ),
      ),
    );
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

  static const _dayNames = ['Δευ', 'Τρί', 'Τετ', 'Πέμ', 'Παρ', 'Σάβ', 'Κυρ'];

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
        body: Center(child: Text(_error ?? 'Δεν βρέθηκε',
            style: const TextStyle(color: AppColors.textSecondary))),
      );
    }

    final gym      = _gym!;
    final color    = _parseColor(gym['primary_color'] as String?);
    final name     = gym['app_name'] as String? ?? gym['name'] as String? ?? '';
    final city     = gym['city'] as String? ?? '';
    final desc     = gym['description'] as String? ?? '';
    final phone    = gym['phone'] as String? ?? '';
    final address  = gym['address'] as String? ?? '';
    final logoUrl  = gym['logo_url'] as String?;
    final services = (gym['services'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final isLoggedIn = widget.globalAuth.isLoggedIn;

    return Scaffold(
      backgroundColor: AppColors.bg,
      // Sticky bottom bar
      bottomNavigationBar: _StickyBar(
        isLoggedIn: isLoggedIn,
        joinStatus: _joinStatus,
        joiningRequest: _joiningRequest,
        color: color,
        onLogin: _goLogin,
        onJoin: _sendJoinRequest,
      ),
      body: CustomScrollView(
        slivers: [
          // ── Hero ─────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: AppColors.bg,
            elevation: 0,
            leading: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                radius: 18,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 16),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Background: logo fill or gradient
                  if (logoUrl != null)
                    Image.network(logoUrl, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _GradientBg(color: color))
                  else
                    _GradientBg(color: color),

                  // Dark overlay for readability
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black87],
                      ),
                    ),
                  ),

                  // Name + city at bottom
                  Positioned(
                    bottom: 20, left: 20, right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: const TextStyle(
                              fontSize: 28, fontWeight: FontWeight.w900,
                              color: Colors.white, height: 1.1,
                            )),
                        if (city.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(children: [
                            const Icon(Icons.location_on_rounded,
                                size: 13, color: Colors.white70),
                            const SizedBox(width: 4),
                            Text(city,
                                style: const TextStyle(
                                    fontSize: 13, color: Colors.white70)),
                          ]),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Body ─────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Service chips
                  if (services.isNotEmpty) ...[
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: services.map((s) => _ServiceChip(
                        label: s['name'] as String? ?? '',
                        color: color,
                      )).toList(),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Description
                  if (desc.isNotEmpty) ...[
                    Text(desc,
                        style: const TextStyle(
                            fontSize: 14, color: AppColors.textSecondary,
                            height: 1.65)),
                    const SizedBox(height: 24),
                  ],

                  // Contact info
                  if (phone.isNotEmpty || address.isNotEmpty) ...[
                    _SectionTitle('Στοιχεία επικοινωνίας'),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          if (phone.isNotEmpty)
                            _InfoRow(Icons.phone_rounded, phone),
                          if (phone.isNotEmpty && address.isNotEmpty)
                            const Divider(color: AppColors.border, height: 20),
                          if (address.isNotEmpty)
                            _InfoRow(Icons.location_on_rounded, address),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Opening hours
                  if (_hours.isNotEmpty) ...[
                    _SectionTitle('Ωράριο λειτουργίας'),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: List.generate(_hours.length, (i) {
                          final h = _hours[i];
                          final day = h['day_of_week'] as int? ?? i;
                          final isClosed = (h['is_closed'] as int?) == 1;
                          final open  = h['open_time']  as String? ?? '';
                          final close = h['close_time'] as String? ?? '';
                          final dayName = day < _dayNames.length ? _dayNames[day] : '';
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 36,
                                  child: Text(dayName,
                                      style: const TextStyle(
                                          fontSize: 13, fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: isClosed
                                      ? const Text('Κλειστό',
                                          style: TextStyle(fontSize: 13,
                                              color: AppColors.textSecondary))
                                      : Text('$open – $close',
                                          style: const TextStyle(fontSize: 13,
                                              color: AppColors.textPrimary)),
                                ),
                                if (!isClosed)
                                  Container(
                                    width: 7, height: 7,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF4CAF50),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Υπηρεσίες
                  if (services.isNotEmpty) ...[
                    _SectionTitle('Υπηρεσίες'),
                    const SizedBox(height: 12),
                    ...services.map((s) => _ServiceRow(
                      service: s,
                      color: color,
                      onBook: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ServiceDetailScreen(
                            service: s,
                            gymSlug: widget.slug,
                            gymName: name,
                            gymColor: color,
                            globalAuth: widget.globalAuth,
                            onPurchased: () {
                              widget.onLoggedIn();
                              setState(() {});
                            },
                          ),
                        ),
                      ),
                    )),
                    const SizedBox(height: 24),
                  ],

                  // Πακέτα
                  if (_packages.isNotEmpty) ...[
                    _SectionTitle('Πακέτα'),
                    const SizedBox(height: 12),
                    ..._packages.map((p) => _PackageCard(
                          package: p, color: color, fmtPrice: _fmtPrice)),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sticky bottom bar ─────────────────────────────────────────

class _StickyBar extends StatelessWidget {
  const _StickyBar({
    required this.isLoggedIn,
    required this.joinStatus,
    required this.joiningRequest,
    required this.color,
    required this.onLogin,
    required this.onJoin,
  });

  final bool isLoggedIn;
  final String? joinStatus;
  final bool joiningRequest;
  final Color color;
  final VoidCallback onLogin;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20,
          MediaQuery.of(context).padding.bottom + 12),
      decoration: const BoxDecoration(
        color: AppColors.bg,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: isLoggedIn
          ? _joinedBar()
          : _loggedOutBar(),
    );
  }

  Widget _loggedOutBar() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: onLogin,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: AppColors.border),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Σύνδεση', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: FilledButton(
            onPressed: onLogin,
            style: FilledButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Αίτηση Εγγραφής',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ),
      ],
    );
  }

  Widget _joinedBar() {
    if (joinStatus == 'pending') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.lime.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
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
      );
    }
    if (joinStatus == 'linked') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.green, size: 18),
            SizedBox(width: 8),
            Text('Είσαι ήδη μέλος!',
                style: TextStyle(color: Colors.green, fontWeight: FontWeight.w700)),
          ],
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: joiningRequest ? null : onJoin,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: joiningRequest
            ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Text('Αίτηση Εγγραφής',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────

class _GradientBg extends StatelessWidget {
  const _GradientBg({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          color.withValues(alpha: 0.6),
          color.withValues(alpha: 0.15),
          AppColors.bg,
        ],
      ),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary));
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 16, color: AppColors.textSecondary),
      const SizedBox(width: 10),
      Expanded(child: Text(text,
          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary))),
    ],
  );
}

class _ServiceChip extends StatelessWidget {
  const _ServiceChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Text(label, style: TextStyle(
        fontSize: 12, fontWeight: FontWeight.w600, color: color)),
  );
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({
    required this.service,
    required this.color,
    required this.onBook,
  });
  final Map<String, dynamic> service;
  final Color color;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final name     = service['name'] as String? ?? '';
    final duration = service['duration_mins'] as int?;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.fitness_center_rounded, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 14,
                    color: AppColors.textPrimary)),
                if (duration != null)
                  Text('$duration λεπτά',
                      style: const TextStyle(fontSize: 12,
                          color: AppColors.textSecondary)),
              ],
            ),
          ),
          TextButton(
            onPressed: onBook,
            style: TextButton.styleFrom(
              foregroundColor: color,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: color.withValues(alpha: 0.4))),
            ),
            child: const Text('Κράτηση',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _PackageCard extends StatelessWidget {
  const _PackageCard({
    required this.package,
    required this.color,
    required this.fmtPrice,
  });
  final Map<String, dynamic> package;
  final Color color;
  final String Function(int) fmtPrice;

  @override
  Widget build(BuildContext context) {
    final name     = package['name'] as String? ?? '';
    final desc     = package['description'] as String? ?? '';
    final sessions = package['sessions_included'] as int?;
    final days     = package['validity_days'] as int?;
    final price    = package['price_cents'] as int? ?? 0;

    return Container(
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
                Text(name, style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 15,
                    color: AppColors.textPrimary)),
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(desc, style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
                ],
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    if (sessions != null)
                      _pill('$sessions συνεδρίες'),
                    if (days != null)
                      _pill('$days ημέρες'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(fmtPrice(price),
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w900, color: color)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
  );
}
