import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/omni_design.dart';

class GymSpaceScreen extends StatelessWidget {
  const GymSpaceScreen({super.key});

  static const _kDark = Color(0xFF161616);
  static const _kBorder26 = Color(0xFF262626);
  static const _kGray6B = Color(0xFF6B7280);
  static const _kGray9C = Color(0xFF9CA3AF);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeroHeader(context),
                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMemberSpaceSection(),
                      const SizedBox(height: 32),
                      _buildUpcomingClass(),
                      const SizedBox(height: 32),
                      _buildLiveUpdates(),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: _buildBottomNav(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroHeader(BuildContext context) {
    return SizedBox(
      height: 320,
      child: Stack(
        children: [
          // Gym image placeholder
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0A2020), Color(0xFF050F0F)],
              ),
            ),
            child: const Center(
              child: Icon(Icons.fitness_center, color: Color(0xFF1A3030), size: 100),
            ),
          ),
          // Bottom gradient overlay
          Positioned(
            left: 0, right: 0, bottom: 0, height: 200,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [kBg, kBg.withValues(alpha: 0.40), Colors.transparent],
                  stops: const [0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          // Back button + actions row
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildGlassButton(const Icon(Icons.chevron_left, color: Colors.white, size: 20)),
                    Row(
                      children: [
                        Stack(
                          children: [
                            _buildGlassButton(const Icon(Icons.notifications_outlined, color: Colors.white, size: 16)),
                            Positioned(
                              top: 8, right: 8,
                              child: Container(
                                width: 8, height: 8,
                                decoration: BoxDecoration(
                                  color: kLime, shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: kLime,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: kLime.withValues(alpha: 0.30), blurRadius: 15),
                            ],
                          ),
                          child: const Icon(Icons.qr_code_2, color: kBg, size: 18),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Gym info overlay
          Positioned(
            left: 24, right: 24, bottom: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.fitness_center, color: Colors.black, size: 32),
                ),
                const SizedBox(height: 12),
                Text('Fitness Club\nAthens', style: GoogleFonts.spaceGrotesk(
                  fontSize: 30, fontWeight: FontWeight.w800,
                  color: Colors.white, height: 1.0, letterSpacing: -0.75)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: kLime.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(9999),
                        border: Border.all(color: kLime.withValues(alpha: 0.30)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle, color: kLime, size: 8),
                          const SizedBox(width: 6),
                          Text('Active Membership', style: GoogleFonts.manrope(
                            fontSize: 9, fontWeight: FontWeight.w700,
                            color: kLime, letterSpacing: 0.9)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('Athens, Greece', style: GoogleFonts.manrope(
                      fontSize: 10, fontWeight: FontWeight.w600,
                      color: kCyan, letterSpacing: -0.5)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassButton(Widget child) {
    return Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: kBg.withValues(alpha: 0.40),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Center(child: child),
    );
  }

  Widget _buildMemberSpaceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('MEMBER SPACE', style: GoogleFonts.spaceGrotesk(
              fontSize: 12, fontWeight: FontWeight.w700,
              color: _kGray6B, letterSpacing: 2.4)),
            const SizedBox(width: 16),
            Expanded(child: Container(height: 1, color: _kBorder26.withValues(alpha: 0.30))),
          ],
        ),
        const SizedBox(height: 20),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.0,
          children: [
            _buildGridItem(Icons.card_membership_outlined, 'MY\nPACKAGE',
              accentColor: kLime.withValues(alpha: 0.20),
              borderColor: kLime.withValues(alpha: 0.20),
              iconBg: kLime.withValues(alpha: 0.10)),
            _buildGridItem(Icons.add_circle_outline, 'BOOK\nCLASS',
              iconBg: kCyan.withValues(alpha: 0.10)),
            _buildGridItem(Icons.calendar_today_outlined, 'MY\nSCHEDULE'),
            _buildGridItem(Icons.fitness_center_outlined, 'TRAINING\nPROGRAMS'),
            _buildGridItem(Icons.restaurant_outlined, 'NUTRITION\nPLAN'),
            _buildGridItem(Icons.show_chart, 'BODY\nPROGRESS'),
            _buildGridItem(Icons.people_outlined, 'SOCIAL\nFEED'),
            _buildGridItem(Icons.store_outlined, 'STORE\nSHOP'),
            _buildGridItem(Icons.chat_bubble_outline, 'COACH\nCHAT', badge: '2'),
          ],
        ),
      ],
    );
  }

  Widget _buildGridItem(IconData icon, String label, {
    Color? iconBg, Color? accentColor, Color? borderColor, String? badge,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x66262626), Color(0x99161616)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor ?? Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: iconBg ?? Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              if (badge != null)
                Positioned(
                  top: -4, right: -4,
                  child: Container(
                    width: 16, height: 16,
                    decoration: BoxDecoration(color: kCyan, shape: BoxShape.circle),
                    child: Center(
                      child: Text(badge, style: GoogleFonts.manrope(
                        fontSize: 8, fontWeight: FontWeight.w700, color: kBg)),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(label, style: GoogleFonts.manrope(
            fontSize: 9, fontWeight: FontWeight.w700,
            color: const Color(0xFFD1D5DB), letterSpacing: 0.15),
            textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildUpcomingClass() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x66262626), Color(0x99161616)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(color: kLime, width: 4),
          top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
          right: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('UPCOMING CLASS', style: GoogleFonts.manrope(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: kLime, letterSpacing: 1.0)),
                  const SizedBox(height: 4),
                  Text('CrossFit Intermediate', style: GoogleFonts.manrope(
                    fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('18:30', style: GoogleFonts.spaceGrotesk(
                    fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                  Text('IN 45 MINS', style: GoogleFonts.manrope(
                    fontSize: 10, fontWeight: FontWeight.w700, color: _kGray6B)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.only(top: 12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0x0DFFFFFF))),
            ),
            child: Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _kBorder26),
                    color: const Color(0xFF3A3C42),
                  ),
                  child: const Icon(Icons.person, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Coach Alexander', style: GoogleFonts.manrope(
                        fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white)),
                      Text('Main Studio • Zone 3', style: GoogleFonts.manrope(
                        fontSize: 10, color: _kGray6B)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _kBorder26,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('DETAILS', style: GoogleFonts.manrope(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: Colors.white, letterSpacing: 0.5)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveUpdates() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('LIVE UPDATES', style: GoogleFonts.spaceGrotesk(
          fontSize: 12, fontWeight: FontWeight.w700,
          color: _kGray6B, letterSpacing: 2.4)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _kDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.people_outline, color: kCyan, size: 16),
                        const SizedBox(width: 8),
                        Text('GYM TRAFFIC', style: GoogleFonts.manrope(
                          fontSize: 10, fontWeight: FontWeight.w700, color: _kGray9C)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text('42%', style: GoogleFonts.spaceGrotesk(
                          fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                        const SizedBox(width: 4),
                        Text('Low', style: GoogleFonts.spaceGrotesk(
                          fontSize: 10, color: kLime)),
                      ],
                    ),
                    Text('Ideal time for heavy lift', style: GoogleFonts.manrope(
                      fontSize: 10, color: _kGray6B)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _kDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.thermostat_outlined, color: kCyan, size: 16),
                        const SizedBox(width: 8),
                        Text('TEMPERATURE', style: GoogleFonts.manrope(
                          fontSize: 10, fontWeight: FontWeight.w700, color: _kGray9C)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('21.5°C', style: GoogleFonts.spaceGrotesk(
                      fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                    Text('Climate controlled', style: GoogleFonts.manrope(
                      fontSize: 10, color: _kGray6B)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
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
          _buildProfileNavItem(),
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

  Widget _buildProfileNavItem() {
    return SizedBox(
      width: 60,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 24, height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _kGray6B),
            ),
            child: ClipOval(
              child: Container(
                color: const Color(0xFF3A3C42),
                child: const Icon(Icons.person, color: Colors.white, size: 14),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text('PROFILE', style: GoogleFonts.manrope(
            fontSize: 9, fontWeight: FontWeight.w700,
            color: _kGray6B, letterSpacing: 0.9)),
        ],
      ),
    );
  }
}
