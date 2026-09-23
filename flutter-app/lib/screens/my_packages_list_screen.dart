import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/omni_design.dart';

class MyPackagesListScreen extends StatefulWidget {
  const MyPackagesListScreen({super.key});

  @override
  State<MyPackagesListScreen> createState() => _MyPackagesListScreenState();
}

class _MyPackagesListScreenState extends State<MyPackagesListScreen> {
  static const _kDark = Color(0xFF161616);
  static const _kBorder26 = Color(0xFF262626);
  static const _kGray6B = Color(0xFF6B7280);

  int _activeTab = 0; // 0=Active, 1=Pending, 2=Expired

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 96),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFacilityTitle(),
                          const SizedBox(height: 24),
                          _buildTabBar(),
                          const SizedBox(height: 24),
                          _buildPackageCard(
                            title: '10 CLASS PACK',
                            subtitle: 'Premium CrossFit Tier',
                            remaining: '7 Sessions',
                            expires: '28 Oct 2026',
                            price: '€120',
                            isUnlimited: false,
                          ),
                          const SizedBox(height: 24),
                          _buildPackageCard(
                            title: 'YOGA MONTHLY',
                            subtitle: 'Zen Studio Unlimited',
                            remaining: 'Unlimited',
                            expires: '15 Nov 2025',
                            price: '€80',
                            isUnlimited: true,
                          ),
                          const SizedBox(height: 24),
                          _buildPurchaseNew(),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(left: 0, right: 0, bottom: 0, child: _buildBottomNav()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: kBg.withValues(alpha: 0.80),
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildCircleBtn(const Icon(Icons.chevron_left, color: Colors.white, size: 20)),
          Text('MY PACKAGES', style: GoogleFonts.spaceGrotesk(
            fontSize: 18, fontWeight: FontWeight.w700,
            color: Colors.white, letterSpacing: 1.8)),
          _buildCircleBtn(const Icon(Icons.tune, color: Colors.white, size: 18)),
        ],
      ),
    );
  }

  Widget _buildCircleBtn(Widget child) {
    return Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: _kBorder26.withValues(alpha: 0.50),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Center(child: child),
    );
  }

  Widget _buildFacilityTitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('CURRENT FACILITY', style: GoogleFonts.manrope(
          fontSize: 10, fontWeight: FontWeight.w700,
          color: kCyan, letterSpacing: 1.0)),
        const SizedBox(height: 4),
        Text('FITNESS CLUB ATHENS', style: GoogleFonts.spaceGrotesk(
          fontSize: 20, fontWeight: FontWeight.w800,
          color: Colors.white, letterSpacing: -0.5)),
      ],
    );
  }

  Widget _buildTabBar() {
    final tabs = ['Active', 'Pending', 'Expired'];
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: _kDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final active = _activeTab == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeTab = i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: active ? kLime : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(tabs[i].toUpperCase(), style: GoogleFonts.manrope(
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: active ? kBg : _kGray6B,
                    letterSpacing: 0.6)),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPackageCard({
    required String title,
    required String subtitle,
    required String remaining,
    required String expires,
    required String price,
    required bool isUnlimited,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x66262626), Color(0x99161616)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title row
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: GoogleFonts.spaceGrotesk(
                          fontSize: 24, fontWeight: FontWeight.w900,
                          color: Colors.white, letterSpacing: -0.19)),
                        const SizedBox(height: 4),
                        Text(subtitle, style: GoogleFonts.manrope(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: kCyan)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Stats grid
                Container(
                  decoration: BoxDecoration(
                    border: Border.symmetric(
                      horizontal: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildStatItem('REMAINING',
                              isUnlimited
                                ? Text('Unlimited', style: GoogleFonts.spaceGrotesk(
                                    fontSize: 18, fontWeight: FontWeight.w900,
                                    color: Colors.white, fontStyle: FontStyle.italic,
                                    letterSpacing: -0.9))
                                : Text(remaining, style: GoogleFonts.manrope(
                                    fontSize: 18, fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                            ),
                            const SizedBox(height: 16),
                            _buildStatItem('PRICE',
                              Text(price, style: GoogleFonts.manrope(
                                fontSize: 18, fontWeight: FontWeight.w700,
                                color: Colors.white)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildStatItem('EXPIRES',
                              Text(expires, style: GoogleFonts.manrope(
                                fontSize: 18, fontWeight: FontWeight.w700,
                                color: Colors.white)),
                            ),
                            const SizedBox(height: 16),
                            _buildStatItem('PAYMENT',
                              Row(
                                children: [
                                  const Icon(Icons.check_circle, color: kLime, size: 14),
                                  const SizedBox(width: 6),
                                  Text('Paid', style: GoogleFonts.manrope(
                                    fontSize: 14, fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: kLime,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(
                            color: kLime.withValues(alpha: 0.15),
                            blurRadius: 10)],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.remove_red_eye_outlined, color: kBg, size: 16),
                            const SizedBox(width: 8),
                            Text('VIEW', style: GoogleFonts.manrope(
                              fontSize: 11, fontWeight: FontWeight.w700,
                              color: kBg, letterSpacing: 1.1)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                      ),
                      child: const Center(
                        child: Icon(Icons.calendar_today_outlined, color: Colors.white, size: 16),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Active badge
          Positioned(
            top: 16, right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: kLime.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(9999),
                border: Border.all(color: kLime.withValues(alpha: 0.30)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6, height: 6,
                    decoration: const BoxDecoration(color: kLime, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text('ACTIVE', style: GoogleFonts.manrope(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: kLime, letterSpacing: 0.05)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, Widget value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.manrope(
          fontSize: 9, fontWeight: FontWeight.w700,
          color: _kGray6B, letterSpacing: 0.45)),
        const SizedBox(height: 2),
        value,
      ],
    );
  }

  Widget _buildPurchaseNew() {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.add_circle_outline, color: kCyan, size: 16),
          const SizedBox(width: 8),
          Text('PURCHASE NEW PACKAGE', style: GoogleFonts.manrope(
            fontSize: 11, fontWeight: FontWeight.w700,
            color: kCyan, letterSpacing: 1.1)),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: kBg.withValues(alpha: 0.95),
        border: const Border(top: BorderSide(color: Color(0xFF262626))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildNavItem(Icons.home_rounded, 'HOME', false),
          _buildNavItem(Icons.search, 'SEARCH', false),
          _buildNavItem(Icons.calendar_today_outlined, 'SCHEDULE', false),
          _buildNavItem(Icons.fitness_center_outlined, 'MY GYMS', true),
          SizedBox(
            width: 60,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _kGray6B),
                    color: const Color(0xFF3A3C42),
                  ),
                  child: const Icon(Icons.person, color: Colors.white, size: 14),
                ),
                const SizedBox(height: 4),
                Text('PROFILE', style: GoogleFonts.manrope(
                  fontSize: 9, fontWeight: FontWeight.w700,
                  color: _kGray6B, letterSpacing: 0.9)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool active) {
    return SizedBox(
      width: 60,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: active ? kLime : _kGray6B, size: 22),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.manrope(
            fontSize: 9, fontWeight: FontWeight.w700,
            color: active ? kLime : _kGray6B, letterSpacing: 0.9)),
        ],
      ),
    );
  }
}
