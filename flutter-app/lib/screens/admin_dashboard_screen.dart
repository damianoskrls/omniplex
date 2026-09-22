import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/omni_design.dart';

const _kAmber = Color(0xFFFFB93D);
const _kAmberBg = Color(0xFF2A210F);
const _kPurple = Color(0xFFB57BFF);
const _kPurpleBg = Color(0xFF20142F);
const _kCyanBg = Color(0xFF0F2429);

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        children: [
          // Top lime glow
          Positioned(
            left: 0, top: 0,
            child: Container(
              width: 375, height: 256,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.0,
                  colors: [
                    kLime.withValues(alpha: 0.10),
                    kLime.withValues(alpha: 0.03),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.35, 0.60],
                ),
              ),
            ),
          ),
          // Bottom-right cyan glow
          Positioned(
            right: 0, top: 384,
            child: Container(
              width: 160, height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    kCyan.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.70],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Admin Dashboard', style: GoogleFonts.manrope(
                                    fontSize: 12, fontWeight: FontWeight.w600, color: kGray)),
                                  const SizedBox(height: 4),
                                  Text('Fitness Club Athens', style: GoogleFonts.spaceGrotesk(
                                    fontSize: 20, fontWeight: FontWeight.w700,
                                    color: Colors.white, letterSpacing: -0.5)),
                                ],
                              ),
                              Row(
                                children: [
                                  Container(
                                    width: 44, height: 44,
                                    decoration: BoxDecoration(
                                      color: kCard,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: kBorder),
                                    ),
                                    child: const Icon(Icons.settings_outlined, color: Colors.white, size: 18),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    width: 44, height: 44,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: kLime, width: 2),
                                    ),
                                    child: ClipOval(
                                      child: Container(
                                        color: const Color(0xFF2A2B30),
                                        child: const Icon(Icons.person, color: kGray, size: 24),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Today section
                        _buildSectionHeader('Today', 'Live overview'),
                        const SizedBox(height: 12),
                        // Stats grid
                        _buildStatsGrid(),
                        const SizedBox(height: 12),
                        // Pending requests alert
                        _buildPendingCard(),
                        const SizedBox(height: 28),
                        // Quick Actions
                        _buildSectionHeader('Quick Actions', null),
                        const SizedBox(height: 12),
                        _buildQuickActions(),
                        const SizedBox(height: 28),
                        // Recent Activity
                        _buildSectionHeader('Recent Activity', 'See all'),
                        const SizedBox(height: 12),
                        _buildActivityList(),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
                // Bottom nav
                _buildBottomNav(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String? trailing) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: GoogleFonts.spaceGrotesk(
          fontSize: 16, fontWeight: FontWeight.w700,
          color: Colors.white, letterSpacing: -0.4)),
        if (trailing != null)
          Row(
            children: [
              Text(trailing, style: GoogleFonts.manrope(
                fontSize: 12, fontWeight: FontWeight.w600, color: kGray)),
              if (trailing == 'See all')
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(Icons.chevron_right, color: kGray, size: 14),
                ),
            ],
          )
        else
          Text('Live overview', style: GoogleFonts.manrope(
            fontSize: 12, fontWeight: FontWeight.w600, color: kGray)),
      ],
    );
  }

  Widget _buildStatsGrid() {
    return SizedBox(
      height: 268,
      child: GridView.count(
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.25,
        children: [
          _buildStatCard('128', 'Active Members', Icons.people_outlined,
            const Color(0xFF1D2410), kLime.withValues(alpha: 0.30), kLime),
          _buildStatCard('64', 'Bookings', Icons.calendar_month_outlined,
            _kCyanBg, kCyan.withValues(alpha: 0.30), kCyan),
          _buildStatCard('52', 'Check-ins', Icons.qr_code_scanner_outlined,
            const Color(0xFF1D2410), kLime.withValues(alpha: 0.30), kLime),
          _buildStatCard('8', 'Classes', Icons.fitness_center_outlined,
            const Color(0xFF1F2024), kBorder2, Colors.white),
        ],
      ),
    );
  }

  Widget _buildStatCard(String value, String label, IconData icon,
      Color iconBg, Color iconBorderColor, Color valueColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: iconBorderColor),
            ),
            child: Icon(icon, color: valueColor, size: 16),
          ),
          const SizedBox(height: 12),
          Text(value, style: GoogleFonts.spaceGrotesk(
            fontSize: 24, fontWeight: FontWeight.w700,
            color: valueColor, height: 1.0)),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.manrope(
            fontSize: 12, fontWeight: FontWeight.w600, color: kGray)),
        ],
      ),
    );
  }

  Widget _buildPendingCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _kAmberBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kAmber.withValues(alpha: 0.40)),
        ),
        child: Stack(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: kBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _kAmber.withValues(alpha: 0.30)),
                      ),
                      child: const Icon(Icons.notifications_outlined, color: _kAmber, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('3', style: GoogleFonts.spaceGrotesk(
                          fontSize: 24, fontWeight: FontWeight.w700,
                          color: _kAmber, height: 1.0)),
                        const SizedBox(height: 4),
                        Text('Pending Requests', style: GoogleFonts.manrope(
                          fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                      ],
                    ),
                  ],
                ),
                const Icon(Icons.chevron_right, color: kGray, size: 16),
              ],
            ),
            // Left accent bar
            Positioned(
              left: -16, top: -16, bottom: -16,
              child: Container(
                width: 4,
                decoration: BoxDecoration(
                  color: _kAmber,
                  boxShadow: [
                    BoxShadow(color: _kAmber.withValues(alpha: 0.60), blurRadius: 10),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        _buildQuickAction('Members', Icons.people_outlined,
          const Color(0xFF1D2410), kLime.withValues(alpha: 0.30), kLime),
        const SizedBox(width: 10),
        _buildQuickAction('Staff', Icons.assignment_outlined,
          _kCyanBg, kCyan.withValues(alpha: 0.30), kCyan),
        const SizedBox(width: 10),
        _buildQuickAction('Classes', Icons.sports_outlined,
          _kPurpleBg, _kPurple.withValues(alpha: 0.30), _kPurple),
        const SizedBox(width: 10),
        Stack(
          children: [
            _buildQuickAction('Requests', Icons.inbox_outlined,
              _kAmberBg, _kAmber.withValues(alpha: 0.30), _kAmber),
            Positioned(
              top: 10, right: 10,
              child: Container(
                width: 10, height: 10,
                decoration: BoxDecoration(
                  color: _kAmber,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: _kAmber.withValues(alpha: 0.90), blurRadius: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickAction(String label, IconData icon, Color iconBg,
      Color iconBorderColor, Color iconColor) {
    return Expanded(
      child: Container(
        height: 92,
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorder),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40, height: 36,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: iconBorderColor),
              ),
              child: Icon(icon, color: iconColor, size: 16),
            ),
            const SizedBox(height: 10),
            Text(label, style: GoogleFonts.manrope(
              fontSize: 10, fontWeight: FontWeight.w600,
              color: Colors.white, letterSpacing: 0.13),
              textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityList() {
    final items = [
      ('New member joined', 'Damianos K.', '2m ago',
        const Color(0xFF1D2410), kLime.withValues(alpha: 0.30), Icons.person_add_outlined, kLime),
      ('Booking cancelled', 'CrossFit 18:30', '18m ago',
        kBg, kBorder2, Icons.cancel_outlined, kGray),
      ('Staff leave requested', 'Maria P.', '1h ago',
        _kAmberBg, _kAmber.withValues(alpha: 0.30), Icons.flight_takeoff_outlined, _kAmber),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        children: items.asMap().entries.map((e) {
          final i = e.key;
          final item = e.value;
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: i < items.length - 1
                ? const Border(bottom: BorderSide(color: kBorder))
                : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: item.$4,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: item.$5),
                  ),
                  child: Icon(item.$6, color: item.$7, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.$1, style: GoogleFonts.manrope(
                        fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                      Text(item.$2, style: GoogleFonts.manrope(
                        fontSize: 12, color: kGray)),
                    ],
                  ),
                ),
                Text(item.$3, style: GoogleFonts.manrope(
                  fontSize: 11, fontWeight: FontWeight.w600, color: kDim)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: kCard,
        border: Border(top: BorderSide(color: kBorder)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildNavItem(Icons.home_outlined, 'Home', true, false),
          _buildNavItem(Icons.people_outlined, 'Members', false, false),
          _buildNavItem(Icons.assignment_outlined, 'Staff', false, false),
          _buildNavItem(Icons.inbox_outlined, 'Requests', false, true),
          _buildNavItem(Icons.person_outline, 'Profile', false, false),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool active, bool hasBadge) {
    return SizedBox(
      width: 68,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              SizedBox(
                width: 44, height: 44,
                child: Center(child: Icon(icon, color: active ? kLime : kDim, size: 22)),
              ),
              if (hasBadge)
                Positioned(
                  top: 4, right: 10,
                  child: Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      color: _kAmber,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: _kAmber.withValues(alpha: 0.90), blurRadius: 8),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(label, style: active
            ? GoogleFonts.spaceGrotesk(
                fontSize: 10, fontWeight: FontWeight.w700, color: kLime)
            : GoogleFonts.manrope(
                fontSize: 10, fontWeight: FontWeight.w600, color: kGray),
            textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
