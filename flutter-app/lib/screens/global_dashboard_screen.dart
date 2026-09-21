import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/tenant_config.dart';
import '../services/biometric_auth_service.dart';
import '../services/global_auth_service.dart';
import '../theme/app_colors.dart';
import 'business_selector_screen.dart';

class GlobalDashboardScreen extends StatefulWidget {
  const GlobalDashboardScreen({
    super.key,
    required this.globalAuth,
    required this.onEnterGym,
    required this.onLogout,
  });

  final GlobalAuthService globalAuth;
  final void Function(TenantConfig config) onEnterGym;
  final VoidCallback onLogout;

  @override
  State<GlobalDashboardScreen> createState() => _GlobalDashboardScreenState();
}

class _GlobalDashboardScreenState extends State<GlobalDashboardScreen> {
  static const _apiBase = 'https://passionate-grace-production-98ad.up.railway.app/api';

  List<Map<String, dynamic>> _upcomingBookings = [];
  bool _loading = true;
  String? _error;
  bool _enteringGym = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      await widget.globalAuth.refreshGyms();
      final token = widget.globalAuth.token;
      final res = await http.get(
        Uri.parse('$_apiBase/global/me/dashboard'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() {
          _upcomingBookings = ((body['upcoming_bookings'] as List?) ?? [])
              .cast<Map<String, dynamic>>();
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _enterGym(GlobalGym gym) async {
    setState(() => _enteringGym = true);
    try {
      final gymToken = await widget.globalAuth.getGymToken(gym.businessId);
      // Pre-store the per-gym JWT so AuthService.init() picks it up
      await BiometricAuthService.instance.saveToken(gym.businessId, gymToken);
      final config = await TenantConfig.loadFromApi(
        slug:       gym.slug,
        apiBaseUrl: 'https://passionate-grace-production-98ad.up.railway.app',
      );
      if (!mounted) return;
      widget.onEnterGym(config);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red.shade700),
      );
    } finally {
      if (mounted) setState(() => _enteringGym = false);
    }
  }

  void _addGym() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BusinessSelectorScreen(
          onConfigLoaded: (config) {
            Navigator.pop(context);
            widget.onEnterGym(config);
          },
          showBack: true,
        ),
      ),
    );
  }

  Color _parseColor(String hex) {
    try { return Color(int.parse(hex.replaceFirst('#', '0xFF'))); }
    catch (_) { return AppColors.lime; }
  }

  String _fmtDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final d = DateTime.parse(iso);
      const months = ['Ιαν','Φεβ','Μαρ','Απρ','Μαΐ','Ιουν','Ιουλ','Αυγ','Σεπ','Οκτ','Νοε','Δεκ'];
      return '${d.day} ${months[d.month - 1]}';
    } catch (_) { return iso; }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.globalAuth.user;
    final gyms = widget.globalAuth.gyms;
    final firstName = user?.fullName.split(' ').first ?? '';

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: _enteringGym
            ? const Center(child: CircularProgressIndicator(color: AppColors.lime))
            : RefreshIndicator(
                color: AppColors.lime,
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  children: [
                    // Header
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Γεια σου, $firstName 👋',
                                style: const TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.w900,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                '${gyms.length} γυμναστήρι${gyms.length == 1 ? 'ο' : 'α'}',
                                style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () async {
                            await widget.globalAuth.clear();
                            widget.onLogout();
                          },
                          icon: const Icon(Icons.logout_rounded, color: AppColors.textSecondary, size: 22),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // My Gyms section
                    const Text(
                      'Τα Γυμναστήριά Μου',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 12),

                    if (_loading)
                      const Center(child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: CircularProgressIndicator(color: AppColors.lime),
                      ))
                    else ...[
                      ...gyms.map((gym) {
                        final color = _parseColor(gym.primaryColor);
                        return _GymCard(
                          gym: gym,
                          accentColor: color,
                          onTap: () => _enterGym(gym),
                        );
                      }),

                      // Add gym button
                      GestureDetector(
                        onTap: _addGym,
                        child: Container(
                          margin: const EdgeInsets.only(top: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: AppColors.lime.withValues(alpha: 0.3),
                              style: BorderStyle.solid,
                            ),
                            color: AppColors.lime.withValues(alpha: 0.05),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.add_rounded, color: AppColors.lime, size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'Προσθήκη γυμναστηρίου',
                                style: TextStyle(
                                  color: AppColors.lime,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    // Upcoming bookings
                    if (_upcomingBookings.isNotEmpty) ...[
                      const SizedBox(height: 28),
                      const Text(
                        'Επόμενες Κρατήσεις',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 12),
                      ..._upcomingBookings.map((b) => _BookingRow(booking: b, fmtDate: _fmtDate)),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

class _GymCard extends StatelessWidget {
  const _GymCard({required this.gym, required this.accentColor, required this.onTap});
  final GlobalGym gym;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: gym.logoUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: Image.network(gym.logoUrl!, fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => _Initial(name: gym.appName, color: accentColor)),
                    )
                  : _Initial(name: gym.appName, color: accentColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(gym.appName, style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textPrimary)),
                  if (gym.businessType.isNotEmpty)
                    Text(_typeLabel(gym.businessType), style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('Είσοδος', style: TextStyle(
                color: accentColor, fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  String _typeLabel(String t) {
    const m = {'gym': 'Γυμναστήριο', 'pilates': 'Pilates/Yoga', 'salon': 'Κομμωτήριο', 'spa': 'Spa'};
    return m[t] ?? t;
  }
}

class _Initial extends StatelessWidget {
  const _Initial({required this.name, required this.color});
  final String name;
  final Color color;
  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      name.isNotEmpty ? name[0].toUpperCase() : '?',
      style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w800),
    ),
  );
}

class _BookingRow extends StatelessWidget {
  const _BookingRow({required this.booking, required this.fmtDate});
  final Map<String, dynamic> booking;
  final String Function(String?) fmtDate;

  @override
  Widget build(BuildContext context) {
    final time = (booking['booking_time'] as String? ?? '').substring(0, 5);
    final service = booking['service_name'] as String? ?? '';
    final gymName = booking['app_name'] as String? ?? booking['business_name'] as String? ?? '';
    final date = fmtDate(booking['booking_date'] as String?);
    final staffName = booking['staff_name'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(date, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              Text(time, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.lime)),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(service, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                Text(
                  gymName + (staffName != null ? ' · $staffName' : ''),
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
