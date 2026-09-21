import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;
import '../services/global_auth_service.dart';
import '../theme/app_colors.dart';
import 'global_login_screen.dart';
import 'package_purchase_screen.dart';

class ServiceDetailScreen extends StatefulWidget {
  const ServiceDetailScreen({
    super.key,
    required this.service,
    required this.gymSlug,
    required this.gymName,
    required this.gymColor,
    required this.globalAuth,
    required this.onPurchased,
  });

  final Map<String, dynamic> service;
  final String gymSlug;
  final String gymName;
  final Color gymColor;
  final GlobalAuthService globalAuth;
  final VoidCallback onPurchased;

  @override
  State<ServiceDetailScreen> createState() => _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends State<ServiceDetailScreen> {
  static const _apiBase = 'https://passionate-grace-production-98ad.up.railway.app/api';

  List<Map<String, dynamic>> _packages = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPackages();
  }

  Future<void> _loadPackages() async {
    try {
      final serviceId = widget.service['id']?.toString() ?? '';
      final res = await http.get(
        Uri.parse('$_apiBase/global/discovery/gyms/${widget.gymSlug}/packages'),
      );
      if (res.statusCode == 200) {
        final all = (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
        setState(() {
          _packages = all
              .where((p) => p['service_id']?.toString() == serviceId)
              .toList();
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  void _buyPackage(Map<String, dynamic> pkg) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PackagePurchaseScreen(
          plan: pkg,
          gymSlug: widget.gymSlug,
          gymName: widget.gymName,
          gymColor: widget.gymColor,
          globalAuth: widget.globalAuth,
          onPurchased: () {
            Navigator.pop(context); // pop purchase screen
            Navigator.pop(context); // pop service detail
            widget.onPurchased();
          },
        ),
      ),
    );
  }

  String _fmtPrice(int cents) {
    final eur = cents / 100;
    return '€${eur % 1 == 0 ? eur.toInt() : eur.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final service  = widget.service;
    final name     = service['name'] as String? ?? '';
    final desc     = service['description'] as String? ?? '';
    final duration = service['duration_mins'] as int?;
    final color    = widget.gymColor;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: AppColors.bg,
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
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color.withValues(alpha: 0.7), color.withValues(alpha: 0.2), AppColors.bg],
                  ),
                ),
                child: Align(
                  alignment: Alignment.center,
                  child: Icon(Icons.fitness_center_rounded, color: color, size: 64),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + meta
                  Text(name, style: const TextStyle(
                      fontSize: 26, fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(widget.gymName,
                            style: TextStyle(fontSize: 12, color: color,
                                fontWeight: FontWeight.w700)),
                      ),
                      if (duration != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text('$duration λεπτά',
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textSecondary)),
                        ),
                      ],
                    ],
                  ),

                  if (desc.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(desc,
                        style: const TextStyle(
                            fontSize: 14, color: AppColors.textSecondary, height: 1.65)),
                  ],

                  const SizedBox(height: 28),
                  const Text('Πακέτα',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text('Επίλεξε πακέτο για να ξεκινήσεις',
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  const SizedBox(height: 16),

                  if (_loading)
                    const Center(child: CircularProgressIndicator(color: AppColors.lime))
                  else if (_packages.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Center(
                        child: Text('Δεν υπάρχουν διαθέσιμα πακέτα',
                            style: TextStyle(color: AppColors.textSecondary)),
                      ),
                    )
                  else
                    ..._packages.map((pkg) => _PackageTile(
                          pkg: pkg,
                          color: color,
                          fmtPrice: _fmtPrice,
                          onBuy: () => _buyPackage(pkg),
                        )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PackageTile extends StatelessWidget {
  const _PackageTile({
    required this.pkg,
    required this.color,
    required this.fmtPrice,
    required this.onBuy,
  });

  final Map<String, dynamic> pkg;
  final Color color;
  final String Function(int) fmtPrice;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final name     = pkg['name'] as String? ?? '';
    final desc     = pkg['description'] as String? ?? '';
    final sessions = pkg['sessions_included'] as int?;
    final days     = pkg['validity_days'] as int?;
    final price    = pkg['price_cents'] as int? ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(name,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary)),
              ),
              Text(fmtPrice(price),
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
            ],
          ),
          if (desc.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(desc, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 6,
            children: [
              if (sessions != null)
                _pill(Icons.fitness_center_rounded, '$sessions συνεδρίες', color),
              if (days != null)
                _pill(Icons.calendar_today_rounded, '$days ημέρες', color),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onBuy,
              style: FilledButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Αγορά πακέτου',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(IconData icon, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
      ],
    ),
  );
}
